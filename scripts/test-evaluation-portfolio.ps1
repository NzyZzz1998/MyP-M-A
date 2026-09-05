param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)
$generator = Join-Path $PSScriptRoot 'build-eval-inventory.ps1'
$panelBuilder = Join-Path $PSScriptRoot 'build-eval-panel.ps1'

. (Join-Path $PSScriptRoot 'validation\validate-evaluation-portfolio.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-contracts.ps1')

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Copy-PortfolioFixture {
    param([Parameter(Mandatory = $true)][string]$Destination, [switch]$IncludeContracts)

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'SKILL.md') -Destination (Join-Path $Destination 'SKILL.md')
    $evalDestination = Join-Path $Destination 'evals'
    New-Item -ItemType Directory -Force -Path $evalDestination | Out-Null
    foreach ($name in @('evals.json', 'challenge-evals.json', 'trigger-evals.json', 'contract-registry.json', 'eval-lifecycle.json', 'eval-state-registry.json', 'release-panel-core.json', 'release-panel.json', 'evaluation-policy.json', 'eval-inventory.json')) {
        Copy-Item -LiteralPath (Join-Path $root "evals\$name") -Destination (Join-Path $evalDestination $name)
    }
    $notes = Join-Path $Destination 'notes'
    New-Item -ItemType Directory -Force -Path $notes | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'notes\v0.41-evaluation-governance.md') -Destination $notes
    if ($IncludeContracts) {
        $registry = Read-FixtureJson (Join-Path $root 'evals\contract-registry.json')
        $paths = @('agents/openai.yaml', 'evals/trigger-baseline.json') + @($registry.contracts.source_file | Select-Object -Unique) + @($registry.contracts.related_source_files | ForEach-Object { $_ } | Where-Object { $_ } | Select-Object -Unique)
        foreach ($relative in $paths) {
            $destinationFile = Join-Path $Destination $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationFile) | Out-Null
            Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destinationFile
        }
    }
}

function Read-FixtureJson {
    param([string]$Path)
    return ([System.IO.File]::ReadAllText($Path, $utf8) | ConvertFrom-Json)
}

function Write-FixtureJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    $json = ($Value | ConvertTo-Json -Depth 40) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $json + "`n", $utf8)
}

function Set-FixtureState {
    param([string]$Fixture, [string]$Suite, [string]$Id, [string]$State, [string]$Successor = '')
    $path = Join-Path $Fixture 'evals\eval-state-registry.json'
    $registry = Read-FixtureJson $path
    if (@($registry.decisions | Where-Object id -eq 'fixture-transition').Count -eq 0) {
        $registry.decisions = @($registry.decisions) + @([ordered]@{ id = 'fixture-transition'; reason = 'Synthetic lifecycle test'; evidence = 'notes/v0.41-evaluation-governance.md' })
    }
    $event = [ordered]@{ state = $State; version = '0.41.0'; decision_id = 'fixture-transition' }
    if ($State -in @('archived', 'retired')) { $event.last_valid_version = '0.41.0' }
    if ($Successor) {
        $parts = $Successor.Split(':')
        $event.successor = [ordered]@{ suite = $parts[0]; id = $parts[1] }
    }
    $record = @($registry.records | Where-Object { [string]$_.suite -eq $Suite -and [string]$_.id -eq $Id })
    if ($record.Count -eq 0) {
        $registry.records = @($registry.records) + @([ordered]@{ suite = $Suite; id = $Id; history = @($event) })
    } else {
        $record[0].history = @($record[0].history) + @($event)
    }
    Write-FixtureJson -Path $path -Value $registry
}

function Update-FixtureInventory {
    param([string]$Fixture)
    $value = & $generator -RootPath $Fixture -AsObject
    Write-FixtureJson -Path (Join-Path $Fixture 'evals\eval-inventory.json') -Value $value
    return $value
}

& $generator -Check | Out-Host

$positive = Invoke-MypmEvaluationPortfolioValidation -Root $root
Assert-True ($positive.Errors.Count -eq 0) "Current evaluation portfolio must validate: $($positive.Errors -join '; ')"
$stable = Read-FixtureJson (Join-Path $root 'evals\evals.json')
$challenge = Read-FixtureJson (Join-Path $root 'evals\challenge-evals.json')
$triggers = @(Read-FixtureJson (Join-Path $root 'evals\trigger-evals.json'))
$core = Read-FixtureJson (Join-Path $root 'evals\release-panel-core.json')
$states = Read-FixtureJson (Join-Path $root 'evals\eval-state-registry.json')
$behaviorCount = @($stable.evals).Count + @($challenge.evals).Count
Assert-True ([int]$positive.Metrics.cases -eq ($behaviorCount + $triggers.Count)) 'Portfolio asset count must be derived from sources'
Assert-True ([int]$positive.Metrics.behavior -eq $behaviorCount) 'Portfolio behavior count must be derived from sources'
Assert-True ([int]$positive.Metrics.core -eq @($core.selection).Count) 'Portfolio core count drifted'
Assert-True ([int]$positive.Metrics.canary -eq @($states.records | Where-Object { [string]$_.history[-1].state -eq 'canary' }).Count) 'Portfolio canary count must follow persistent decisions'
$inventory = Read-FixtureJson (Join-Path $root 'evals\eval-inventory.json')
Assert-True (@($inventory.cases | Where-Object { [string]$_.route -eq 'unknown' }).Count -eq 0) 'Portfolio must not contain unclassified routes'
Assert-True ([int]$inventory.summary.routes.'outside-mypm' -eq @($triggers | Where-Object { -not $_.should_trigger }).Count) 'Negative trigger route count drifted'

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
$temp = [System.IO.Path]::GetFullPath((Join-Path $tempRoot ("mypm-evaluation-portfolio-" + [guid]::NewGuid().ToString('N'))))
$negativeCount = 0
$positiveCount = 1
try {
    $mutations = @(
        @{ name = 'stale-hash'; pattern = 'source hash is stale'; mutate = { param($value) $value.generated_from[0].sha256 = ('0' * 64) } },
        @{ name = 'invalid-state'; pattern = 'Unsupported lifecycle state'; mutate = { param($value) $value.cases[0].lifecycle_state = 'unknown-state' } },
        @{ name = 'unrecorded-state'; pattern = 'projection mismatch'; mutate = { param($value) $value.cases[0].lifecycle_state = 'archived' } },
        @{ name = 'wrong-expectations'; pattern = 'projection mismatch'; mutate = { param($value) $value.cases[0].expectation_count++ } },
        @{ name = 'wrong-contract'; pattern = 'projection mismatch'; mutate = {
            param($value)
            $owned = @($value.cases | Where-Object { $_.ownership_type -eq 'contract' })
            $replacement = @($owned | Where-Object { $_.contract_ids[0] -ne $owned[0].contract_ids[0] })[0].contract_ids[0]
            $owned[0].contract_ids = @($replacement)
        } },
        @{ name = 'wrong-route'; pattern = 'projection mismatch'; mutate = {
            param($value)
            $old = [string]$value.cases[0].route
            $new = if ($old -eq '/review') { '/prd' } else { '/review' }
            $value.cases[0].route = $new
            $value.summary.routes.$old--
            $value.summary.routes.$new++
        } }
    )
    foreach ($test in $mutations) {
        $fixture = Join-Path $temp $test.name
        Copy-PortfolioFixture -Destination $fixture
        $path = Join-Path $fixture 'evals\eval-inventory.json'
        $value = Read-FixtureJson $path
        & $test.mutate $value
        Write-FixtureJson -Path $path -Value $value
        $result = Invoke-MypmEvaluationPortfolioValidation -Root $fixture
        Assert-True (@($result.Errors | Where-Object { $_ -match $test.pattern }).Count -gt 0) "Expected failure was not detected: $($test.name)"
        $negativeCount++
    }

    $timeoutFixture = Join-Path $temp 'final-attempt-cutoff'
    Copy-PortfolioFixture -Destination $timeoutFixture
    $policyPath = Join-Path $timeoutFixture 'evals\evaluation-policy.json'
    $policy = Read-FixtureJson $policyPath
    $policy.execution_profiles.final_attempt_timeout_seconds = 600
    Write-FixtureJson -Path $policyPath -Value $policy
    $updated = & $generator -RootPath $timeoutFixture -AsObject
    Write-FixtureJson -Path (Join-Path $timeoutFixture 'evals\eval-inventory.json') -Value $updated
    $timeoutResult = Invoke-MypmEvaluationPortfolioValidation -Root $timeoutFixture
    Assert-True (@($timeoutResult.Errors | Where-Object { $_ -match 'without a time-based cutoff' }).Count -gt 0) 'A fresh inventory must not allow a final-attempt timeout'
    $negativeCount++

    $unknownFixture = Join-Path $temp 'unknown-trigger'
    Copy-PortfolioFixture -Destination $unknownFixture
    $triggerPath = Join-Path $unknownFixture 'evals\trigger-evals.json'
    $unknownTriggers = @(Read-FixtureJson $triggerPath) + @([pscustomobject]@{ query = 'Unclassified positive fixture'; should_trigger = $true })
    Write-FixtureJson -Path $triggerPath -Value $unknownTriggers
    Set-FixtureState -Fixture $unknownFixture -Suite trigger -Id ([string]$unknownTriggers.Count) -State canary
    $unknownResult = Invoke-MypmEvaluationPortfolioValidation -Root $unknownFixture
    Assert-True (@($unknownResult.Errors | Where-Object { $_ -match 'Unclassified positive trigger route' }).Count -gt 0) 'Unknown positive triggers must fail instead of becoming handoff'
    $negativeCount++

    $overrideFixture = Join-Path $temp 'stale-route-override'
    Copy-PortfolioFixture -Destination $overrideFixture
    $overridePolicyPath = Join-Path $overrideFixture 'evals\evaluation-policy.json'
    $overridePolicy = Read-FixtureJson $overridePolicyPath
    $overridePolicy.trigger_route_overrides[0].query_sha256 = ('0' * 64)
    Write-FixtureJson -Path $overridePolicyPath -Value $overridePolicy
    $overrideResult = Invoke-MypmEvaluationPortfolioValidation -Root $overrideFixture
    Assert-True (@($overrideResult.Errors | Where-Object { $_ -match 'override query hash is stale' }).Count -gt 0) 'Route override must bind the exact source query'
    $negativeCount++

    $growthFixture = Join-Path $temp 'valid-growth'
    Copy-PortfolioFixture -Destination $growthFixture
    $growthTriggerPath = Join-Path $growthFixture 'evals\trigger-evals.json'
    $growthTriggers = @(Read-FixtureJson $growthTriggerPath) + @([pscustomobject]@{ query = '/review synthetic growth fixture'; should_trigger = $true })
    Write-FixtureJson -Path $growthTriggerPath -Value $growthTriggers
    Set-FixtureState -Fixture $growthFixture -Suite trigger -Id ([string]$growthTriggers.Count) -State canary
    $grown = & $generator -RootPath $growthFixture -AsObject
    Write-FixtureJson -Path (Join-Path $growthFixture 'evals\eval-inventory.json') -Value $grown
    $growthResult = Invoke-MypmEvaluationPortfolioValidation -Root $growthFixture
    Assert-True ($growthResult.Errors.Count -eq 0) "Valid inventory growth must pass without editing count constants: $($growthResult.Errors -join '; ')"
    Assert-True ([int]$growthResult.Metrics.cases -eq ([int]$positive.Metrics.cases + 1)) 'Growth must add exactly one asset'
    Assert-True ([string]$grown.cases[-1].route -eq '/review') 'Explicit positive trigger route must be retained'
    $positiveCount++

    $policyMutations = @(
        @{ name = 'attempts'; pattern = 'three-attempt'; mutate = { param($value) $value.execution_profiles.max_attempts = 4 } },
        @{ name = 'concurrency'; pattern = 'max_concurrency'; mutate = { param($value) $value.execution_profiles.max_concurrency = 4 } },
        @{ name = 'runs'; pattern = 'runs_per_case'; mutate = { param($value) $value.execution_profiles.canonical.runs_per_case = 0 } },
        @{ name = 'retry'; pattern = 'missing: retry_policy'; mutate = { param($value) $value.execution_profiles.PSObject.Properties.Remove('retry_policy') } }
    )
    foreach ($test in $policyMutations) {
        $fixture = Join-Path $temp "invalid-policy-$($test.name)"
        Copy-PortfolioFixture -Destination $fixture
        $path = Join-Path $fixture 'evals\evaluation-policy.json'
        $value = Read-FixtureJson $path
        & $test.mutate $value
        Write-FixtureJson -Path $path -Value $value
        $null = Update-FixtureInventory $fixture
        $result = Invoke-MypmEvaluationPortfolioValidation -Root $fixture
        Assert-True (@($result.Errors | Where-Object { $_ -match $test.pattern }).Count -gt 0) "Invalid policy must fail: $($test.name)"
        $negativeCount++
    }

    $rotationFixture = Join-Path $temp 'panel-rotation'
    Copy-PortfolioFixture -Destination $rotationFixture
    $contracts = Read-FixtureJson (Join-Path $rotationFixture 'evals\contract-registry.json')
    $promptContract = @($contracts.contracts | Where-Object { '/prompt' -in $_.routes -and (@($_.stable_evals).Count + @($_.challenge_evals).Count) -gt 0 })[0]
    & $panelBuilder -RootPath $rotationFixture -AffectedContracts ([string]$promptContract.contract_id) -MaxCases 1000 -SnapshotPath 'evals/release-panel.json' -OutputPath 'panel-output.json' | Out-Host
    $rotated = Update-FixtureInventory $rotationFixture
    $rotationResult = Invoke-MypmEvaluationPortfolioValidation -Root $rotationFixture
    Assert-True ($rotationResult.Errors.Count -eq 0) "Rotated panel must validate: $($rotationResult.Errors -join '; ')"
    foreach ($before in $inventory.cases) {
        $after = @($rotated.cases | Where-Object { $_.suite -eq $before.suite -and [string]$_.id -eq [string]$before.id })[0]
        Assert-True ($after.lifecycle_state -eq $before.lifecycle_state) "Panel rotation changed lifecycle without a decision: $($before.suite):$($before.id)"
    }
    $positiveCount++

    $routeFixture = Join-Path $temp 'affected-route-full'
    Copy-PortfolioFixture -Destination $routeFixture -IncludeContracts
    $beforeExpansion = Invoke-MypmContractsValidation -Root $routeFixture
    Assert-True ($beforeExpansion.Errors.Count -eq 0) "Baseline fixture must pass contract validation: $($beforeExpansion.Errors -join '; ')"
    & $panelBuilder -RootPath $routeFixture -ChangedFiles 'SKILL.md' -MaxCases 1 -SnapshotPath 'evals/release-panel.json' -OutputPath 'panel-output.json' | Out-Host
    $expanded = Read-FixtureJson (Join-Path $routeFixture 'evals\release-panel.json')
    $null = Update-FixtureInventory $routeFixture
    $expandedPortfolio = Invoke-MypmEvaluationPortfolioValidation -Root $routeFixture
    Assert-True ($expandedPortfolio.Errors.Count -eq 0) 'Expanded standard snapshot must pass portfolio validation'
    $expandedContracts = Invoke-MypmContractsValidation -Root $routeFixture
    Assert-True ($expandedContracts.Errors.Count -eq 0) "Expanded standard snapshot must pass contract validation: $($expandedContracts.Errors -join '; ')"
    Assert-True ($expanded.mode -eq 'affected-route-full-regression') 'Overflow must explicitly escalate'
    $expandedKeys = @($expanded.selection | ForEach-Object { "$($_.suite):$($_.id)" })
    $scenarios = Read-FixtureJson (Join-Path $routeFixture 'evals\eval-lifecycle.json')
    $scenarioCount = 0
    foreach ($group in @($scenarios.scenario_groups | Where-Object { $_.status -eq 'active' -and $_.route -in $expanded.affected_routes })) {
        foreach ($suite in @('stable', 'challenge')) {
            foreach ($id in @($group.("${suite}_evals"))) {
                Assert-True ("${suite}:$id" -in $expandedKeys) "Affected route omitted scenario case: ${suite}:$id"
                $scenarioCount++
            }
        }
    }
    Assert-True ($scenarioCount -gt 0) 'Affected-route fixture must exercise scenario-only cases'
    Assert-True (@($expandedKeys | Select-Object -Unique).Count -eq $expandedKeys.Count) 'Affected-route panel must deduplicate cases'
    foreach ($entry in $core.selection) { Assert-True ("$($entry.suite):$($entry.id)" -in $expandedKeys) 'Affected-route expansion must retain the fixed core' }
    $positiveCount++

    $scenarioMutations = @(
        @{ name = 'missing-group'; pattern = 'unknown group'; mutate = { param($entry, $groups) $entry.PSObject.Properties.Remove('scenario_group_id') } },
        @{ name = 'unknown-group'; pattern = 'unknown group'; mutate = { param($entry, $groups) $entry.scenario_group_id = 'unknown-fixture-group' } },
        @{ name = 'wrong-group'; pattern = 'not mapped by scenario group'; mutate = { param($entry, $groups) $entry.scenario_group_id = @($groups | Where-Object { $_.group_id -ne $entry.scenario_group_id })[0].group_id } },
        @{ name = 'wrong-route'; pattern = 'route or group state mismatch'; mutate = { param($entry, $groups) $entry.route = if ($entry.route -eq '/review') { '/prd' } else { '/review' } } },
        @{ name = 'mixed-ownership'; pattern = 'conflicting ownership'; mutate = { param($entry, $groups) $entry.contract_id = 'idea-core-output' } },
        @{ name = 'invalid-suite'; pattern = 'unsupported suite'; mutate = { param($entry, $groups) $entry.suite = 'trigger' } }
    )
    $expandedPath = Join-Path $routeFixture 'evals\release-panel.json'
    foreach ($test in $scenarioMutations) {
        $mutated = ($expanded | ConvertTo-Json -Depth 40) | ConvertFrom-Json
        $entry = @($mutated.selection | Where-Object category -eq 'scenario')[0]
        & $test.mutate $entry @($scenarios.scenario_groups)
        Write-FixtureJson -Path $expandedPath -Value $mutated
        $result = Invoke-MypmContractsValidation -Root $routeFixture
        Assert-True (@($result.Errors | Where-Object { $_ -match $test.pattern }).Count -gt 0) "Forged scenario ownership must fail: $($test.name)"
        $negativeCount++
    }
    Write-FixtureJson -Path $expandedPath -Value $expanded
    $statePath = Join-Path $routeFixture 'evals\eval-state-registry.json'
    $savedStates = Read-FixtureJson $statePath
    $scenario = @($expanded.selection | Where-Object category -eq 'scenario')[0]
    foreach ($state in @('archived', 'retired')) {
        Set-FixtureState -Fixture $routeFixture -Suite ([string]$scenario.suite) -Id ([string]$scenario.id) -State $state -Successor "$($core.selection[0].suite):$($core.selection[0].id)"
        $result = Invoke-MypmContractsValidation -Root $routeFixture
        Assert-True (@($result.Errors | Where-Object { $_ -match 'inactive lifecycle state' }).Count -gt 0) "Frozen scenario must not retain an inactive state: $state"
        Write-FixtureJson -Path $statePath -Value $savedStates
        $negativeCount++
    }

    $inactiveFixture = Join-Path $temp 'inactive-states'
    Copy-PortfolioFixture -Destination $inactiveFixture
    Set-FixtureState -Fixture $inactiveFixture -Suite stable -Id 2 -State archived
    Set-FixtureState -Fixture $inactiveFixture -Suite stable -Id 3 -State retired -Successor 'stable:4'
    $inactive = Update-FixtureInventory $inactiveFixture
    $inactiveResult = Invoke-MypmEvaluationPortfolioValidation -Root $inactiveFixture
    Assert-True ($inactiveResult.Errors.Count -eq 0) "Audited inactive states must validate: $($inactiveResult.Errors -join '; ')"
    Assert-True ($inactive.summary.lifecycle_states.archived -eq 1 -and $inactive.summary.lifecycle_states.retired -eq 1) 'Inactive states must remain in the inventory'
    & $panelBuilder -RootPath $inactiveFixture -ChangedFiles 'SKILL.md' -MaxCases 1 -SnapshotPath 'expanded-panel.json' -OutputPath 'panel-output.json' | Out-Host
    $filtered = Read-FixtureJson (Join-Path $inactiveFixture 'expanded-panel.json')
    Assert-True (@($filtered.selection | Where-Object { $_.suite -eq 'stable' -and [string]$_.id -in @('2', '3') }).Count -eq 0) 'Archived and retired cases must be excluded from automatic selection'
    $positiveCount++

    $frozenPath = Join-Path $inactiveFixture 'evals\release-panel.json'
    $frozen = Read-FixtureJson $frozenPath
    $frozen.selection = @($frozen.selection) + @([ordered]@{ suite = 'stable'; id = 2 })
    Write-FixtureJson -Path $frozenPath -Value $frozen
    $frozenRejected = $false
    try { & $panelBuilder -RootPath $inactiveFixture -OutputPath 'invalid-panel.json' | Out-Host } catch { $frozenRejected = $_.Exception.Message -match 'inactive lifecycle case' }
    Assert-True $frozenRejected 'Inactive frozen selection must fail, not silently shrink the panel'
    $negativeCount++

    $successorFixture = Join-Path $temp 'missing-successor'
    Copy-PortfolioFixture -Destination $successorFixture
    Set-FixtureState -Fixture $successorFixture -Suite stable -Id 3 -State retired
    $successorResult = Invoke-MypmEvaluationPortfolioValidation -Root $successorFixture
    Assert-True (@($successorResult.Errors | Where-Object { $_ -match 'Retired case requires' }).Count -gt 0) 'Retirement requires a successor'
    $negativeCount++
} finally {
    if (Test-Path -LiteralPath $temp) {
        $resolved = (Resolve-Path -LiteralPath $temp).Path.TrimEnd('\', '/')
        $parent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolved)).TrimEnd('\', '/')
        if ($parent -ne $tempRoot -or (Split-Path -Leaf $resolved) -notmatch '^mypm-evaluation-portfolio-[0-9a-f]{32}$' -or ((Get-Item -LiteralPath $resolved).Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw "Refusing fixture cleanup outside the generated temporary directory: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

Write-Host "Evaluation portfolio self-test passed: assets=$($positive.Metrics.cases) behavior=$behaviorCount core=$($positive.Metrics.core) canary=$($positive.Metrics.canary) positive=$positiveCount negative=$negativeCount scenario_coverage=$scenarioCount"
