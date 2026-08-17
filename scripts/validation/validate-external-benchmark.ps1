. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmExternalBenchmarkValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$ExternalRoot = ''
    )

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $candidatePath = Join-Path $root 'evals\external-candidates.json'
    $benchmarkPath = Join-Path $root 'evals\external-benchmark.json'
    $contractPath = Join-Path $root 'evals\external-benchmark-contract.json'
    $candidatesDocument = Read-MypmJson -Path $candidatePath -Result $result -Label 'evals/external-candidates.json'
    $benchmark = Read-MypmJson -Path $benchmarkPath -Result $result -Label 'evals/external-benchmark.json'
    $contract = Read-MypmJson -Path $contractPath -Result $result -Label 'evals/external-benchmark-contract.json'
    if ($null -in @($candidatesDocument, $benchmark, $contract)) { return $result }

    if ([int]$candidatesDocument.schema_version -ne 1 -or [int]$benchmark.schema_version -ne 1 -or [int]$contract.schema_version -ne 1) {
        Add-MypmValidationError -Result $result -Message 'External benchmark schema_version must be 1'
    }
    if ([string]$benchmark.candidate_manifest -ne 'evals/external-candidates.json') {
        Add-MypmValidationError -Result $result -Message 'External benchmark candidate_manifest is not canonical'
    }
    if ([string]$benchmark.task_contract -ne 'evals/external-benchmark-contract.json') {
        Add-MypmValidationError -Result $result -Message 'External benchmark task_contract is not canonical'
    }
    if ([string]$contract.requirement_id -ne 'FR-007' -or [string]$contract.source_prd -ne 'notes/v0.36-capability-ecosystem-prd.md') {
        Add-MypmValidationError -Result $result -Message 'External benchmark task contract is not bound to FR-007'
    }

    $prdPath = Join-Path $root ([string]$contract.source_prd)
    $prdText = ''
    if (-not (Test-Path -LiteralPath $prdPath -PathType Leaf)) {
        Add-MypmValidationError -Result $result -Message "External benchmark source PRD not found: $($contract.source_prd)"
    } else {
        $prdText = [System.IO.File]::ReadAllText($prdPath, [System.Text.Encoding]::UTF8)
    }

    $candidateIds = @{}
    $behaviorIds = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in @($candidatesDocument.candidates)) {
        $id = [string]$candidate.id
        if ($id -notmatch '^[a-z][a-z0-9-]+$') {
            Add-MypmValidationError -Result $result -Message "Invalid external candidate id: $id"
            continue
        }
        if ($candidateIds.ContainsKey($id)) {
            Add-MypmValidationError -Result $result -Message "Duplicate external candidate id: $id"
        } else {
            $candidateIds[$id] = $candidate
        }
        if ([string]$candidate.base_commit -notmatch '^[0-9a-f]{40}$') {
            Add-MypmValidationError -Result $result -Message "External candidate $id has invalid base_commit"
        }
        if ([string]::IsNullOrWhiteSpace([string]$candidate.repository_url) -or [string]::IsNullOrWhiteSpace([string]$candidate.license)) {
            Add-MypmValidationError -Result $result -Message "External candidate $id is missing repository or license identity"
        }
        $mode = [string]$candidate.comparison_mode
        if ($mode -notin @('behavior', 'structure-only')) {
            Add-MypmValidationError -Result $result -Message "External candidate $id has unsupported comparison_mode: $mode"
        }
        if ($mode -eq 'behavior') { $behaviorIds.Add($id) }
    }
    if ($behaviorIds.Count -lt 2) {
        Add-MypmValidationError -Result $result -Message 'External benchmark requires at least two behavior candidates'
    }

    if ([string]$benchmark.execution.output_language -ne 'zh-CN' -or [string]$benchmark.execution.tools -ne 'disabled') {
        Add-MypmValidationError -Result $result -Message 'External benchmark must use Chinese output with tools disabled'
    }
    if ([int]$benchmark.execution.runs_per_task -ne 1 -or [int]$benchmark.execution.timeout_seconds -gt 300) {
        Add-MypmValidationError -Result $result -Message 'External benchmark default execution must be one run with a maximum 300-second timeout'
    }
    if (-not [bool]$benchmark.reporting.no_unified_total_score) {
        Add-MypmValidationError -Result $result -Message 'External benchmark must not define a unified total score'
    }
    if ([int]$benchmark.reporting.minimum_common_valid_tasks -lt 10) {
        Add-MypmValidationError -Result $result -Message 'External benchmark minimum common valid tasks must be at least 10'
    }

    $expectedDimensions = @('correctness', 'evidence_discipline', 'decision_clarity', 'completeness', 'executability', 'redundancy', 'characters', 'duration_ms', 'valid_return')
    $dimensionIds = @($benchmark.scoring_dimensions.id | ForEach-Object { [string]$_ })
    foreach ($dimension in $expectedDimensions) {
        if ($dimension -notin $dimensionIds) {
            Add-MypmValidationError -Result $result -Message "External benchmark is missing scoring dimension: $dimension"
        }
    }
    if (@($dimensionIds | Sort-Object -Unique).Count -ne $dimensionIds.Count) {
        Add-MypmValidationError -Result $result -Message 'External benchmark contains duplicate scoring dimensions'
    }

    $taskIds = @{}
    $tasks = @($benchmark.tasks)
    $contractTasks = @($contract.tasks)
    if ($tasks.Count -ne 12) {
        Add-MypmValidationError -Result $result -Message "External benchmark must define exactly 12 tasks; found $($tasks.Count)"
    }
    if ($contractTasks.Count -ne 12) {
        Add-MypmValidationError -Result $result -Message "External benchmark contract must define exactly 12 tasks; found $($contractTasks.Count)"
    }
    $contractById = @{}
    foreach ($contractTask in $contractTasks) {
        $contractId = [string]$contractTask.id
        if ($contractById.ContainsKey($contractId)) {
            Add-MypmValidationError -Result $result -Message "Duplicate external benchmark contract task id: $contractId"
        } else {
            $contractById[$contractId] = $contractTask
        }
        $expectedRow = "| $contractId | $($contractTask.title_zh) | $($contractTask.capability) | $($contractTask.hard_gate) |"
        if (-not [string]::IsNullOrWhiteSpace($prdText) -and -not $prdText.Contains($expectedRow)) {
            Add-MypmValidationError -Result $result -Message "External benchmark PRD row drift for $contractId"
        }
    }
    foreach ($task in $tasks) {
        $taskId = [string]$task.id
        if ($taskId -notmatch '^EB-[0-9]{2}$') {
            Add-MypmValidationError -Result $result -Message "Invalid external benchmark task id: $taskId"
        } elseif ($taskIds.ContainsKey($taskId)) {
            Add-MypmValidationError -Result $result -Message "Duplicate external benchmark task id: $taskId"
        } else {
            $taskIds[$taskId] = $true
        }
        foreach ($property in @('requirement_id', 'semantic_key', 'domain', 'title_zh', 'fixture', 'prompt', 'minimum_contract', 'candidate_context')) {
            if ($property -notin @($task.PSObject.Properties.Name)) {
                Add-MypmValidationError -Result $result -Message "External benchmark task $taskId is missing $property"
            }
        }
        if (-not $contractById.ContainsKey($taskId)) {
            Add-MypmValidationError -Result $result -Message "External benchmark task $taskId is not declared by FR-007 contract"
        } else {
            $contractTask = $contractById[$taskId]
            if ([string]$task.requirement_id -ne "FR-007/$taskId") {
                Add-MypmValidationError -Result $result -Message "External benchmark task $taskId has invalid requirement_id"
            }
            foreach ($property in @('semantic_key', 'domain', 'title_zh')) {
                if ([string]$task.$property -ne [string]$contractTask.$property) {
                    Add-MypmValidationError -Result $result -Message "External benchmark task contract drift for $taskId/$property"
                }
            }
            if ([string]$contractTask.hard_gate -notin @($task.minimum_contract | ForEach-Object { [string]$_ })) {
                Add-MypmValidationError -Result $result -Message "External benchmark task contract drift for $taskId/hard_gate"
            }
        }
        if (@($task.minimum_contract).Count -lt 3) {
            Add-MypmValidationError -Result $result -Message "External benchmark task $taskId needs at least three minimum contracts"
        }

        $fixture = [string]$task.fixture
        if ([System.IO.Path]::IsPathRooted($fixture)) {
            Add-MypmValidationError -Result $result -Message "External benchmark fixture must be relative: $fixture"
        } else {
            $resolvedFixture = Resolve-MypmPath -Root $root -RelativePath $fixture
            if (-not (Test-MypmPathInsideRoot -Root $root -Path $resolvedFixture) -or -not (Test-Path -LiteralPath $resolvedFixture -PathType Leaf)) {
                Add-MypmValidationError -Result $result -Message "External benchmark fixture not found or outside root: $fixture"
            }
        }

        $contextNames = @($task.candidate_context.PSObject.Properties.Name)
        foreach ($behaviorId in $behaviorIds) {
            if ($behaviorId -notin $contextNames) {
                Add-MypmValidationError -Result $result -Message "External benchmark task $taskId is missing behavior candidate context: $behaviorId"
                continue
            }
            $files = @($task.candidate_context.$behaviorId)
            if ($files.Count -eq 0 -or $files.Count -gt 4) {
                Add-MypmValidationError -Result $result -Message "External benchmark task $taskId candidate $behaviorId must load 1 to 4 files"
            }
            $seenFiles = @{}
            foreach ($fileValue in $files) {
                $file = [string]$fileValue
                if ([System.IO.Path]::IsPathRooted($file) -or $file.Contains('..')) {
                    Add-MypmValidationError -Result $result -Message "Unsafe candidate context path for $taskId/$behaviorId`: $file"
                    continue
                }
                $key = $file.Replace('\', '/').ToLowerInvariant()
                if ($seenFiles.ContainsKey($key)) {
                    Add-MypmValidationError -Result $result -Message "Duplicate candidate context path for $taskId/$behaviorId`: $file"
                } else {
                    $seenFiles[$key] = $true
                }
            }
        }
        foreach ($contextName in $contextNames) {
            if (-not $candidateIds.ContainsKey([string]$contextName)) {
                Add-MypmValidationError -Result $result -Message "External benchmark task $taskId references unknown candidate: $contextName"
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExternalRoot)) {
        $externalRoot = [System.IO.Path]::GetFullPath($ExternalRoot)
        foreach ($behaviorId in $behaviorIds) {
            $candidate = $candidateIds[$behaviorId]
            $candidateRoot = if ($behaviorId -eq 'mypm-v036') { $root } else { Join-Path $externalRoot ([string]$candidate.clone_dir) }
            if (-not (Test-Path -LiteralPath $candidateRoot -PathType Container)) {
                Add-MypmValidationError -Result $result -Message "External candidate clone not found: $behaviorId"
                continue
            }
            if ($behaviorId -ne 'mypm-v036') {
                try {
                    $actualCommit = (& git -C $candidateRoot rev-parse HEAD 2>$null).Trim()
                    if ($actualCommit -ne [string]$candidate.base_commit) {
                        Add-MypmValidationError -Result $result -Message "External candidate commit mismatch for $behaviorId`: expected $($candidate.base_commit), got $actualCommit"
                    }
                } catch {
                    Add-MypmValidationError -Result $result -Message "Cannot read external candidate commit for $behaviorId"
                }
            }
            foreach ($task in $tasks) {
                foreach ($fileValue in @($task.candidate_context.$behaviorId)) {
                    $file = [string]$fileValue
                    $resolved = Resolve-MypmPath -Root $candidateRoot -RelativePath $file
                    if (-not (Test-MypmPathInsideRoot -Root $candidateRoot -Path $resolved) -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                        Add-MypmValidationError -Result $result -Message "Candidate context file not found for $($task.id)/$behaviorId`: $file"
                    }
                }
            }
        }
    }

    $result.Metrics['candidates'] = @($candidatesDocument.candidates).Count
    $result.Metrics['behavior_candidates'] = $behaviorIds.Count
    $result.Metrics['tasks'] = $tasks.Count
    $result.Metrics['task_contracts'] = $contractTasks.Count
    $result.Metrics['dimensions'] = $dimensionIds.Count
    return $result
}
