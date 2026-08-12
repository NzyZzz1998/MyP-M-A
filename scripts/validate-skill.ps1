param(
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot 'validation\validate-core.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-docs.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-evals.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-contracts.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-runtime.ps1')

$results = [ordered]@{
    core = Invoke-MypmCoreValidation -Root $root
    docs = Invoke-MypmDocsValidation -Root $root
    evals = Invoke-MypmEvalsValidation -Root $root
    contracts = Invoke-MypmContractsValidation -Root $root
    runtime = Invoke-MypmRuntimeValidation -Root $root
}
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
foreach ($module in $results.Keys) {
    foreach ($message in @($results[$module].Errors)) { $errors.Add("$module validation: $message") }
    foreach ($message in @($results[$module].Warnings)) { $warnings.Add("$module validation: $message") }
}

if ($Strict) {
    foreach ($test in @(
        'test-evaluation-pipeline.ps1',
        'test-delivery-quality.ps1',
        'test-skill-validation.ps1'
    )) {
        try {
            & (Join-Path $PSScriptRoot $test) | Out-Host
        } catch {
            $errors.Add("Strict self-test failed ($test): $($_.Exception.Message)")
        }
    }
}

if ($Strict -and $warnings.Count -gt 0) {
    foreach ($warning in @($warnings)) { $errors.Add($warning) }
}
foreach ($warning in $warnings) { Write-Warning $warning }
if ($errors.Count -gt 0) {
    foreach ($item in $errors) { Write-Error $item }
    exit 1
}

$core = $results.core.Metrics
$evals = $results.evals.Metrics
$contracts = $results.contracts.Metrics
$docs = $results.docs.Metrics
Write-Host (
    'MyP-M-A static validation passed: ' +
    "version=$($core.version) " +
    "skill_chars=$($core.skill_chars)/$($core.skill_budget) " +
    "evals=$($evals.stable) challenges=$($evals.challenge) triggers=$($evals.trigger) " +
    "contracts=$($contracts.contracts) lifecycle_groups=$($contracts.lifecycle_groups) " +
    "files=$($docs.files) modules=$($results.Count) warnings=$($warnings.Count)"
)
exit 0
