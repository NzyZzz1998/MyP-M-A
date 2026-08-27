. (Join-Path $PSScriptRoot 'common.ps1')

function Get-MypmPortfolioFileHash {
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha.Dispose()
    }
}

function Invoke-MypmEvaluationPortfolioValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $policy = Read-MypmJson -Path (Join-Path $root 'evals\evaluation-policy.json') -Result $result -Label 'evals/evaluation-policy.json'
    $inventory = Read-MypmJson -Path (Join-Path $root 'evals\eval-inventory.json') -Result $result -Label 'evals/eval-inventory.json'
    $stable = Read-MypmJson -Path (Join-Path $root 'evals\evals.json') -Result $result -Label 'evals/evals.json'
    $challenge = Read-MypmJson -Path (Join-Path $root 'evals\challenge-evals.json') -Result $result -Label 'evals/challenge-evals.json'
    $triggers = Read-MypmJson -Path (Join-Path $root 'evals\trigger-evals.json') -Result $result -Label 'evals/trigger-evals.json'
    $registry = Read-MypmJson -Path (Join-Path $root 'evals\contract-registry.json') -Result $result -Label 'evals/contract-registry.json'
    $lifecycle = Read-MypmJson -Path (Join-Path $root 'evals\eval-lifecycle.json') -Result $result -Label 'evals/eval-lifecycle.json'
    $core = Read-MypmJson -Path (Join-Path $root 'evals\release-panel-core.json') -Result $result -Label 'evals/release-panel-core.json'
    $panel = Read-MypmJson -Path (Join-Path $root 'evals\release-panel.json') -Result $result -Label 'evals/release-panel.json'
    if ($null -in @($policy, $inventory, $stable, $challenge, $triggers, $registry, $lifecycle, $core, $panel)) { return $result }

    $skill = Read-MypmUtf8Text -Path (Join-Path $root 'SKILL.md') -Result $result -Label 'SKILL.md'
    $version = if ($null -ne $skill) { Get-MypmSkillVersion -SkillText $skill } else { $null }
    if ([int]$policy.schema_version -ne 1) { Add-MypmValidationError -Result $result -Message 'Unsupported evaluation policy schema_version' }
    if ([int]$inventory.schema_version -ne 1 -or [int]$inventory.generator_version -ne 1) { Add-MypmValidationError -Result $result -Message 'Unsupported evaluation inventory schema or generator version' }
    if ($version -and [string]$policy.skill_version -ne $version) { Add-MypmValidationError -Result $result -Message "Evaluation policy version mismatch: policy=$($policy.skill_version) skill=$version" }
    if ([string]$inventory.skill_version -ne [string]$policy.skill_version) { Add-MypmValidationError -Result $result -Message 'Evaluation inventory version does not match policy' }

    $requiredStates = @('core', 'active', 'canary', 'archived', 'retired')
    $stateIds = @($policy.lifecycle_states | ForEach-Object { [string]$_.id })
    foreach ($state in $requiredStates) { if ($state -notin $stateIds) { Add-MypmValidationError -Result $result -Message "Evaluation policy missing lifecycle state: $state" } }
    if (@($stateIds | Select-Object -Unique).Count -ne $stateIds.Count) { Add-MypmValidationError -Result $result -Message 'Evaluation policy contains duplicate lifecycle states' }

    $requiredTiers = @('T0', 'T1', 'T2', 'T3', 'T4', 'T5')
    $tierIds = @($policy.execution_tiers | ForEach-Object { [string]$_.id })
    foreach ($tier in $requiredTiers) { if ($tier -notin $tierIds) { Add-MypmValidationError -Result $result -Message "Evaluation policy missing execution tier: $tier" } }
    if (@($tierIds | Select-Object -Unique).Count -ne $tierIds.Count) { Add-MypmValidationError -Result $result -Message 'Evaluation policy contains duplicate execution tiers' }
    if ([int]$policy.execution_profiles.standard_sla_seconds -le 0) { Add-MypmValidationError -Result $result -Message 'Standard evaluation SLA must be positive' }
    if ([int]$policy.execution_profiles.long_form_sla_seconds -lt [int]$policy.execution_profiles.standard_sla_seconds) { Add-MypmValidationError -Result $result -Message 'Long-form SLA cannot be shorter than standard SLA' }
    if ([int]$policy.execution_profiles.max_attempts -ne 3) { Add-MypmValidationError -Result $result -Message 'Evaluation max_attempts must preserve the three-attempt protocol' }
    foreach ($field in @('retry_policy', 'targeted_max', 'cross_model')) {
        if ([string]::IsNullOrWhiteSpace([string]$policy.execution_profiles.$field)) { Add-MypmValidationError -Result $result -Message "Evaluation execution protocol is missing: $field" }
    }
    if ([int]$policy.execution_profiles.max_concurrency -lt 1 -or [int]$policy.execution_profiles.max_concurrency -gt 3) { Add-MypmValidationError -Result $result -Message 'Evaluation max_concurrency must be between 1 and 3' }
    if ([int]$policy.execution_profiles.max_cases_per_agent -lt 1 -or [int]$policy.execution_profiles.max_cases_per_agent -gt 5) { Add-MypmValidationError -Result $result -Message 'Evaluation max_cases_per_agent must be between 1 and 5' }
    if ([int]$policy.execution_profiles.canonical.runs_per_case -lt 1) { Add-MypmValidationError -Result $result -Message 'Evaluation runs_per_case must be positive' }
    if ([string]::IsNullOrWhiteSpace([string]$policy.execution_profiles.canonical.model) -or [string]$policy.execution_profiles.canonical.reasoning_effort -notin @('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra')) { Add-MypmValidationError -Result $result -Message 'Evaluation canonical model or reasoning effort is invalid' }
    $finalTimeout = $policy.execution_profiles.PSObject.Properties['final_attempt_timeout_seconds']
    if ([string]$policy.execution_profiles.final_attempt_policy -ne 'wait_for_result' -or $null -eq $finalTimeout -or $null -ne $finalTimeout.Value) {
        Add-MypmValidationError -Result $result -Message 'Final attempt must wait for a result without a time-based cutoff'
    }
    if ([string]::IsNullOrWhiteSpace([string]$policy.inventory_purpose)) { Add-MypmValidationError -Result $result -Message 'Evaluation policy must define the inventory purpose' }
    if ([string]$policy.lifecycle_policy.implementation_mode -ne 'persistent_registry' -or (@($policy.lifecycle_policy.supported_states) -join ',') -ne 'core,active,canary,archived,retired') {
        Add-MypmValidationError -Result $result -Message 'Lifecycle implementation boundary must match the persistent state registry'
    }
    if ([int]$policy.selection_policy.default_panel_limit -ne [int]$core.max_cases) { Add-MypmValidationError -Result $result -Message 'Evaluation policy panel limit must match release-panel-core.json' }

    $expectedSourcePaths = @(
        'evals/evals.json',
        'evals/challenge-evals.json',
        'evals/trigger-evals.json',
        'evals/contract-registry.json',
        'evals/eval-lifecycle.json',
        'evals/eval-state-registry.json',
        'evals/release-panel-core.json',
        'evals/release-panel.json',
        'evals/evaluation-policy.json'
    )
    $sourceRecords = @($inventory.generated_from)
    foreach ($relative in $expectedSourcePaths) {
        $record = @($sourceRecords | Where-Object { [string]$_.path -eq $relative })
        if ($record.Count -ne 1) {
            Add-MypmValidationError -Result $result -Message "Evaluation inventory source record missing or duplicated: $relative"
            continue
        }
        $sourcePath = Resolve-MypmPath -Root $root -RelativePath $relative
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            Add-MypmValidationError -Result $result -Message "Evaluation inventory source is missing: $relative"
        } elseif ([string]$record[0].sha256 -ne (Get-MypmPortfolioFileHash -Path $sourcePath)) {
            Add-MypmValidationError -Result $result -Message "Evaluation inventory source hash is stale: $relative"
        }
    }
    if ($sourceRecords.Count -ne $expectedSourcePaths.Count) { Add-MypmValidationError -Result $result -Message 'Evaluation inventory contains unexpected source records' }

    $expectedKeys = [System.Collections.Generic.List[string]]::new()
    foreach ($eval in @($stable.evals)) { $expectedKeys.Add("stable`:$([string]$eval.id)") }
    foreach ($eval in @($challenge.evals)) { $expectedKeys.Add("challenge`:$([string]$eval.id)") }
    for ($index = 0; $index -lt @($triggers).Count; $index++) { $expectedKeys.Add("trigger`:$($index + 1)") }
    $caseKeys = @($inventory.cases | ForEach-Object { "$([string]$_.suite)`:$([string]$_.id)" })
    if (@($caseKeys | Select-Object -Unique).Count -ne $caseKeys.Count) { Add-MypmValidationError -Result $result -Message 'Evaluation inventory contains duplicate case keys' }
    foreach ($key in $expectedKeys) { if ($key -notin $caseKeys) { Add-MypmValidationError -Result $result -Message "Evaluation inventory is missing case: $key" } }
    foreach ($key in $caseKeys) { if ($key -notin $expectedKeys) { Add-MypmValidationError -Result $result -Message "Evaluation inventory contains unknown case: $key" } }

    $contractIds = @($registry.contracts.contract_id | ForEach-Object { [string]$_ })
    $scenarioIds = @($lifecycle.scenario_groups.group_id | ForEach-Object { [string]$_ })
    $allowedRoutes = @('/review', '/idea', '/prd', '/acceptance', '/prompt', 'memory', 'handoff', 'cross-route', 'outside-mypm')
    $allowedRisks = @('critical', 'high', 'medium', 'low', 'scenario')
    $allowedRoles = @('core', 'current_delta', 'adjacent_control', 'catalog', 'trigger')
    foreach ($case in @($inventory.cases)) {
        $key = "$([string]$case.suite)`:$([string]$case.id)"
        if ([string]$case.lifecycle_state -notin $requiredStates) { Add-MypmValidationError -Result $result -Message "Unsupported lifecycle state in $key`: $($case.lifecycle_state)" }
        if ([string]$case.default_tier -notin $requiredTiers) { Add-MypmValidationError -Result $result -Message "Unsupported default tier in $key`: $($case.default_tier)" }
        if ([string]$case.selection_role -notin $allowedRoles) { Add-MypmValidationError -Result $result -Message "Unsupported selection role in $key`: $($case.selection_role)" }
        if ([string]$case.route -notin $allowedRoutes) { Add-MypmValidationError -Result $result -Message "Unsupported route in $key`: $($case.route)" }
        if ([string]$case.risk -notin $allowedRisks) { Add-MypmValidationError -Result $result -Message "Unsupported risk in $key`: $($case.risk)" }
        foreach ($contractId in @($case.contract_ids)) { if ([string]$contractId -notin $contractIds) { Add-MypmValidationError -Result $result -Message "Unknown contract in $key`: $contractId" } }
        if (-not [string]::IsNullOrWhiteSpace([string]$case.scenario_group) -and [string]$case.scenario_group -notin $scenarioIds) { Add-MypmValidationError -Result $result -Message "Unknown scenario group in $key`: $($case.scenario_group)" }
        if ([string]$case.ownership_type -eq 'contract' -and @($case.contract_ids).Count -eq 0) { Add-MypmValidationError -Result $result -Message "Contract-owned case has no contracts: $key" }
        if ([string]$case.ownership_type -eq 'scenario' -and [string]::IsNullOrWhiteSpace([string]$case.scenario_group)) { Add-MypmValidationError -Result $result -Message "Scenario-owned case has no scenario group: $key" }
        if ([string]$case.lifecycle_state -eq 'core' -and [string]$case.selection_role -ne 'core') { Add-MypmValidationError -Result $result -Message "Core lifecycle case is not in the core panel: $key" }
        if ([string]$case.lifecycle_state -in @('archived', 'retired') -and [string]$case.selection_role -in @('core', 'current_delta', 'adjacent_control')) { Add-MypmValidationError -Result $result -Message "Inactive lifecycle case remains in the release panel: $key" }
    }

    $stableExpectations = [int](($stable.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
    $challengeExpectations = [int](($challenge.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
    $summaryChecks = [ordered]@{
        stable_cases = @($stable.evals).Count
        challenge_cases = @($challenge.evals).Count
        trigger_cases = @($triggers).Count
        behavior_cases = @($stable.evals).Count + @($challenge.evals).Count
        stable_expectations = $stableExpectations
        challenge_expectations = $challengeExpectations
        contracts = @($registry.contracts).Count
        scenario_groups = @($lifecycle.scenario_groups).Count
    }
    foreach ($name in $summaryChecks.Keys) {
        if ([int]$inventory.summary.$name -ne [int]$summaryChecks[$name]) { Add-MypmValidationError -Result $result -Message "Evaluation inventory summary is stale: $name" }
    }
    foreach ($route in $allowedRoutes) {
        $expected = @($inventory.cases | Where-Object { [string]$_.route -eq $route }).Count
        $property = $inventory.summary.routes.PSObject.Properties[$route]
        if ($null -eq $property -or [int]$property.Value -ne $expected) { Add-MypmValidationError -Result $result -Message "Evaluation inventory route summary is stale: $route" }
    }
    foreach ($role in $allowedRoles) {
        $expected = @($inventory.cases | Where-Object { [string]$_.selection_role -eq $role }).Count
        $property = $inventory.summary.selection_roles.PSObject.Properties[$role]
        if ($null -eq $property -or [int]$property.Value -ne $expected) { Add-MypmValidationError -Result $result -Message "Evaluation inventory role summary is stale: $role" }
    }
    foreach ($ownership in @('contract', 'scenario', 'trigger-baseline')) {
        $expected = @($inventory.cases | Where-Object { [string]$_.ownership_type -eq $ownership }).Count
        $property = $inventory.summary.ownership_types.PSObject.Properties[$ownership]
        if ($null -eq $property -or [int]$property.Value -ne $expected) { Add-MypmValidationError -Result $result -Message "Evaluation inventory ownership summary is stale: $ownership" }
    }
    if ([int]$inventory.summary.lifecycle_states.core -ne @($core.selection).Count) { Add-MypmValidationError -Result $result -Message 'Evaluation inventory core count is stale' }

    # Validate the complete projection, not only valid enum values and self-consistent counts.
    try {
        $generator = Join-Path (Split-Path -Parent $PSScriptRoot) 'build-eval-inventory.ps1'
        $expectedInventory = & $generator -RootPath $root -AsObject
        $expectedJson = $expectedInventory | ConvertTo-Json -Depth 40 -Compress
        $actualJson = $inventory | ConvertTo-Json -Depth 40 -Compress
        if ($actualJson -cne $expectedJson) {
            Add-MypmValidationError -Result $result -Message 'Evaluation inventory projection mismatch: rebuild from source; per-case metadata or summaries have drifted'
        }
    } catch {
        Add-MypmValidationError -Result $result -Message "Evaluation inventory projection failed: $($_.Exception.Message)"
    }

    $result.Metrics['cases'] = @($inventory.cases).Count
    $result.Metrics['behavior'] = [int]$inventory.summary.behavior_cases
    $result.Metrics['core'] = [int]$inventory.summary.lifecycle_states.core
    $result.Metrics['active'] = [int]$inventory.summary.lifecycle_states.active
    $result.Metrics['canary'] = [int]$inventory.summary.lifecycle_states.canary
    return $result
}
