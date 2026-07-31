param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Prepare', 'Apply')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Workspace,

    [ValidateRange(1, 8)]
    [int]$BatchSize = 3,

    [string]$OutputDirectory = '_grading-batches',
    [switch]$IncludeGraded,
    [switch]$Overwrite,
    [switch]$AllowIncomplete
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $json = $Value | ConvertTo-Json -Depth 40
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8)
}

function Test-IsInside {
    param(
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $childPath = [System.IO.Path]::GetFullPath($Child).TrimEnd('\') + '\'
    $parentPath = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    return $childPath.StartsWith($parentPath, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-StableHash {
    param([Parameter(Mandatory = $true)][string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Resolve-WorkspaceContext {
    $workspacePath = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).Path
    $iterationPath = Join-Path $workspacePath 'iteration.json'
    if (-not (Test-Path -LiteralPath $iterationPath -PathType Leaf)) {
        throw "iteration.json not found: $iterationPath"
    }
    $iteration = Read-JsonFile -Path $iterationPath
    $outputPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
        [System.IO.Path]::GetFullPath($OutputDirectory)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $workspacePath $OutputDirectory))
    }
    if ($outputPath.Equals($workspacePath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-IsInside -Child $outputPath -Parent $workspacePath)) {
        throw 'Grading batch output must stay inside the regression workspace.'
    }
    return [ordered]@{ workspace = $workspacePath; iteration = $iteration; output = $outputPath }
}

function Invoke-Prepare {
    $context = Resolve-WorkspaceContext
    $workspacePath = $context.workspace
    $iteration = $context.iteration
    $outputPath = $context.output

    if (Test-Path -LiteralPath $outputPath) {
        if (-not $Overwrite) {
            throw "Grading batch directory already exists; use -Overwrite: $outputPath"
        }
        Remove-Item -LiteralPath $outputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    $privatePath = Join-Path $outputPath '_private'
    New-Item -ItemType Directory -Path $privatePath -Force | Out-Null

    $pending = [System.Collections.Generic.List[object]]::new()
    foreach ($directoryName in @($iteration.eval_directories)) {
        $evalDirectory = Join-Path $workspacePath $directoryName
        $task = Read-JsonFile -Path (Join-Path $evalDirectory 'task.json')
        $metadata = Read-JsonFile -Path (Join-Path $workspacePath "$($iteration.grader_directory)\$directoryName.json")
        $attachments = [System.Collections.Generic.List[object]]::new()
        foreach ($relativeFile in @($task.files)) {
            $attachmentPath = Join-Path $evalDirectory ([string]$relativeFile)
            $attachments.Add([ordered]@{
                name = Split-Path -Leaf $attachmentPath
                content = [System.IO.File]::ReadAllText($attachmentPath, [System.Text.Encoding]::UTF8)
            })
        }

        foreach ($configuration in @($iteration.configurations)) {
            foreach ($runNumber in 1..([int]$iteration.runs_per_configuration)) {
                $runDirectory = Join-Path $evalDirectory "$($configuration.name)\run-$runNumber"
                $responsePath = Join-Path $runDirectory 'response.md'
                $gradingPath = Join-Path $runDirectory 'grading.json'
                if (-not (Test-Path -LiteralPath $responsePath -PathType Leaf)) {
                    continue
                }
                if ((Test-Path -LiteralPath $gradingPath -PathType Leaf) -and -not $IncludeGraded) {
                    continue
                }
                $pending.Add([ordered]@{
                    sort_key = Get-StableHash -Value "$($metadata.id)|$($configuration.name)|$runNumber|mypm-v030"
                    eval_id = [string]$metadata.id
                    eval_name = [string]$metadata.name
                    eval_directory = $directoryName
                    configuration = [string]$configuration.name
                    run = $runNumber
                    run_directory = $runDirectory
                    prompt = [string]$task.prompt
                    attachments = @($attachments)
                    expected_output = [string]$metadata.expected_output
                    expectations = @($metadata.expectations | ForEach-Object { [string]$_ })
                    response = [System.IO.File]::ReadAllText($responsePath, [System.Text.Encoding]::UTF8)
                })
            }
        }
    }

    $orderedPending = @($pending | Sort-Object sort_key)
    $mappingItems = [System.Collections.Generic.List[object]]::new()
    $batchEntries = [System.Collections.Generic.List[object]]::new()
    for ($offset = 0; $offset -lt $orderedPending.Count; $offset += $BatchSize) {
        $batchNumber = [int]($offset / $BatchSize) + 1
        $batchName = 'batch-{0:D3}' -f $batchNumber
        $lastIndex = [Math]::Min($offset + $BatchSize - 1, $orderedPending.Count - 1)
        $batchItems = [System.Collections.Generic.List[object]]::new()
        for ($index = $offset; $index -le $lastIndex; $index++) {
            $item = $orderedPending[$index]
            $blindId = 'B{0:D4}' -f ($index + 1)
            $batchItems.Add([ordered]@{
                blind_id = $blindId
                prompt = $item.prompt
                attachments = @($item.attachments)
                expected_output = $item.expected_output
                expectations = @($item.expectations)
                response = $item.response
            })
            $mappingItems.Add([ordered]@{
                blind_id = $blindId
                batch = $batchName
                eval_id = $item.eval_id
                eval_name = $item.eval_name
                eval_directory = $item.eval_directory
                configuration = $item.configuration
                run = $item.run
                run_directory = $item.run_directory
                expectations = @($item.expectations)
            })
        }

        $inputName = "$batchName-input.json"
        $outputName = "$batchName-output.json"
        Write-JsonFile -Value ([ordered]@{
            schema_version = 1
            instruction = '逐条独立评分。只能依据请求、附件、预期说明、检查项和回答判断；不得推断执行模型或配置。每个检查项必须保持原文、给出布尔 passed 和中文 evidence。'
            output_contract = [ordered]@{
                results = @([ordered]@{
                    blind_id = '原样返回 blind_id'
                    expectations = @([ordered]@{ text = '检查项原文'; passed = $true; evidence = '中文证据' })
                })
            }
            items = @($batchItems)
        }) -Path (Join-Path $outputPath $inputName)
        $batchEntries.Add([ordered]@{
            name = $batchName
            input = $inputName
            expected_output = $outputName
            item_count = $batchItems.Count
        })
    }

    Write-JsonFile -Value ([ordered]@{
        schema_version = 1
        prepared_at_utc = [DateTime]::UtcNow.ToString('o')
        workspace = $workspacePath
        batch_size = $BatchSize
        item_count = $mappingItems.Count
        batches = @($batchEntries)
    }) -Path (Join-Path $outputPath 'manifest.json')
    Write-JsonFile -Value ([ordered]@{
        schema_version = 1
        note = '私有映射。不得把本文件或该目录提供给评分模型。'
        items = @($mappingItems)
    }) -Path (Join-Path $privatePath 'mapping.json')

    Write-Host "Blind grading batches prepared: items=$($mappingItems.Count) batches=$($batchEntries.Count) batch_size=$BatchSize"
    Write-Host "Give graders only *-input.json files. Save matching results as *-output.json, then run -Action Apply."
}

function Invoke-Apply {
    $context = Resolve-WorkspaceContext
    $outputPath = $context.output
    $manifestPath = Join-Path $outputPath 'manifest.json'
    $mappingPath = Join-Path $outputPath '_private\mapping.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $mappingPath -PathType Leaf)) {
        throw 'Grading batch manifest or private mapping is missing. Run -Action Prepare first.'
    }
    $batchManifest = Read-JsonFile -Path $manifestPath
    $mapping = Read-JsonFile -Path $mappingPath
    $mappingById = @{}
    foreach ($item in @($mapping.items)) {
        $mappingById[[string]$item.blind_id] = $item
    }

    $resultsById = @{}
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($batch in @($batchManifest.batches)) {
        $outputFile = Join-Path $outputPath ([string]$batch.expected_output)
        if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
            $issues.Add("missing grader output: $($batch.expected_output)")
            continue
        }
        try {
            $payload = Read-JsonFile -Path $outputFile
            foreach ($result in @($payload.results)) {
                $blindId = [string]$result.blind_id
                if (-not $mappingById.ContainsKey($blindId)) {
                    $issues.Add("unknown blind_id in $($batch.expected_output): $blindId")
                    continue
                }
                if ($resultsById.ContainsKey($blindId)) {
                    $issues.Add("duplicate blind_id: $blindId")
                    continue
                }
                $resultsById[$blindId] = $result
            }
        } catch {
            $issues.Add("invalid grader output $($batch.expected_output): $($_.Exception.Message)")
        }
    }

    $writes = [System.Collections.Generic.List[object]]::new()
    foreach ($blindId in $mappingById.Keys) {
        $map = $mappingById[$blindId]
        if (-not $resultsById.ContainsKey($blindId)) {
            $issues.Add("missing grading result: $blindId")
            continue
        }
        $result = $resultsById[$blindId]
        $expectedTexts = @($map.expectations | ForEach-Object { [string]$_ })
        $graded = @($result.expectations)
        if ($graded.Count -ne $expectedTexts.Count) {
            $issues.Add("expectation count mismatch for $blindId")
            continue
        }
        $normalized = [System.Collections.Generic.List[object]]::new()
        $valid = $true
        for ($index = 0; $index -lt $expectedTexts.Count; $index++) {
            $entry = $graded[$index]
            if ([string]$entry.text -ne $expectedTexts[$index]) {
                $issues.Add("expectation text mismatch for $blindId at index $index")
                $valid = $false
            }
            if ($entry.passed -isnot [bool]) {
                $issues.Add("passed must be boolean for $blindId at index $index")
                $valid = $false
            }
            if ([string]::IsNullOrWhiteSpace([string]$entry.evidence)) {
                $issues.Add("evidence is empty for $blindId at index $index")
                $valid = $false
            }
            $normalized.Add([ordered]@{
                text = $expectedTexts[$index]
                passed = [bool]$entry.passed
                evidence = [string]$entry.evidence
            })
        }
        if (-not $valid) {
            continue
        }
        $gradingPath = Join-Path ([string]$map.run_directory) 'grading.json'
        if ((Test-Path -LiteralPath $gradingPath -PathType Leaf) -and -not $Overwrite) {
            $issues.Add("grading already exists; use -Overwrite: $gradingPath")
            continue
        }
        $passed = @($normalized | Where-Object { $_.passed -eq $true }).Count
        $writes.Add([ordered]@{
            path = $gradingPath
            value = [ordered]@{
                blind_id = $blindId
                expectations = @($normalized)
                summary = [ordered]@{ passed = $passed; failed = $normalized.Count - $passed; total = $normalized.Count }
            }
        })
    }

    if ($issues.Count -gt 0 -and -not $AllowIncomplete) {
        throw "Cannot apply grading batches:`n- $($issues -join "`n- ")"
    }
    foreach ($write in @($writes)) {
        Write-JsonFile -Value $write.value -Path $write.path
    }
    foreach ($issue in @($issues)) {
        Write-Warning $issue
    }
    Write-Host "Blind grading results applied: written=$($writes.Count) issues=$($issues.Count)"
}

if ($Action -eq 'Prepare') {
    Invoke-Prepare
} else {
    Invoke-Apply
}
