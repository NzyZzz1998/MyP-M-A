. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmContractsValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $registry = Read-MypmJson -Path (Join-Path $root 'evals\contract-registry.json') -Result $result -Label 'evals/contract-registry.json'
    $stable = Read-MypmJson -Path (Join-Path $root 'evals\evals.json') -Result $result -Label 'evals/evals.json'
    $challenge = Read-MypmJson -Path (Join-Path $root 'evals\challenge-evals.json') -Result $result -Label 'evals/challenge-evals.json'
    $trigger = Read-MypmJson -Path (Join-Path $root 'evals\trigger-evals.json') -Result $result -Label 'evals/trigger-evals.json'
    $core = Read-MypmJson -Path (Join-Path $root 'evals\release-panel-core.json') -Result $result -Label 'evals/release-panel-core.json'
    $panel = Read-MypmJson -Path (Join-Path $root 'evals\release-panel.json') -Result $result -Label 'evals/release-panel.json'
    $baseline = Read-MypmJson -Path (Join-Path $root 'evals\trigger-baseline.json') -Result $result -Label 'evals/trigger-baseline.json'
    $lifecycle = Read-MypmJson -Path (Join-Path $root 'evals\eval-lifecycle.json') -Result $result -Label 'evals/eval-lifecycle.json'
    if ($null -in @($registry, $stable, $challenge, $trigger, $core, $panel, $baseline, $lifecycle)) { return $result }

    $stableIds = @($stable.evals.id | ForEach-Object { [string]$_ })
    $challengeIds = @($challenge.evals.id | ForEach-Object { [string]$_ })
    $allowedRoutes = @('/review', '/idea', '/prd', '/acceptance', '/prompt')
    $allowedRisks = @('critical', 'high', 'medium', 'low')
    $requiredProperties = @('contract_id', 'source_file', 'routes', 'risk', 'stable_evals', 'challenge_evals', 'trigger_evals', 'release_core')
    $contracts = @($registry.contracts)
    $byId = @{}
    $contractStableIds = @{}
    $contractChallengeIds = @{}

    foreach ($contract in $contracts) {
        $id = [string]$contract.contract_id
        foreach ($property in $requiredProperties) {
            if ($property -notin @($contract.PSObject.Properties.Name)) { Add-MypmValidationError -Result $result -Message "Contract $id is missing $property" }
        }
        if ([string]::IsNullOrWhiteSpace($id)) { Add-MypmValidationError -Result $result -Message 'Contract id cannot be empty'; continue }
        if ($byId.ContainsKey($id)) { Add-MypmValidationError -Result $result -Message "Duplicate contract id: $id" } else { $byId[$id] = $contract }
        if ([string]$contract.risk -notin $allowedRisks) { Add-MypmValidationError -Result $result -Message "Contract $id has unsupported risk: $($contract.risk)" }
        foreach ($route in @($contract.routes)) {
            if ([string]$route -notin $allowedRoutes) { Add-MypmValidationError -Result $result -Message "Contract $id has unsupported route: $route" }
        }
        $source = Resolve-MypmPath -Root $root -RelativePath ([string]$contract.source_file)
        if (-not (Test-MypmPathInsideRoot -Root $root -Path $source)) {
            Add-MypmValidationError -Result $result -Message "Contract $id source escapes skill root: $($contract.source_file)"
        } elseif (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            Add-MypmValidationError -Result $result -Message "Contract $id source file not found: $($contract.source_file)"
        } else {
            $sourceText = Read-MypmUtf8Text -Path $source -Result $result -Label ([string]$contract.source_file)
            if ($null -ne $sourceText -and -not $sourceText.Contains("contract:$id")) {
                Add-MypmValidationError -Result $result -Message "Contract anchor not found in $($contract.source_file): contract:$id"
            }
        }
        foreach ($evalId in @($contract.stable_evals)) {
            if ([string]$evalId -notin $stableIds) { Add-MypmValidationError -Result $result -Message "Contract $id references missing stable eval: $evalId" }
            $contractStableIds[[string]$evalId] = $true
        }
        foreach ($evalId in @($contract.challenge_evals)) {
            if ([string]$evalId -notin $challengeIds) { Add-MypmValidationError -Result $result -Message "Contract $id references missing challenge eval: $evalId" }
            $contractChallengeIds[[string]$evalId] = $true
        }
        foreach ($triggerId in @($contract.trigger_evals)) {
            if ([int]$triggerId -lt 1 -or [int]$triggerId -gt @($trigger).Count) { Add-MypmValidationError -Result $result -Message "Contract $id references missing trigger eval: $triggerId" }
        }
        if ([string]$contract.risk -eq 'critical' -and (@($contract.stable_evals).Count + @($contract.challenge_evals).Count) -eq 0) {
            Add-MypmValidationError -Result $result -Message "Critical contract has no behavior eval mapping: $id"
        }
    }

    $allowedLifecycleRoutes = @('/review', '/idea', '/prd', '/acceptance', '/prompt', 'memory')
    $lifecycleStableCounts = @{}
    $lifecycleChallengeCounts = @{}
    $lifecycleGroupIds = @{}
    foreach ($group in @($lifecycle.scenario_groups)) {
        $groupId = [string]$group.group_id
        foreach ($property in @('group_id', 'route', 'status', 'purpose', 'stable_evals', 'challenge_evals')) {
            if ($property -notin @($group.PSObject.Properties.Name)) { Add-MypmValidationError -Result $result -Message "Eval lifecycle group $groupId is missing $property" }
        }
        if ([string]::IsNullOrWhiteSpace($groupId)) {
            Add-MypmValidationError -Result $result -Message 'Eval lifecycle group id cannot be empty'
            continue
        }
        if ($lifecycleGroupIds.ContainsKey($groupId)) {
            Add-MypmValidationError -Result $result -Message "Duplicate eval lifecycle group: $groupId"
        } else {
            $lifecycleGroupIds[$groupId] = $true
        }
        if ([string]$group.route -notin $allowedLifecycleRoutes) { Add-MypmValidationError -Result $result -Message "Eval lifecycle group $groupId has unsupported route: $($group.route)" }
        if ([string]$group.status -ne 'active') { Add-MypmValidationError -Result $result -Message "Current eval lifecycle group must be active: $groupId" }
        if ([string]::IsNullOrWhiteSpace([string]$group.purpose)) { Add-MypmValidationError -Result $result -Message "Eval lifecycle group purpose cannot be empty: $groupId" }

        foreach ($evalId in @($group.stable_evals)) {
            $key = [string]$evalId
            if ($key -notin $stableIds) { Add-MypmValidationError -Result $result -Message "Eval lifecycle group $groupId references missing stable eval: $key" }
            if ($contractStableIds.ContainsKey($key)) { Add-MypmValidationError -Result $result -Message "Eval lifecycle overlaps contract mapping: stable:$key" }
            if (-not $lifecycleStableCounts.ContainsKey($key)) { $lifecycleStableCounts[$key] = 0 }
            $lifecycleStableCounts[$key]++
        }
        foreach ($evalId in @($group.challenge_evals)) {
            $key = [string]$evalId
            if ($key -notin $challengeIds) { Add-MypmValidationError -Result $result -Message "Eval lifecycle group $groupId references missing challenge eval: $key" }
            if ($contractChallengeIds.ContainsKey($key)) { Add-MypmValidationError -Result $result -Message "Eval lifecycle overlaps contract mapping: challenge:$key" }
            if (-not $lifecycleChallengeCounts.ContainsKey($key)) { $lifecycleChallengeCounts[$key] = 0 }
            $lifecycleChallengeCounts[$key]++
        }
    }
    foreach ($evalId in $stableIds) {
        $inContract = $contractStableIds.ContainsKey($evalId)
        $lifecycleCount = if ($lifecycleStableCounts.ContainsKey($evalId)) { [int]$lifecycleStableCounts[$evalId] } else { 0 }
        if (-not $inContract -and $lifecycleCount -eq 0) { Add-MypmValidationError -Result $result -Message "Eval lifecycle ownership missing: stable:$evalId" }
        if ($lifecycleCount -gt 1) { Add-MypmValidationError -Result $result -Message "Duplicate eval lifecycle ownership: stable:$evalId" }
    }
    foreach ($evalId in $challengeIds) {
        $inContract = $contractChallengeIds.ContainsKey($evalId)
        $lifecycleCount = if ($lifecycleChallengeCounts.ContainsKey($evalId)) { [int]$lifecycleChallengeCounts[$evalId] } else { 0 }
        if (-not $inContract -and $lifecycleCount -eq 0) { Add-MypmValidationError -Result $result -Message "Eval lifecycle ownership missing: challenge:$evalId" }
        if ($lifecycleCount -gt 1) { Add-MypmValidationError -Result $result -Message "Duplicate eval lifecycle ownership: challenge:$evalId" }
    }

    $coreContractIds = @{}
    foreach ($entry in @($core.selection)) {
        $contractId = [string]$entry.contract_id
        $coreContractIds[$contractId] = $true
        if (-not $byId.ContainsKey($contractId)) {
            Add-MypmValidationError -Result $result -Message "Release core references unknown contract: $contractId"
            continue
        }
        $contract = $byId[$contractId]
        if (-not [bool]$contract.release_core) { Add-MypmValidationError -Result $result -Message "Release core contract is not marked release_core: $contractId" }
        $mapped = if ([string]$entry.suite -eq 'stable') { @($contract.stable_evals | ForEach-Object { [string]$_ }) } else { @($contract.challenge_evals | ForEach-Object { [string]$_ }) }
        if ([string]$entry.id -notin $mapped) { Add-MypmValidationError -Result $result -Message "Release core case is not mapped by contract $contractId`: $($entry.suite):$($entry.id)" }
    }
    foreach ($contract in $contracts) {
        if ([bool]$contract.release_core -and -not $coreContractIds.ContainsKey([string]$contract.contract_id)) {
            Add-MypmValidationError -Result $result -Message "release_core contract is missing from core panel: $($contract.contract_id)"
        }
    }

    foreach ($contractId in @($panel.affected_contracts)) {
        if (-not $byId.ContainsKey([string]$contractId)) { Add-MypmValidationError -Result $result -Message "Release panel references unknown affected contract: $contractId" }
    }
    if (@($panel.unmapped_files).Count -gt 0) { Add-MypmValidationError -Result $result -Message "Release panel contains unmapped behavior files: $(@($panel.unmapped_files) -join ', ')" }
    foreach ($entry in @($panel.selection)) {
        $contractId = [string]$entry.contract_id
        if (-not $byId.ContainsKey($contractId)) {
            Add-MypmValidationError -Result $result -Message "Release panel entry references unknown contract: $contractId"
            continue
        }
        $contract = $byId[$contractId]
        $mapped = if ([string]$entry.suite -eq 'stable') { @($contract.stable_evals | ForEach-Object { [string]$_ }) } else { @($contract.challenge_evals | ForEach-Object { [string]$_ }) }
        if ([string]$entry.id -notin $mapped) { Add-MypmValidationError -Result $result -Message "Release panel case is not mapped by contract $contractId`: $($entry.suite):$($entry.id)" }
    }

    $skillText = Read-MypmUtf8Text -Path (Join-Path $root 'SKILL.md') -Result $result -Label 'SKILL.md'
    $agentText = Read-MypmUtf8Text -Path (Join-Path $root 'agents\openai.yaml') -Result $result -Label 'agents/openai.yaml'
    $triggerText = Read-MypmUtf8Text -Path (Join-Path $root 'evals\trigger-evals.json') -Result $result -Label 'evals/trigger-evals.json'
    if ($null -ne $skillText -and $null -ne $agentText -and $null -ne $triggerText) {
        $descriptionMatch = [regex]::Match($skillText, '(?m)^description:\s*"(?<value>.*)"\s*$')
        if (-not $descriptionMatch.Success) {
            Add-MypmValidationError -Result $result -Message 'Cannot extract SKILL.md description for trigger freshness'
        } else {
            $description = $descriptionMatch.Groups['value'].Value
            $cases = [System.Collections.Generic.List[object]]::new()
            for ($index = 0; $index -lt @($trigger).Count; $index++) {
                $cases.Add([ordered]@{ id = $index + 1; query = [string]$trigger[$index].query })
            }
            $caseJson = @($cases) | ConvertTo-Json -Depth 5 -Compress
            $expectedHashes = [ordered]@{
                skill_description_sha256 = Get-MypmTextHash -Text $description
                agents_openai_sha256 = Get-MypmTextHash -Text $agentText
                trigger_cases_sha256 = Get-MypmTextHash -Text $caseJson
                trigger_evals_file_sha256 = Get-MypmTextHash -Text $triggerText
                input_bundle_sha256 = Get-MypmTextHash -Text ($description + "`n" + $agentText + "`n" + $caseJson)
            }
            foreach ($name in $expectedHashes.Keys) {
                if ([string]$baseline.input_hashes.$name -ne [string]$expectedHashes[$name]) {
                    Add-MypmValidationError -Result $result -Message "Stale trigger summary hash: $name"
                }
            }
        }
    }
    if ([int]$baseline.case_counts.total -ne @($trigger).Count) { Add-MypmValidationError -Result $result -Message 'Stale trigger summary case count' }
    foreach ($model in @('gpt-5.6-sol', 'gpt-5.6-terra')) {
        $run = @($baseline.runs | Where-Object { [string]$_.model -eq $model })
        if ($run.Count -ne 1 -or [string]$run[0].status -ne 'passed' -or [int]$run[0].correct_count -ne @($trigger).Count) {
            Add-MypmValidationError -Result $result -Message "Trigger baseline is not fresh and passing for model: $model"
        }
    }

    $result.Metrics['contracts'] = $contracts.Count
    $result.Metrics['critical'] = @($contracts | Where-Object risk -eq 'critical').Count
    $result.Metrics['lifecycle_groups'] = @($lifecycle.scenario_groups).Count
    $result.Metrics['scenario_stable'] = $lifecycleStableCounts.Count
    $result.Metrics['scenario_challenge'] = $lifecycleChallengeCounts.Count
    return $result
}
