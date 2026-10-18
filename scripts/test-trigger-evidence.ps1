$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'validation/validate-contracts.ps1')
if (-not (Get-Command Test-MypmTriggerEvidence -ErrorAction SilentlyContinue)) { throw 'Missing trigger evidence validator' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('mypm-trigger-' + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
function Save-Json($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), $utf8) }
function Assert-Case([bool]$Expected, [string]$Name) {
    $result = New-MypmValidationResult
    Test-MypmTriggerEvidence -Root $temp -Baseline $baseline -Trigger $cases -Result $result
    if (($result.Errors.Count -eq 0) -ne $Expected) { throw "$Name failed: $($result.Errors -join '; ')" }
}
try {
    New-Item -ItemType Directory -Path (Join-Path $temp 'evals/trigger-results') -Force | Out-Null
    $policy = @{trigger_verification=@{required_profiles=@(@{model='test-model';reasoning_effort='medium'})}}
    Save-Json $policy (Join-Path $temp 'evals/evaluation-policy.json')
    $path = Join-Path $temp 'evals/trigger-results/test.json'
    $cases = @(@{should_trigger=$true},@{should_trigger=$false})
    $answers = @{input_bundle_sha256=('a'*64);model='test-model';reasoning_effort='medium';predictions=@(@{id=1;should_trigger=$true;reason='product'},@{id=2;should_trigger=$false;reason='implementation'})}
    Save-Json $answers $path
    $run = @{model='test-model';reasoning_effort='medium';status='passed';valid_count=2;correct_count=2;incorrect_ids=@();answer_file='evals/trigger-results/test.json';answer_sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
    $baseline = @{schema_version=2;status='passed';input_hashes=@{input_bundle_sha256=('a'*64)};runs=@($run)}
    Assert-Case $true 'matching raw answers'
    $answers.predictions[1].should_trigger=$true
    Save-Json $answers $path
    Assert-Case $false 'tampered answers fail hash'
    $run.answer_sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
    Assert-Case $false 'wrong prediction cannot pass by summary'
    $answers.predictions[1].should_trigger=$false
    $answers.predictions[1].id=1
    Save-Json $answers $path
    $run.answer_sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
    Assert-Case $false 'duplicate identity'
    $answers.predictions[1].id=2
    $answers.input_bundle_sha256=('b'*64)
    Save-Json $answers $path
    $run.answer_sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
    Assert-Case $false 'wrong input identity'
    $answers.input_bundle_sha256=('a'*64)
    Save-Json $answers $path
    $run.answer_sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
    $run.reasoning_effort='high'
    Assert-Case $false 'wrong profile'
    $run.reasoning_effort='medium'
    $run.answer_file='../outside.json'
    Assert-Case $false 'outside evidence'
    $run.answer_file='evals/trigger-results/test.json'
    $baseline.runs=@($run,$run)
    Assert-Case $false 'duplicate model runs'
    $baseline.runs=@($run)
    $policy.trigger_verification.required_profiles=@()
    Save-Json $policy (Join-Path $temp 'evals/evaluation-policy.json')
    Assert-Case $false 'missing configured profiles'
    Write-Host 'Trigger evidence tests passed: one positive and eight negative fixtures; no model calls.'
} finally {
    $full = [IO.Path]::GetFullPath($temp)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $full.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $full -Leaf) -notlike 'mypm-trigger-*') { throw 'Unsafe fixture cleanup' }
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}
