param(
    [string]$PanelFile = 'evals\release-panel.json',
    [string]$CoreFile = 'evals\release-panel-core.json',
    [string]$ContractRegistryFile = 'evals\contract-registry.json',
    [string]$BaselineRef,
    [string]$CandidateRef,
    [string[]]$ChangedFiles = @(),
    [string[]]$AffectedContracts = @(),
    [switch]$UseExplicitAffectedContracts,
    [string]$NoBehaviorChangeFile,
    [int]$MaxCases = 26,
    [string]$SnapshotPath,
    [string]$RootPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = if ($RootPath) { [System.IO.Path]::GetFullPath($RootPath) } else { Split-Path -Parent $PSScriptRoot }
$utf8 = [System.Text.UTF8Encoding]::new($false)
$routeOrder = @('/review', '/idea', '/prd', '/acceptance', '/prompt')
. (Join-Path $PSScriptRoot 'evaluation-state.ps1')
$legacyState = -not (Test-Path -LiteralPath (Join-Path $root 'evals\evaluation-policy.json'))
$stateMap = Get-MypmEvaluationStateMap -Root $root -AllowLegacy:$legacyState
if ($MaxCases -lt 1) { throw 'MaxCases must be positive' }

function Resolve-RepoFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$AllowMissing
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    if ($AllowMissing) { return [System.IO.Path]::GetFullPath($candidate) }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.File]::ReadAllText((Resolve-RepoFile -Path $Path), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $fullPath = Resolve-RepoFile -Path $Path -AllowMissing
    $directory = Split-Path -Parent $fullPath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $json = ($Value | ConvertTo-Json -Depth 40) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($fullPath, $json + "`n", $utf8)
    return $fullPath
}

function Normalize-RelativePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return (($Path -replace '\\', '/') -replace '^\./', '')
}

function Get-SelectionKey {
    param($Entry)
    return "$([string]$Entry.suite):$([string]$Entry.id)"
}

function Convert-EvalId {
    param([string]$Suite, $Id)
    if ($Suite -eq 'stable' -and [string]$Id -match '^\d+$') { return [int]$Id }
    return [string]$Id
}

function New-SelectionEntry {
    param(
        [string]$Suite,
        $Id,
        [string]$Category,
        [string]$Route,
        [string]$ContractId,
        [string]$Reason,
        [string]$ScenarioGroupId = ''
    )

    $entry = [ordered]@{
        suite = $Suite
        id = Convert-EvalId -Suite $Suite -Id $Id
        category = $Category
        route = $Route
        contract_id = $ContractId
        reason = $Reason
    }
    if ($ScenarioGroupId) { $entry.scenario_group_id = $ScenarioGroupId }
    return $entry
}

function Add-UniqueSelection {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [hashtable]$Seen,
        $Entry
    )

    $key = Get-SelectionKey -Entry $Entry
    if (-not (Test-SelectableCase -Key $key)) { return $false }
    if ($Seen.ContainsKey($key)) { return $false }
    $Seen[$key] = $true
    $Target.Add($Entry)
    return $true
}

function Test-SelectableCase {
    param([string]$Key)
    if ($stateMap.Count -eq 0 -and $legacyState) { return $true }
    if (-not $stateMap.ContainsKey($Key)) { throw "Evaluation case has no persistent lifecycle state: $Key" }
    return [string]$stateMap[$Key].state -notin @('archived', 'retired')
}

function Get-ContractEvalEntries {
    param($Contract, [string]$ReasonPrefix)

    $entries = [System.Collections.Generic.List[object]]::new()
    $fallbackRoute = if (@($Contract.routes).Count -gt 0) { [string]$Contract.routes[0] } else { '' }
    foreach ($id in @($Contract.stable_evals)) {
        $eval = @($stable.evals | Where-Object { [string]$_.id -eq [string]$id })
        $match = if ($eval.Count -eq 1) { [regex]::Match([string]$eval[0].prompt, '^/(review|idea|prd|acceptance|prompt)\b') } else { $null }
        $route = if ($null -ne $match -and $match.Success) { $match.Value } else { $fallbackRoute }
        $entries.Add((New-SelectionEntry -Suite 'stable' -Id $id -Category 'delta' -Route $route -ContractId ([string]$Contract.contract_id) -Reason "$ReasonPrefix$($Contract.contract_id)"))
    }
    foreach ($id in @($Contract.challenge_evals)) {
        $eval = @($challenge.evals | Where-Object { [string]$_.id -eq [string]$id })
        $match = if ($eval.Count -eq 1) { [regex]::Match([string]$eval[0].prompt, '^/(review|idea|prd|acceptance|prompt)\b') } else { $null }
        $route = if ($null -ne $match -and $match.Success) { $match.Value } else { $fallbackRoute }
        $entries.Add((New-SelectionEntry -Suite 'challenge' -Id $id -Category 'delta' -Route $route -ContractId ([string]$Contract.contract_id) -Reason "$ReasonPrefix$($Contract.contract_id)"))
    }
    return @($entries)
}

function Test-BehaviorPath {
    param([string]$Path)
    $normalized = Normalize-RelativePath -Path $Path
    return ($normalized -eq 'SKILL.md' -or $normalized.StartsWith('references/') -or $normalized.StartsWith('templates/'))
}

function Test-WorkingTreeRef {
    param([string]$Ref)
    return (-not [string]::IsNullOrWhiteSpace($Ref)) -and $Ref.StartsWith('working-tree-', [System.StringComparison]::Ordinal)
}

function Test-Waiver {
    param(
        [object[]]$Waivers,
        [string]$SourceFile,
        [string]$ContractId
    )

    foreach ($waiver in @($Waivers)) {
        $reason = [string]$waiver.reason
        if ([string]::IsNullOrWhiteSpace($reason)) { continue }
        if ($SourceFile -and (Normalize-RelativePath -Path ([string]$waiver.source_file)) -eq (Normalize-RelativePath -Path $SourceFile)) { return $true }
        if ($ContractId -and [string]$waiver.contract_id -eq $ContractId) { return $true }
    }
    return $false
}

function Get-SortedSelection {
    param([object[]]$Entries)
    return @($Entries | Sort-Object `
        @{ Expression = { if ([string]$_.suite -eq 'stable') { 0 } else { 1 } } }, `
        @{ Expression = { if ([string]$_.id -match '^\d+$') { [int]$_.id } else { [int]::MaxValue } } }, `
        @{ Expression = { [string]$_.id } }, `
        @{ Expression = { [string]$_.contract_id } })
}

$stable = Read-JsonFile -Path 'evals\evals.json'
$challenge = Read-JsonFile -Path 'evals\challenge-evals.json'
$core = Read-JsonFile -Path $CoreFile
$registry = Read-JsonFile -Path $ContractRegistryFile
$lifecycle = Read-JsonFile -Path 'evals\eval-lifecycle.json'
foreach ($entry in @($core.selection)) {
    $coreKey = Get-SelectionKey -Entry $entry
    if (-not (Test-SelectableCase -Key $coreKey) -or ($stateMap.Count -gt 0 -and [string]$stateMap[$coreKey].state -ne 'core')) {
        throw "Fixed core must remain an active core lifecycle case: $coreKey"
    }
}
$contracts = @($registry.contracts)
$contractById = @{}
foreach ($contract in $contracts) {
    $id = [string]$contract.contract_id
    if ($contractById.ContainsKey($id)) { throw "Duplicate contract id: $id" }
    $contractById[$id] = $contract
}

$hasDynamicInput = (-not [string]::IsNullOrWhiteSpace($BaselineRef)) -or
    (-not [string]::IsNullOrWhiteSpace($CandidateRef)) -or
    @($ChangedFiles).Count -gt 0 -or
    @($AffectedContracts).Count -gt 0 -or
    $UseExplicitAffectedContracts -or
    (-not [string]::IsNullOrWhiteSpace($NoBehaviorChangeFile))

if (-not $hasDynamicInput) {
    $panel = Read-JsonFile -Path $PanelFile
    $selection = @($panel.selection)
    if ($selection.Count -eq 0) { throw 'Release panel selection is empty' }
    $snapshot = $panel
} else {
    if ([string]::IsNullOrWhiteSpace($BaselineRef)) { $BaselineRef = 'working-tree-baseline' }
    if ([string]::IsNullOrWhiteSpace($CandidateRef)) { $CandidateRef = 'working-tree-candidate' }

    $changed = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-WorkingTreeRef -Ref $BaselineRef) -and -not (Test-WorkingTreeRef -Ref $CandidateRef)) {
        $range = "$BaselineRef..$CandidateRef"
        $gitOutput = @(& git -C $root diff --name-only --diff-filter=ACMRT $range 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Cannot resolve git diff $range`: $($gitOutput -join ' ')" }
        foreach ($path in $gitOutput) {
            $normalized = Normalize-RelativePath -Path ([string]$path)
            if ($normalized) { $changed.Add($normalized) }
        }
    }
    foreach ($path in @($ChangedFiles)) {
        $normalized = Normalize-RelativePath -Path ([string]$path)
        if ($normalized) { $changed.Add($normalized) }
    }
    $changedFilesFinal = @($changed | Sort-Object -Unique)

    $waivers = @()
    if (-not [string]::IsNullOrWhiteSpace($NoBehaviorChangeFile)) {
        $waiverData = Read-JsonFile -Path $NoBehaviorChangeFile
        $waivers = @($waiverData.entries)
    }

    $explicitAffectedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($id in @($AffectedContracts)) {
        if (-not $contractById.ContainsKey([string]$id)) { throw "Unknown affected contract: $id" }
        [void]$explicitAffectedIds.Add([string]$id)
    }
    if ($UseExplicitAffectedContracts -and $explicitAffectedIds.Count -eq 0) {
        throw 'UseExplicitAffectedContracts requires at least one AffectedContracts entry.'
    }

    $affectedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $unmappedFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $changedFilesFinal) {
        if (-not (Test-BehaviorPath -Path $path)) { continue }
        $matches = @($contracts | Where-Object { (Normalize-RelativePath -Path ([string]$_.source_file)) -eq $path })
        if ($matches.Count -eq 0) {
            if (-not (Test-Waiver -Waivers $waivers -SourceFile $path -ContractId '')) {
                $unmappedFiles.Add($path)
            }
            continue
        }
        if ($UseExplicitAffectedContracts) {
            $selectedMatches = @($matches | Where-Object { $explicitAffectedIds.Contains([string]$_.contract_id) })
            if ($selectedMatches.Count -eq 0) {
                if (-not (Test-Waiver -Waivers $waivers -SourceFile $path -ContractId '')) {
                    $unmappedFiles.Add($path)
                }
                continue
            }
            foreach ($contract in $selectedMatches) { [void]$affectedIds.Add([string]$contract.contract_id) }
        } else {
            foreach ($contract in $matches) { [void]$affectedIds.Add([string]$contract.contract_id) }
        }
    }
    foreach ($id in $explicitAffectedIds) { [void]$affectedIds.Add([string]$id) }
    if ($unmappedFiles.Count -gt 0) {
        throw "Behavior files have no contract mapping: $($unmappedFiles -join ', '). Add contract mappings or an audited no_behavior_change reason."
    }

    $affected = @($contracts | Where-Object { $affectedIds.Contains([string]$_.contract_id) } | Sort-Object contract_id)
    foreach ($contract in $affected) {
        $mappedCount = @($contract.stable_evals).Count + @($contract.challenge_evals).Count
        if ($mappedCount -eq 0 -and -not (Test-Waiver -Waivers $waivers -SourceFile ([string]$contract.source_file) -ContractId ([string]$contract.contract_id))) {
            throw "Affected contract has no eval mapping: $($contract.contract_id). Add an eval or an audited no_behavior_change reason."
        }
    }

    $seen = @{}
    $coreEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($core.selection)) {
        if (-not (Add-UniqueSelection -Target $coreEntries -Seen $seen -Entry $entry)) {
            throw "Duplicate core selection: $(Get-SelectionKey -Entry $entry)"
        }
    }

    $deltaEntries = [System.Collections.Generic.List[object]]::new()
    $deltaCandidates = [System.Collections.Generic.List[object]]::new()
    foreach ($contract in $affected) {
        foreach ($entry in @(Get-ContractEvalEntries -Contract $contract -ReasonPrefix 'contract-delta:')) { $deltaCandidates.Add($entry) }
    }
    foreach ($entry in @(Get-SortedSelection -Entries @($deltaCandidates))) {
        [void](Add-UniqueSelection -Target $deltaEntries -Seen $seen -Entry $entry)
    }

    $affectedRoutes = @($affected | ForEach-Object { @($_.routes) } | Sort-Object -Unique)
    $controlEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($route in $routeOrder) {
        if ($controlEntries.Count -ge 5) { break }
        if ($route -notin $affectedRoutes) { continue }
        $controlContracts = @($contracts | Where-Object {
            ([string]$_.contract_id -notin @($affected.contract_id | ForEach-Object { [string]$_ })) -and
            ($route -in @($_.routes))
        } | Sort-Object contract_id)
        $added = $false
        foreach ($contract in $controlContracts) {
            foreach ($candidate in @(Get-SortedSelection -Entries @(Get-ContractEvalEntries -Contract $contract -ReasonPrefix "adjacent-control:$route`:"))) {
                $candidate.category = 'control'
                if (Add-UniqueSelection -Target $controlEntries -Seen $seen -Entry $candidate) {
                    $added = $true
                    break
                }
            }
            if ($added) { break }
        }
    }

    $mode = 'release-panel'
    $upgradeReason = $null
    $selection = @($coreEntries) + @($deltaEntries) + @($controlEntries)
    if ($selection.Count -gt $MaxCases) {
        $mode = 'affected-route-full-regression'
        $upgradeReason = "Selection count $($selection.Count) exceeds max $MaxCases; affected routes are upgraded without truncating critical contracts."
        $seen = @{}
        $fullEntries = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in @($core.selection)) { [void](Add-UniqueSelection -Target $fullEntries -Seen $seen -Entry $entry) }
        $routeContracts = @($contracts | Where-Object {
            $contractRoutes = @($_.routes)
            @($contractRoutes | Where-Object { $_ -in $affectedRoutes }).Count -gt 0
        } | Sort-Object contract_id)
        $fullCandidates = [System.Collections.Generic.List[object]]::new()
        foreach ($contract in $routeContracts) {
            foreach ($entry in @(Get-ContractEvalEntries -Contract $contract -ReasonPrefix 'affected-route-full-regression:')) { $fullCandidates.Add($entry) }
        }
        foreach ($group in @($lifecycle.scenario_groups | Where-Object { [string]$_.status -eq 'active' -and [string]$_.route -in $affectedRoutes })) {
            foreach ($suite in @('stable', 'challenge')) {
                foreach ($id in @($group.("${suite}_evals"))) {
                    $fullCandidates.Add((New-SelectionEntry -Suite $suite -Id $id -Category 'scenario' -Route ([string]$group.route) -ContractId '' -ScenarioGroupId ([string]$group.group_id) -Reason "affected-route-scenario:$($group.group_id)"))
                }
            }
        }
        foreach ($entry in @(Get-SortedSelection -Entries @($fullCandidates))) { [void](Add-UniqueSelection -Target $fullEntries -Seen $seen -Entry $entry) }
        $selection = @($fullEntries)
        $controlEntries = [System.Collections.Generic.List[object]]::new()
    }

    $snapshot = [ordered]@{
        schema_version = 2
        name = "MyP-M-A $CandidateRef 发布面板"
        purpose = '固定核心、合同差量与相邻控制项；超过面板上限时显式升级为受影响入口全量回归。'
        baseline_ref = $BaselineRef
        candidate_ref = $CandidateRef
        mode = $mode
        max_cases = $MaxCases
        changed_files = @($changedFilesFinal)
        contract_selection_mode = if ($UseExplicitAffectedContracts) { 'explicit-audited' } else { 'source-file-expanded' }
        affected_contracts = @($affected | ForEach-Object { [string]$_.contract_id })
        affected_routes = @($affectedRoutes)
        unmapped_files = @()
        no_behavior_change = @($waivers)
        upgrade_reason = $upgradeReason
        selection_groups = [ordered]@{
            core = @($coreEntries)
            delta = @($deltaEntries)
            controls = @($controlEntries)
        }
        selection = @($selection)
    }
    if (-not [string]::IsNullOrWhiteSpace($SnapshotPath)) {
        $writtenSnapshot = Write-JsonFile -Value $snapshot -Path $SnapshotPath
        Write-Host "Release panel snapshot created: $writtenSnapshot"
    }
}

$seenCases = @{}
$selected = [System.Collections.Generic.List[object]]::new()
foreach ($entry in @($snapshot.selection)) {
    $key = Get-SelectionKey -Entry $entry
    if (-not (Test-SelectableCase -Key $key)) { throw "Frozen panel contains an inactive lifecycle case: $key" }
    if ($seenCases.ContainsKey($key)) { throw "Duplicate release-panel entry: $key" }
    $seenCases[$key] = $true
    $source = switch ([string]$entry.suite) {
        'stable' { @($stable.evals) }
        'challenge' { @($challenge.evals) }
        default { throw "Unsupported release-panel suite: $($entry.suite)" }
    }
    $match = @($source | Where-Object { [string]$_.id -eq [string]$entry.id })
    if ($match.Count -ne 1) { throw "Release-panel case not found or ambiguous: $key" }
    $selected.Add($match[0])
}

$result = [ordered]@{
    skill_name = 'mypm'
    display_name = 'MyP-M-A'
    version = [string]$stable.version
    purpose = [string]$snapshot.purpose
    panel_mode = [string]$snapshot.mode
    baseline_ref = [string]$snapshot.baseline_ref
    candidate_ref = [string]$snapshot.candidate_ref
    evals = @($selected)
}

$writtenOutput = Write-JsonFile -Value $result -Path $OutputPath
Write-Host "Release panel created: $writtenOutput"
Write-Host "Mode=$($snapshot.mode) cases=$($selected.Count) stable=$(@($snapshot.selection | Where-Object suite -eq 'stable').Count) challenge=$(@($snapshot.selection | Where-Object suite -eq 'challenge').Count) affected_contracts=$(@($snapshot.affected_contracts).Count)"
