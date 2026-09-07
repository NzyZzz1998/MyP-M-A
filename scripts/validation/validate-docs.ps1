. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmLatestObservationValidation {
    param([string]$Root, $Result)
    $path = Join-Path $Root 'evals/latest-observation.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    try {
        $observation = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($field in @('source', 'source_sha256', 'snapshot_head')) {
            $value = $observation.$field
            if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) { throw "Missing or invalid observation identity field: $field" }
        }
        if ($observation.snapshot_head -cnotmatch '\A[A-Fa-f0-9]{40}\z' -or $observation.snapshot_head -eq ('0' * 40)) {
            throw 'Invalid snapshot_head'
        }
        $models = @($observation.models)
        $validModels = @($models | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })
        if ($observation.schema_version -ne 1 -or $observation.metric -ne 'assertion-pass-rate' -or
            $observation.duration_basis -notin @('per-case-wall-clock', 'batch-wall-clock-equal-allocation') -or
            $observation.source_sha256 -cnotmatch '\A[A-Fa-f0-9]{64}\z' -or
            $observation.source_sha256 -eq ('0' * 64) -or
            $models.Count -eq 0 -or $validModels.Count -ne $models.Count -or
            @($models | Sort-Object -Unique).Count -ne $models.Count -or
            @($observation.scores).Count -ne ($models.Count * 2) -or
            @($observation.documents).Count -ne 3 -or
            @($observation.documents.path | Sort-Object -Unique).Count -ne 3) { throw 'Invalid observation identity or metric boundary' }
        foreach ($document in $observation.documents) {
            if ($document.path -notin @('README.md', 'notes/mypm-roadmap.md', 'notes/evaluation-history.md')) { throw 'Unsupported observation document' }
            $text = [IO.File]::ReadAllText((Join-Path $Root $document.path), [Text.Encoding]::UTF8)
            $section = [regex]::Match($text, [string]$document.section_pattern)
            if (-not $section.Success) { throw "Missing observation section: $($document.path)" }
            if ($document.path -eq 'notes/evaluation-history.md') {
                # Bind to the selected historical record, not the current Candidate checkout.
                $heads = @([regex]::Matches($section.Value, 'HEAD\s+`([^`]+)`'))
                if ($heads.Count -ne 1 -or $heads[0].Groups[1].Value -ine $observation.snapshot_head) {
                    throw 'snapshot_head does not match selected historical snapshot identity'
                }
                $hashes = @([regex]::Matches($section.Value, '`benchmark\.json` SHA-256\s*[:\uFF1A]\s*`([^`]+)`'))
                if ($hashes.Count -ne 1 -or $hashes[0].Groups[1].Value -ine $observation.source_sha256) {
                    throw 'source_sha256 does not match selected historical benchmark identity'
                }
            }
            foreach ($pattern in @($document.required_patterns)) {
                if (-not [regex]::IsMatch($section.Value, [string]$pattern)) { throw "Observation mismatch in $($document.path): $pattern" }
            }
            # Only the selected observation, never the entire historical archive.
            $scores = @([regex]::Matches($section.Value, '\b\d+/(?:883|376)\b') | ForEach-Object { $_.Value })
            if (($scores -join ',') -ne ($observation.scores -join ',')) { throw "Conflicting observation scores in $($document.path)" }
        }
        # External evidence is optional; an available but conflicting file is not a skip.
        $source = $observation.source
        $Result.Metrics['observation_source_bytes'] = 'unavailable'
        $Result.Metrics['observation_external_identity'] = 'unavailable'
        if (-not [IO.Path]::IsPathRooted($source)) { $source = Join-Path $Root $source }
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256 -ErrorAction Stop).Hash -ine $observation.source_sha256) {
                throw 'Source benchmark hash mismatch'
            }
            $Result.Metrics['observation_source_bytes'] = 'verified'
        }
        $manifestPath = Join-Path (Split-Path -Parent $source) 'run-manifest.json'
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $manifest = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            if ($manifest.head -isnot [string] -or $manifest.head -ine $observation.snapshot_head) {
                throw 'snapshot_head does not match external run-manifest head'
            }
            $Result.Metrics['observation_external_identity'] = 'verified'
        }
    } catch {
        Add-MypmValidationError -Result $Result -Message "Latest observation: $($_.Exception.Message)"
    }
}

function Invoke-MypmDocsValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    Invoke-MypmLatestObservationValidation -Root $root -Result $result
    $extensions = @('.md', '.json', '.yaml', '.ps1', '.csv', '.sql', '.log')
    $markers = @([char]0xFFFD, [char]0x951B, [char]0x9286, [char]0x9235, [char]0x99A3, [char]0x95C1)
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in $extensions })

    foreach ($file in $files) {
        $relative = Get-MypmRelativePath -Root $root -Path $file.FullName
        $text = Read-MypmUtf8Text -Path $file.FullName -Result $result -Label $relative
        if ($null -eq $text) { continue }
        foreach ($marker in $markers) {
            if ($text.Contains([string]$marker)) {
                Add-MypmValidationError -Result $result -Message "Possible mojibake: $relative contains U+$([int]$marker).ToString('X4')"
            }
        }
    }

    $skillPath = Join-Path $root 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        Add-MypmValidationError -Result $result -Message 'Missing SKILL.md'
        return $result
    }
    $skill = Read-MypmUtf8Text -Path $skillPath -Result $result -Label 'SKILL.md'
    if ($null -eq $skill) { return $result }
    $frontmatter = [regex]::Match($skill, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|$)')
    if (-not $frontmatter.Success) {
        Add-MypmValidationError -Result $result -Message 'SKILL.md is missing valid YAML frontmatter'
    } elseif (-not [regex]::IsMatch($frontmatter.Groups['yaml'].Value, '(?m)^name:\s*mypm\s*$')) {
        Add-MypmValidationError -Result $result -Message 'SKILL.md frontmatter name must be mypm'
    }
    $version = Get-MypmSkillVersion -SkillText $skill
    if (-not $version) { Add-MypmValidationError -Result $result -Message 'SKILL.md is missing metadata.version' }

    $statusPattern = '<!-- project-status: version=([^;]+); state=([a-z-]+) -->'
    $allowedStates = @('candidate', 'stable-local-pending', 'local-committed', 'remote-synced')
    $records = [System.Collections.Generic.List[string]]::new()
    $stateByDocument = @{}
    foreach ($relative in @('README.md', 'notes/mypm-roadmap.md')) {
        $path = Resolve-MypmPath -Root $root -RelativePath $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-MypmValidationError -Result $result -Message "Missing status document: $relative"
            continue
        }
        $text = Read-MypmUtf8Text -Path $path -Result $result -Label $relative
        if ($null -eq $text) { continue }
        $match = [regex]::Match($text, $statusPattern)
        if (-not $match.Success) {
            Add-MypmValidationError -Result $result -Message "Missing project-status marker in $relative"
            continue
        }
        $state = $match.Groups[2].Value
        if ($state -notin $allowedStates) { Add-MypmValidationError -Result $result -Message "Unsupported project-status state in $relative`: $state" }
        if ($version -and $match.Groups[1].Value -ne $version) {
            Add-MypmValidationError -Result $result -Message "Project-status version mismatch in $relative`: SKILL=$version document=$($match.Groups[1].Value)"
        }
        $records.Add("$($match.Groups[1].Value)|$state")
        $stateByDocument[$relative] = $state
    }
    if ($records.Count -eq 2 -and @($records | Select-Object -Unique).Count -ne 1) {
        Add-MypmValidationError -Result $result -Message 'README.md and notes/mypm-roadmap.md project-status markers must match'
    }

    $stable = Read-MypmJson -Path (Join-Path $root 'evals\evals.json') -Result $result -Label 'evals/evals.json'
    $challenge = Read-MypmJson -Path (Join-Path $root 'evals\challenge-evals.json') -Result $result -Label 'evals/challenge-evals.json'
    if ($null -ne $stable -and $null -ne $challenge) {
        $stableTotal = [int](($stable.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
        $challengeTotal = [int](($challenge.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
        $combinedTotal = $stableTotal + $challengeTotal
        $combinedPattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$combinedTotal))\b"
        $stablePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$stableTotal))\b"
        $challengePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$challengeTotal))\b"
        $stablePending = "(?m)\u5F85\u8BC4\u6D4B\s*/\s*$([regex]::Escape([string]$stableTotal))\b"
        $challengePending = "(?m)\u5F85\u8BC4\u6D4B\s*/\s*$([regex]::Escape([string]$challengeTotal))\b"
        $stableNotRerun = "(?m)\u672A\u5168\u91CF\u91CD\u8DD1\s*/\s*$([regex]::Escape([string]$stableTotal))\b"
        $challengeNotRerun = "(?m)\u672A\u5168\u91CF\u91CD\u8DD1\s*/\s*$([regex]::Escape([string]$challengeTotal))\b"
        $allowPending = $stateByDocument['README.md'] -eq 'candidate'
        foreach ($relative in @('README.md', 'CHANGELOG.md', 'notes/mypm-roadmap.md')) {
            $path = Resolve-MypmPath -Root $root -RelativePath $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                Add-MypmValidationError -Result $result -Message "Missing evaluation status document: $relative"
                continue
            }
            $text = Read-MypmUtf8Text -Path $path -Result $result -Label $relative
            if ($null -eq $text) { continue }
            if ([regex]::IsMatch($text, $combinedPattern)) { Add-MypmValidationError -Result $result -Message "Stable and challenge eval scores must not be reported as a combined total in $relative" }
            if ((-not [regex]::IsMatch($text, $stablePattern)) -and (-not [regex]::IsMatch($text, $stableNotRerun)) -and (-not ($allowPending -and [regex]::IsMatch($text, $stablePending)))) {
                Add-MypmValidationError -Result $result -Message "Missing separate stable eval score in $relative"
            }
            if ((-not [regex]::IsMatch($text, $challengePattern)) -and (-not [regex]::IsMatch($text, $challengeNotRerun)) -and (-not ($allowPending -and [regex]::IsMatch($text, $challengePending)))) {
                Add-MypmValidationError -Result $result -Message "Missing separate challenge eval score in $relative"
            }
        }
    }

    $runtimeFiles = @(Get-Item -LiteralPath $skillPath) + @(Get-ChildItem -LiteralPath (Join-Path $root 'references') -File -Filter '*.md')
    $runtimeText = ($runtimeFiles | ForEach-Object { Read-MypmUtf8Text -Path $_.FullName -Result $result -Label (Get-MypmRelativePath -Root $root -Path $_.FullName) }) -join "`n"
    $referenceRegex = [regex]'`((?:references|templates)/[^`]+\.md)`'
    foreach ($file in $runtimeFiles) {
        $text = Read-MypmUtf8Text -Path $file.FullName -Result $result -Label (Get-MypmRelativePath -Root $root -Path $file.FullName)
        if ($null -eq $text) { continue }
        foreach ($match in $referenceRegex.Matches($text)) {
            $target = Resolve-MypmPath -Root $root -RelativePath $match.Groups[1].Value
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { Add-MypmValidationError -Result $result -Message "Broken reference: $($file.Name) -> $($match.Groups[1].Value)" }
        }
    }
    foreach ($reference in Get-ChildItem -LiteralPath (Join-Path $root 'references') -File -Filter '*.md') {
        if (-not $skill.Contains("references/$($reference.Name)") -and -not $runtimeText.Contains("references/$($reference.Name)")) { Add-MypmValidationWarning -Result $result -Message "Unrouted reference: $($reference.Name)" }
    }
    foreach ($template in Get-ChildItem -LiteralPath (Join-Path $root 'templates') -File -Filter '*.md') {
        if (-not $runtimeText.Contains("templates/$($template.Name)")) { Add-MypmValidationWarning -Result $result -Message "Unrouted template: $($template.Name)" }
    }

    $result.Metrics['files'] = $files.Count
    $result.Metrics['version'] = $version
    return $result
}
