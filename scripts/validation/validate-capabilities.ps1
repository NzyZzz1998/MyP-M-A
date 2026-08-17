. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmCapabilitiesValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $registryPath = Join-Path $root 'capabilities\registry.json'
    $registry = Read-MypmJson -Path $registryPath -Result $result -Label 'capabilities/registry.json'
    if ($null -eq $registry) { return $result }

    if ([int]$registry.schema_version -ne 1) {
        Add-MypmValidationError -Result $result -Message "Unsupported capability registry schema_version: $($registry.schema_version)"
    }
    if ('capabilities' -notin @($registry.PSObject.Properties.Name)) {
        Add-MypmValidationError -Result $result -Message 'Capability registry is missing capabilities'
        return $result
    }

    $stable = Read-MypmJson -Path (Join-Path $root 'evals\evals.json') -Result $result -Label 'evals/evals.json'
    $challenge = Read-MypmJson -Path (Join-Path $root 'evals\challenge-evals.json') -Result $result -Label 'evals/challenge-evals.json'
    $trigger = Read-MypmJson -Path (Join-Path $root 'evals\trigger-evals.json') -Result $result -Label 'evals/trigger-evals.json'
    if ($null -in @($stable, $challenge, $trigger)) { return $result }

    $stableIds = @($stable.evals.id | ForEach-Object { [string]$_ })
    $challengeIds = @($challenge.evals.id | ForEach-Object { [string]$_ })
    $allowedStatuses = @('draft', 'pilot', 'active', 'deprecated', 'retired')
    $allowedEntrypoints = @('/review', '/idea', '/prd', '/acceptance', '/prompt')
    $allowedStages = @('discover', 'validate', 'define', 'review', 'deliver', 'handoff')
    $required = @(
        'id', 'name_zh', 'domain', 'status', 'entrypoints', 'stages', 'triggers', 'anti_triggers',
        'required_inputs', 'outputs', 'evidence_contract', 'tool_categories', 'fallback', 'references',
        'eval_ids', 'owner', 'introduced_in'
    )
    $ids = @{}
    $activeIds = @{}
    $cardFiles = @{}
    $capabilities = @($registry.capabilities)

    foreach ($capability in $capabilities) {
        $id = [string]$capability.id
        foreach ($property in $required) {
            if ($property -notin @($capability.PSObject.Properties.Name)) {
                Add-MypmValidationError -Result $result -Message "Capability $id is missing $property"
            }
        }
        if ([string]::IsNullOrWhiteSpace($id) -or $id -notmatch '^[a-z][a-z0-9-]*\.[a-z][a-z0-9-]*$') {
            Add-MypmValidationError -Result $result -Message "Invalid capability id: $id"
            continue
        }
        if ($ids.ContainsKey($id)) {
            Add-MypmValidationError -Result $result -Message "Duplicate capability id: $id"
        } else {
            $ids[$id] = $capability
        }
        if ([string]$capability.domain -notmatch '^[a-z][a-z0-9-]*$') {
            Add-MypmValidationError -Result $result -Message "Capability $id has invalid domain: $($capability.domain)"
        }
        $status = [string]$capability.status
        if ($status -notin $allowedStatuses) {
            Add-MypmValidationError -Result $result -Message "Capability $id has unsupported status: $status"
        }
        if ($status -in @('pilot', 'active', 'deprecated')) { $activeIds[$id] = $true }
        if ($status -eq 'deprecated' -and ([string]::IsNullOrWhiteSpace([string]$capability.replacement))) {
            Add-MypmValidationError -Result $result -Message "Deprecated capability is missing replacement: $id"
        }

        foreach ($property in @('entrypoints', 'stages', 'triggers', 'anti_triggers', 'required_inputs', 'outputs', 'references')) {
            if (@($capability.$property).Count -eq 0) {
                Add-MypmValidationError -Result $result -Message "Capability $id must define at least one $property"
            }
        }
        foreach ($entrypoint in @($capability.entrypoints)) {
            if ([string]$entrypoint -notin $allowedEntrypoints) {
                Add-MypmValidationError -Result $result -Message "Capability $id has unsupported entrypoint: $entrypoint"
            }
        }
        foreach ($stage in @($capability.stages)) {
            if ([string]$stage -notin $allowedStages) {
                Add-MypmValidationError -Result $result -Message "Capability $id has unsupported stage: $stage"
            }
        }
        foreach ($listName in @('triggers', 'anti_triggers')) {
            $seen = @{}
            foreach ($value in @($capability.$listName)) {
                $text = ([string]$value).Trim()
                if ([string]::IsNullOrWhiteSpace($text)) {
                    Add-MypmValidationError -Result $result -Message "Capability $id contains an empty $listName value"
                    continue
                }
                $key = $text.ToLowerInvariant()
                if ($seen.ContainsKey($key)) {
                    Add-MypmValidationError -Result $result -Message "Capability $id contains duplicate $listName value: $text"
                } else {
                    $seen[$key] = $true
                }
            }
        }

        foreach ($reference in @($capability.references)) {
            $relative = [string]$reference
            if ([System.IO.Path]::IsPathRooted($relative)) {
                Add-MypmValidationError -Result $result -Message "Capability $id reference must be relative: $relative"
                continue
            }
            $resolved = Resolve-MypmPath -Root $root -RelativePath $relative
            if (-not (Test-MypmPathInsideRoot -Root $root -Path $resolved)) {
                Add-MypmValidationError -Result $result -Message "Capability $id reference escapes skill root: $relative"
            } elseif (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                Add-MypmValidationError -Result $result -Message "Capability $id reference file not found: $relative"
            }
        }

        $cardFile = [string]$capability.card_file
        if ($status -in @('pilot', 'active', 'deprecated') -and [string]::IsNullOrWhiteSpace($cardFile)) {
            Add-MypmValidationError -Result $result -Message "Capability $id status $status requires card_file"
        }
        if (-not [string]::IsNullOrWhiteSpace($cardFile)) {
            if ([System.IO.Path]::IsPathRooted($cardFile)) {
                Add-MypmValidationError -Result $result -Message "Capability $id card_file must be relative: $cardFile"
            } else {
                $resolvedCard = Resolve-MypmPath -Root $root -RelativePath $cardFile
                if (-not (Test-MypmPathInsideRoot -Root $root -Path $resolvedCard)) {
                    Add-MypmValidationError -Result $result -Message "Capability $id card_file escapes skill root: $cardFile"
                } elseif (-not (Test-Path -LiteralPath $resolvedCard -PathType Leaf)) {
                    Add-MypmValidationError -Result $result -Message "Capability $id card_file not found: $cardFile"
                } else {
                    $normalizedCard = $cardFile.Replace('\', '/').ToLowerInvariant()
                    if ($cardFiles.ContainsKey($normalizedCard)) {
                        Add-MypmValidationError -Result $result -Message "Capability card_file is shared by multiple ids: $cardFile"
                    } else {
                        $cardFiles[$normalizedCard] = $id
                    }
                    $cardText = Read-MypmUtf8Text -Path $resolvedCard -Result $result -Label $cardFile
                    if ($null -ne $cardText -and -not $cardText.Contains("capability:$id")) {
                        Add-MypmValidationError -Result $result -Message "Capability anchor not found in $cardFile`: capability:$id"
                    }
                    if ($null -ne $cardText -and $cardText -match '(?i)([A-Z]:\\Users\\|/Users/[^/]+/|ghp_[A-Za-z0-9]+|sk-[A-Za-z0-9]{16,})') {
                        Add-MypmValidationError -Result $result -Message "Capability card contains a sensitive path or token pattern: $cardFile"
                    }
                }
            }
        }

        if ('eval_ids' -in @($capability.PSObject.Properties.Name)) {
            foreach ($property in @('stable', 'challenge', 'trigger')) {
                if ($property -notin @($capability.eval_ids.PSObject.Properties.Name)) {
                    Add-MypmValidationError -Result $result -Message "Capability $id eval_ids is missing $property"
                }
            }
            foreach ($evalId in @($capability.eval_ids.stable)) {
                if ([string]$evalId -notin $stableIds) { Add-MypmValidationError -Result $result -Message "Capability $id references missing stable eval: $evalId" }
            }
            foreach ($evalId in @($capability.eval_ids.challenge)) {
                if ([string]$evalId -notin $challengeIds) { Add-MypmValidationError -Result $result -Message "Capability $id references missing challenge eval: $evalId" }
            }
            foreach ($evalId in @($capability.eval_ids.trigger)) {
                if ([int]$evalId -lt 1 -or [int]$evalId -gt @($trigger).Count) { Add-MypmValidationError -Result $result -Message "Capability $id references missing trigger eval: $evalId" }
            }
            if ($status -in @('pilot', 'active') -and (@($capability.eval_ids.stable).Count + @($capability.eval_ids.challenge).Count) -eq 0) {
                Add-MypmValidationError -Result $result -Message "Capability $id status $status requires a stable or challenge eval"
            }
        }
    }

    foreach ($id in $ids.Keys) {
        $capability = $ids[$id]
        if ([string]$capability.status -eq 'deprecated') {
            $replacement = [string]$capability.replacement
            if (-not $ids.ContainsKey($replacement)) {
                Add-MypmValidationError -Result $result -Message "Deprecated capability $id references missing replacement: $replacement"
            } elseif ([string]$ids[$replacement].status -in @('deprecated', 'retired')) {
                Add-MypmValidationError -Result $result -Message "Deprecated capability $id replacement is not usable: $replacement"
            }
        }
    }

    $result.Metrics['capabilities'] = $capabilities.Count
    $result.Metrics['pilot'] = @($capabilities | Where-Object status -eq 'pilot').Count
    $result.Metrics['active'] = @($capabilities | Where-Object status -eq 'active').Count
    return $result
}
