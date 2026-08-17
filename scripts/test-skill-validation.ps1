$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mypm-validation-" + [Guid]::NewGuid().ToString('N'))

. (Join-Path $PSScriptRoot 'validation\validate-docs.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-evals.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-contracts.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-runtime.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-capabilities.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-external-benchmark.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-public-cases.ps1')

function Write-JsonFile {
    param($Value, [string]$Path)
    [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine, $utf8)
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-ValidationErrors {
    param([string]$FixtureRoot)
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($result in @(
        (Invoke-MypmDocsValidation -Root $FixtureRoot),
        (Invoke-MypmEvalsValidation -Root $FixtureRoot),
        (Invoke-MypmContractsValidation -Root $FixtureRoot),
        (Invoke-MypmRuntimeValidation -Root $FixtureRoot),
        (Invoke-MypmCapabilitiesValidation -Root $FixtureRoot),
        (Invoke-MypmExternalBenchmarkValidation -Root $FixtureRoot),
        (Invoke-MypmPublicCasesValidation -Root $FixtureRoot)
    )) {
        foreach ($message in @($result.Errors)) { $errors.Add([string]$message) }
    }
    return @($errors)
}

function New-FixtureCase {
    param([string]$Base, [string]$Name)
    $path = Join-Path $tempRoot $Name
    Copy-Item -LiteralPath $Base -Destination $path -Recurse
    return $path
}

function Assert-FailsWith {
    param([string]$FixtureRoot, [string]$Pattern, [string]$Name)
    $errors = @(Get-ValidationErrors -FixtureRoot $FixtureRoot)
    Assert-True -Condition ($errors.Count -gt 0) -Message "$Name did not fail"
    Assert-True -Condition (@($errors | Where-Object { $_ -match $Pattern }).Count -gt 0) -Message "$Name did not name the expected object. Errors=$($errors -join ' | ')"
}

try {
    $base = Join-Path $tempRoot 'base'
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    foreach ($file in @('SKILL.md', 'README.md', 'CHANGELOG.md')) {
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $base $file)
    }
    foreach ($directory in @('agents', 'capabilities', 'evals', 'examples', 'references', 'templates')) {
        Copy-Item -LiteralPath (Join-Path $root $directory) -Destination (Join-Path $base $directory) -Recurse
    }
    New-Item -ItemType Directory -Path (Join-Path $base 'notes') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'notes\mypm-roadmap.md') -Destination (Join-Path $base 'notes\mypm-roadmap.md')
    Copy-Item -LiteralPath (Join-Path $root 'notes\v0.36-capability-ecosystem-prd.md') -Destination (Join-Path $base 'notes\v0.36-capability-ecosystem-prd.md')

    $positiveErrors = @(Get-ValidationErrors -FixtureRoot $base)
    Assert-True -Condition ($positiveErrors.Count -eq 0) -Message "Positive fixture failed: $($positiveErrors -join ' | ')"

    $case = New-FixtureCase -Base $base -Name 'missing-contract'
    $path = Join-Path $case 'evals\contract-registry.json'
    $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $json.contracts = @($json.contracts | Where-Object contract_id -ne 'idea-core-output')
    Write-JsonFile -Value $json -Path $path
    Assert-FailsWith -FixtureRoot $case -Pattern 'unknown contract: idea-core-output' -Name 'missing contract'

    $case = New-FixtureCase -Base $base -Name 'duplicate-eval-id'
    $path = Join-Path $case 'evals\evals.json'
    $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $json.evals[1].id = $json.evals[0].id
    Write-JsonFile -Value $json -Path $path
    Assert-FailsWith -FixtureRoot $case -Pattern 'Duplicate eval id' -Name 'duplicate eval id'

    $case = New-FixtureCase -Base $base -Name 'stale-source-path'
    $path = Join-Path $case 'evals\contract-registry.json'
    $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $json.contracts[0].source_file = 'references/missing-contract-source.md'
    Write-JsonFile -Value $json -Path $path
    Assert-FailsWith -FixtureRoot $case -Pattern 'source file not found' -Name 'stale source path'

    $case = New-FixtureCase -Base $base -Name 'wrong-status'
    $path = Join-Path $case 'README.md'
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $text = [regex]::Replace($text, '(<!-- project-status: version=[^;]+; state=)[a-z-]+( -->)', '${1}unknown${2}', 1)
    [System.IO.File]::WriteAllText($path, $text, $utf8)
    Assert-FailsWith -FixtureRoot $case -Pattern 'Unsupported project-status state' -Name 'wrong status'

    $case = New-FixtureCase -Base $base -Name 'invalid-utf8'
    [System.IO.File]::WriteAllBytes((Join-Path $case 'references\invalid-utf8.md'), [byte[]](0xC3, 0x28))
    Assert-FailsWith -FixtureRoot $case -Pattern 'Non-UTF8 file: references/invalid-utf8.md' -Name 'invalid UTF-8'

    $case = New-FixtureCase -Base $base -Name 'panel-missing-mapping'
    $path = Join-Path $case 'evals\release-panel.json'
    $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $json.selection[0].contract_id = 'memory-auto-restore-attempt'
    Write-JsonFile -Value $json -Path $path
    Assert-FailsWith -FixtureRoot $case -Pattern 'Release panel case is not mapped' -Name 'panel missing mapping'

    $case = New-FixtureCase -Base $base -Name 'stale-trigger-summary'
    $path = Join-Path $case 'evals\trigger-baseline.json'
    $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $json.input_hashes.trigger_cases_sha256 = ('0' * 64)
    Write-JsonFile -Value $json -Path $path
    Assert-FailsWith -FixtureRoot $case -Pattern 'Stale trigger summary hash: trigger_cases_sha256' -Name 'stale trigger summary'

    $case = New-FixtureCase -Base $base -Name 'missing-eval-lifecycle'
    $path = Join-Path $case 'evals\eval-lifecycle.json'
    $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $json.scenario_groups[0].stable_evals = @($json.scenario_groups[0].stable_evals | Where-Object { [string]$_ -ne '2' })
    Write-JsonFile -Value $json -Path $path
    Assert-FailsWith -FixtureRoot $case -Pattern 'Eval lifecycle ownership missing: stable:2' -Name 'missing eval lifecycle ownership'

    $builder = Join-Path $root 'scripts\build-eval-panel.ps1'
    $replayOutput1 = Join-Path $tempRoot 'replay-1-evals.json'
    $replaySnapshot1 = Join-Path $tempRoot 'replay-1-panel.json'
    $replayOutput2 = Join-Path $tempRoot 'replay-2-evals.json'
    $replaySnapshot2 = Join-Path $tempRoot 'replay-2-panel.json'
    $hasBaselineRef = $false
    $hasCandidateRef = $false
    if ($null -ne (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $root '.git'))) {
        & git -C $root cat-file -e 'd1f19d6^{commit}' 2>$null
        $hasBaselineRef = $LASTEXITCODE -eq 0
        & git -C $root cat-file -e '4ca7de3^{commit}' 2>$null
        $hasCandidateRef = $LASTEXITCODE -eq 0
    }
    $replayArgs = @{
        AffectedContracts = @('acceptance-explicit-inheritance', 'prd-async-idempotency')
    }
    if ($hasBaselineRef -and $hasCandidateRef) {
        $replayArgs['BaselineRef'] = 'd1f19d6'
        $replayArgs['CandidateRef'] = '4ca7de3'
    } else {
        # Portable fallback for exported or shallow skill copies. The M1 gate itself
        # was executed against the real refs; this list preserves the same replay.
        $replayArgs['ChangedFiles'] = @(
            'SKILL.md',
            'references/capability-routing.md',
            'references/strategy-gtm.md',
            'references/tooling.md'
        )
    }
    & $builder @replayArgs -OutputPath $replayOutput1 -SnapshotPath $replaySnapshot1 | Out-Host
    & $builder @replayArgs -OutputPath $replayOutput2 -SnapshotPath $replaySnapshot2 | Out-Host
    $snapshot = Get-Content -Raw -Encoding UTF8 $replaySnapshot1 | ConvertFrom-Json
    $deltaKeys = @($snapshot.selection_groups.delta | ForEach-Object { "$($_.suite):$($_.id)" })
    Assert-True -Condition ('stable:36' -in $deltaKeys) -Message 'v0.33 replay did not select eval 36 from contract delta'
    Assert-True -Condition ('stable:61' -in $deltaKeys) -Message 'v0.33 replay did not select eval 61 from contract delta'
    $hash1 = (Get-FileHash -Algorithm SHA256 -LiteralPath $replaySnapshot1).Hash
    $hash2 = (Get-FileHash -Algorithm SHA256 -LiteralPath $replaySnapshot2).Hash
    Assert-True -Condition ($hash1 -eq $hash2) -Message 'Dynamic panel generation is not deterministic'

    $unknownRejected = $false
    try { & $builder -AffectedContracts @('missing-contract') -OutputPath (Join-Path $tempRoot 'unknown.json') | Out-Null } catch { $unknownRejected = $_.Exception.Message -match 'Unknown affected contract' }
    Assert-True -Condition $unknownRejected -Message 'Unknown affected contract was not rejected'

    $duplicateCore = Join-Path $tempRoot 'duplicate-core.json'
    $coreJson = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'evals\release-panel-core.json') | ConvertFrom-Json
    $coreJson.selection = @($coreJson.selection) + @($coreJson.selection[0])
    Write-JsonFile -Value $coreJson -Path $duplicateCore
    $duplicateRejected = $false
    try { & $builder -CoreFile $duplicateCore -AffectedContracts @('idea-core-output') -OutputPath (Join-Path $tempRoot 'duplicate.json') | Out-Null } catch { $duplicateRejected = $_.Exception.Message -match 'Duplicate core selection' }
    Assert-True -Condition $duplicateRejected -Message 'Duplicate core selection was not rejected'

    $unmappedRejected = $false
    try { & $builder -ChangedFiles @('references/unmapped-fixture.md') -OutputPath (Join-Path $tempRoot 'unmapped.json') | Out-Null } catch { $unmappedRejected = $_.Exception.Message -match 'no contract mapping' }
    Assert-True -Condition $unmappedRejected -Message 'Unmapped behavior file was not rejected'
    $waiverPath = Join-Path $tempRoot 'waiver.json'
    Write-JsonFile -Path $waiverPath -Value ([ordered]@{ schema_version = 1; entries = @([ordered]@{ source_file = 'references/unmapped-fixture.md'; reason = 'Fixture proves a documentation-only change.' }) })
    & $builder -ChangedFiles @('references/unmapped-fixture.md') -NoBehaviorChangeFile $waiverPath -OutputPath (Join-Path $tempRoot 'waived.json') | Out-Null

    $upgradeSnapshot = Join-Path $tempRoot 'upgrade-panel.json'
    & $builder -AffectedContracts @('prd-core-output') -MaxCases 3 -OutputPath (Join-Path $tempRoot 'upgrade-evals.json') -SnapshotPath $upgradeSnapshot | Out-Null
    $upgrade = Get-Content -Raw -Encoding UTF8 $upgradeSnapshot | ConvertFrom-Json
    Assert-True -Condition ([string]$upgrade.mode -eq 'affected-route-full-regression') -Message 'Panel limit did not upgrade to affected-route full regression'
    Assert-True -Condition (@($upgrade.selection).Count -gt 3) -Message 'Full-regression upgrade silently truncated critical contracts'

    Write-Host 'Skill validation fixtures passed: positive=1 negative=8 builder=replay/determinism/unknown/duplicate/unmapped/waiver/upgrade.'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolved = (Resolve-Path -LiteralPath $tempRoot).Path
        $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not ($resolved + '\').StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean path outside system temp: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
