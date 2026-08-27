param(
    [string]$OutputPath = 'evals\eval-inventory.json',
    [switch]$Check,
    [string]$RootPath = '',
    [switch]$AsObject
)

$ErrorActionPreference = 'Stop'
$root = if ([string]::IsNullOrWhiteSpace($RootPath)) { Split-Path -Parent $PSScriptRoot } else { (Resolve-Path -LiteralPath $RootPath -ErrorAction Stop).Path }
$utf8 = [System.Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot 'evaluation-state.ps1')

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    return [System.IO.Path]::GetFullPath($candidate)
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.File]::ReadAllText((Resolve-RepoPath -Path $Path), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-RepoPath -Path $Path))
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha.Dispose()
    }
}

function Add-MapValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        $Value
    )
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = [System.Collections.Generic.List[object]]::new() }
    $Map[$Key].Add($Value)
}

function Get-CaseKey {
    param([string]$Suite, $Id)
    return "$Suite`:$([string]$Id)"
}

function Get-Route {
    param(
        [string]$Text,
        [object[]]$Contracts,
        $Scenario
    )

    $match = [regex]::Match(([string]$Text).TrimStart(), '^/(review|idea|prd|acceptance|prompt)\b')
    if ($match.Success) { return $match.Value }
    if ($null -ne $Scenario -and -not [string]::IsNullOrWhiteSpace([string]$Scenario.route)) { return [string]$Scenario.route }
    $routes = @($Contracts | Where-Object { $null -ne $_ } | ForEach-Object { @($_.routes) } | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($routes.Count -eq 1) { return $routes[0] }
    if ($routes.Count -gt 1) { return 'cross-route' }
    return 'unknown'
}

function Get-Risk {
    param([object[]]$Contracts)
    $items = @($Contracts | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) { return 'scenario' }
    $rank = @{ critical = 4; high = 3; medium = 2; low = 1 }
    return [string](@($items | Sort-Object { -[int]$rank[[string]$_.risk] })[0].risk)
}

function Get-PanelRole {
    param([string]$Key, [hashtable]$CoreKeys, [hashtable]$DeltaKeys, [hashtable]$ControlKeys)
    if ($CoreKeys.ContainsKey($Key)) { return 'core' }
    if ($DeltaKeys.ContainsKey($Key)) { return 'current_delta' }
    if ($ControlKeys.ContainsKey($Key)) { return 'adjacent_control' }
    return 'catalog'
}

function New-BehaviorCase {
    param(
        [string]$Suite,
        $Eval,
        [hashtable]$ContractMap,
        [hashtable]$ScenarioMap,
        [hashtable]$StateMap,
        [hashtable]$CoreKeys,
        [hashtable]$DeltaKeys,
        [hashtable]$ControlKeys
    )

    $key = Get-CaseKey -Suite $Suite -Id $Eval.id
    $contracts = if ($ContractMap.ContainsKey([string]$Eval.id)) { @($ContractMap[[string]$Eval.id]) } else { @() }
    $scenario = if ($ScenarioMap.ContainsKey([string]$Eval.id)) { $ScenarioMap[[string]$Eval.id] } else { $null }
    $role = Get-PanelRole -Key $key -CoreKeys $CoreKeys -DeltaKeys $DeltaKeys -ControlKeys $ControlKeys
    if (-not $StateMap.ContainsKey($key)) { throw "Evaluation case has no persistent lifecycle state: $key" }
    $state = [string]$StateMap[$key].state
    $tier = if ($state -in @('archived', 'retired')) { 'T0' } elseif ($role -eq 'core') { 'T1' } elseif ($state -eq 'canary' -or $role -in @('current_delta', 'adjacent_control')) { 'T2' } else { 'T4' }

    return [ordered]@{
        suite = $Suite
        id = $Eval.id
        name = [string]$Eval.name
        route = (Get-Route -Text ([string]$Eval.prompt) -Contracts $contracts -Scenario $scenario)
        lifecycle_state = $state
        default_tier = $tier
        selection_role = $role
        ownership_type = if (@($contracts).Count -gt 0) { 'contract' } else { 'scenario' }
        contract_ids = @($contracts | ForEach-Object { [string]$_.contract_id } | Sort-Object -Unique)
        scenario_group = if ($null -ne $scenario) { [string]$scenario.group_id } else { $null }
        risk = (Get-Risk -Contracts $contracts)
        expectation_count = @($Eval.expectations).Count
        has_files = @($Eval.files).Count -gt 0
    }
}

$sourceFiles = @(
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

$stable = Read-JsonFile -Path 'evals/evals.json'
$challenge = Read-JsonFile -Path 'evals/challenge-evals.json'
$triggers = Read-JsonFile -Path 'evals/trigger-evals.json'
$registry = Read-JsonFile -Path 'evals/contract-registry.json'
$lifecycle = Read-JsonFile -Path 'evals/eval-lifecycle.json'
$core = Read-JsonFile -Path 'evals/release-panel-core.json'
$panel = Read-JsonFile -Path 'evals/release-panel.json'
$policy = Read-JsonFile -Path 'evals/evaluation-policy.json'
$stateMap = Get-MypmEvaluationStateMap -Root $root
$routeOverrides = @{}
foreach ($entry in @($policy.trigger_route_overrides)) {
    $id = [int]$entry.id
    if ($id -lt 1 -or $id -gt @($triggers).Count -or $routeOverrides.ContainsKey([string]$id)) {
        throw "Invalid or duplicate trigger route override: $id"
    }
    if (-not [bool]$triggers[$id - 1].should_trigger) { throw "Route override cannot target a negative trigger: $id" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = (($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$triggers[$id - 1].query)) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
    if ($hash -cne [string]$entry.query_sha256) { throw "Trigger route override query hash is stale: $id" }
    if ([string]$entry.route -notin @('/review', '/idea', '/prd', '/acceptance', '/prompt', 'memory', 'handoff', 'cross-route') -or [string]::IsNullOrWhiteSpace([string]$entry.reason)) {
        throw "Invalid trigger route override metadata: $id"
    }
    $routeOverrides[[string]$id] = [string]$entry.route
}

$stableContracts = @{}
$challengeContracts = @{}
$triggerContracts = @{}
foreach ($contract in @($registry.contracts)) {
    foreach ($id in @($contract.stable_evals)) { Add-MapValue -Map $stableContracts -Key ([string]$id) -Value $contract }
    foreach ($id in @($contract.challenge_evals)) { Add-MapValue -Map $challengeContracts -Key ([string]$id) -Value $contract }
    foreach ($id in @($contract.trigger_evals)) { Add-MapValue -Map $triggerContracts -Key ([string]$id) -Value $contract }
}

$stableScenarios = @{}
$challengeScenarios = @{}
foreach ($group in @($lifecycle.scenario_groups)) {
    foreach ($id in @($group.stable_evals)) { $stableScenarios[[string]$id] = $group }
    foreach ($id in @($group.challenge_evals)) { $challengeScenarios[[string]$id] = $group }
}

$coreKeys = @{}
foreach ($entry in @($core.selection)) { $coreKeys[(Get-CaseKey -Suite ([string]$entry.suite) -Id $entry.id)] = $true }
$deltaKeys = @{}
foreach ($entry in @($panel.selection_groups.delta)) { $deltaKeys[(Get-CaseKey -Suite ([string]$entry.suite) -Id $entry.id)] = $true }
$controlKeys = @{}
foreach ($entry in @($panel.selection_groups.controls)) { $controlKeys[(Get-CaseKey -Suite ([string]$entry.suite) -Id $entry.id)] = $true }

$cases = [System.Collections.Generic.List[object]]::new()
foreach ($eval in @($stable.evals)) {
    $cases.Add((New-BehaviorCase -Suite 'stable' -Eval $eval -ContractMap $stableContracts -ScenarioMap $stableScenarios -StateMap $stateMap -CoreKeys $coreKeys -DeltaKeys $deltaKeys -ControlKeys $controlKeys))
}
foreach ($eval in @($challenge.evals)) {
    $cases.Add((New-BehaviorCase -Suite 'challenge' -Eval $eval -ContractMap $challengeContracts -ScenarioMap $challengeScenarios -StateMap $stateMap -CoreKeys $coreKeys -DeltaKeys $deltaKeys -ControlKeys $controlKeys))
}
for ($index = 0; $index -lt @($triggers).Count; $index++) {
    $id = $index + 1
    $stateKey = Get-CaseKey -Suite 'trigger' -Id $id
    if (-not $stateMap.ContainsKey($stateKey)) { throw "Evaluation case has no persistent lifecycle state: $stateKey" }
    $contracts = if ($triggerContracts.ContainsKey([string]$id)) { @($triggerContracts[[string]$id]) } else { @() }
    $route = Get-Route -Text ([string]$triggers[$index].query) -Contracts $contracts -Scenario $null
    if (-not [bool]$triggers[$index].should_trigger) {
        $route = 'outside-mypm'
    } elseif ($routeOverrides.ContainsKey([string]$id)) {
        $route = $routeOverrides[[string]$id]
    } elseif ($route -eq 'unknown') {
        throw "Unclassified positive trigger route: $id; register explicit ownership or a query-bound override."
    }
    $cases.Add([ordered]@{
        suite = 'trigger'
        id = $id
        name = ('trigger-{0:d3}' -f $id)
        route = $route
        lifecycle_state = [string]$stateMap[$stateKey].state
        default_tier = 'T1'
        selection_role = 'trigger'
        ownership_type = if (@($contracts).Count -gt 0) { 'contract' } else { 'trigger-baseline' }
        contract_ids = @($contracts | ForEach-Object { [string]$_.contract_id } | Sort-Object -Unique)
        scenario_group = $null
        risk = if (@($contracts).Count -gt 0) { (Get-Risk -Contracts $contracts) } else { 'scenario' }
        expectation_count = 1
        has_files = $false
    })
}

$caseArray = @($cases)
if ($stateMap.Count -ne $caseArray.Count) { throw 'Persistent lifecycle registry contains cases absent from the source inventory' }
$lifecycleCounts = [ordered]@{}
foreach ($state in @('core', 'active', 'canary', 'archived', 'retired')) {
    $lifecycleCounts[$state] = @($caseArray | Where-Object { [string]$_.lifecycle_state -eq $state }).Count
}
$riskCounts = [ordered]@{}
foreach ($risk in @('critical', 'high', 'medium', 'low', 'scenario')) {
    $riskCounts[$risk] = @($caseArray | Where-Object { [string]$_.risk -eq $risk }).Count
}
$routeCounts = [ordered]@{}
foreach ($route in @('/review', '/idea', '/prd', '/acceptance', '/prompt', 'memory', 'handoff', 'cross-route', 'outside-mypm')) {
    $routeCounts[$route] = @($caseArray | Where-Object { [string]$_.route -eq $route }).Count
}
$selectionRoleCounts = [ordered]@{}
foreach ($role in @('core', 'current_delta', 'adjacent_control', 'catalog', 'trigger')) {
    $selectionRoleCounts[$role] = @($caseArray | Where-Object { [string]$_.selection_role -eq $role }).Count
}
$ownershipCounts = [ordered]@{}
foreach ($ownership in @('contract', 'scenario', 'trigger-baseline')) {
    $ownershipCounts[$ownership] = @($caseArray | Where-Object { [string]$_.ownership_type -eq $ownership }).Count
}

$inventory = [ordered]@{
    schema_version = 1
    generator_version = 1
    skill_version = [string]$policy.skill_version
    purpose = [string]$policy.inventory_purpose
    generated_from = @($sourceFiles | ForEach-Object { [ordered]@{ path = $_; sha256 = Get-FileSha256 -Path $_ } })
    summary = [ordered]@{
        stable_cases = @($stable.evals).Count
        challenge_cases = @($challenge.evals).Count
        trigger_cases = @($triggers).Count
        behavior_cases = @($stable.evals).Count + @($challenge.evals).Count
        stable_expectations = [int](($stable.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
        challenge_expectations = [int](($challenge.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
        contracts = @($registry.contracts).Count
        scenario_groups = @($lifecycle.scenario_groups).Count
        lifecycle_states = $lifecycleCounts
        risks = $riskCounts
        routes = $routeCounts
        selection_roles = $selectionRoleCounts
        ownership_types = $ownershipCounts
    }
    cases = $caseArray
}

if ($AsObject) { return $inventory }

$output = Resolve-RepoPath -Path $OutputPath
if ($Check) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw "Evaluation inventory does not exist: $output" }
    $existing = Read-JsonFile -Path $output
    $expectedJson = $inventory | ConvertTo-Json -Depth 30 -Compress
    $existingJson = $existing | ConvertTo-Json -Depth 30 -Compress
    if ($expectedJson -cne $existingJson) { throw 'Evaluation inventory is stale; run scripts\build-eval-inventory.ps1.' }
    Write-Host "Evaluation inventory is current: cases=$($caseArray.Count)"
    exit 0
}

$directory = Split-Path -Parent $output
if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
$json = ($inventory | ConvertTo-Json -Depth 30) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($output, $json + "`n", $utf8)
Write-Host "Evaluation inventory written: $output cases=$($caseArray.Count)"
