$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mypm-v036-governance-" + [guid]::NewGuid().ToString('N'))
$utf8 = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'validation\validate-capabilities.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-external-benchmark.ps1')
. (Join-Path $PSScriptRoot 'validation\validate-public-cases.ps1')

function Write-TestFile {
    param([string]$Path, [string]$Content)
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Copy-EvalCatalogs {
    param([string]$Destination)
    New-Item -ItemType Directory -Path (Join-Path $Destination 'evals') -Force | Out-Null
    foreach ($name in @('evals.json', 'challenge-evals.json', 'trigger-evals.json')) {
        Copy-Item -LiteralPath (Join-Path $root "evals\$name") -Destination (Join-Path $Destination "evals\$name")
    }
}

function New-Capability {
    return [ordered]@{
        id = 'test.problem-validation'
        name_zh = '测试问题验证'
        domain = 'test'
        status = 'pilot'
        card_file = 'capabilities/test/problem-validation.md'
        entrypoints = @('/idea')
        stages = @('validate')
        triggers = @('存在待验证问题')
        anti_triggers = @('需求已确认并进入实施')
        required_inputs = @('问题', '用户', '证据')
        outputs = @('判断', '最小实验')
        evidence_contract = '区分事实与推断'
        tool_categories = @('project-read')
        fallback = '证据不足时标为待验证'
        references = @('references/test.md')
        eval_ids = [ordered]@{ stable = @(1); challenge = @(); trigger = @(1) }
        owner = 'mypm'
        introduced_in = '0.36.0'
    }
}

function New-Fixture {
    param([object[]]$Capabilities)
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Copy-EvalCatalogs -Destination $tempRoot
    Write-TestFile -Path (Join-Path $tempRoot 'references\test.md') -Content '# test'
    Write-TestFile -Path (Join-Path $tempRoot 'capabilities\test\problem-validation.md') -Content "# test`n`ncapability:test.problem-validation`n"
    $registry = [ordered]@{ schema_version = 1; updated_at = '2026-08-17T00:00:00Z'; capabilities = @($Capabilities) }
    Write-TestFile -Path (Join-Path $tempRoot 'capabilities\registry.json') -Content (($registry | ConvertTo-Json -Depth 20) + "`n")
}

function Assert-Validation {
    param([bool]$ShouldPass, [string]$Name)
    $result = Invoke-MypmCapabilitiesValidation -Root $tempRoot
    $passed = $result.Errors.Count -eq 0
    if ($passed -ne $ShouldPass) {
        throw "Unexpected capability validation result for $Name`: $($result.Errors -join '; ')"
    }
}

function New-BenchmarkFixture {
    param([scriptblock]$Mutate)

    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'evals\files') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'notes') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'evals\external-candidates.json') -Destination (Join-Path $tempRoot 'evals\external-candidates.json')
    Copy-Item -LiteralPath (Join-Path $root 'evals\external-benchmark.json') -Destination (Join-Path $tempRoot 'evals\external-benchmark.json')
    Copy-Item -LiteralPath (Join-Path $root 'evals\external-benchmark-contract.json') -Destination (Join-Path $tempRoot 'evals\external-benchmark-contract.json')
    Copy-Item -LiteralPath (Join-Path $root 'notes\v0.36-capability-ecosystem-prd.md') -Destination (Join-Path $tempRoot 'notes\v0.36-capability-ecosystem-prd.md')
    Copy-Item -LiteralPath (Join-Path $root 'evals\files\external-benchmark') -Destination (Join-Path $tempRoot 'evals\files\external-benchmark') -Recurse
    if ($null -ne $Mutate) {
        $path = Join-Path $tempRoot 'evals\external-benchmark.json'
        $document = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
        & $Mutate $document
        Write-TestFile -Path $path -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
}

function Assert-BenchmarkValidation {
    param([bool]$ShouldPass, [string]$Name)

    $result = Invoke-MypmExternalBenchmarkValidation -Root $tempRoot
    $passed = $result.Errors.Count -eq 0
    if ($passed -ne $ShouldPass) {
        throw "Unexpected external benchmark validation result for $Name`: $($result.Errors -join '; ')"
    }
}

function New-PublicCaseFixture {
    param([scriptblock]$Mutate)

    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'examples') -Destination (Join-Path $tempRoot 'examples') -Recurse
    if ($null -ne $Mutate) { & $Mutate $tempRoot }
}

function Assert-PublicCaseValidation {
    param([bool]$ShouldPass, [string]$Name, [string]$Pattern = '')

    $result = Invoke-MypmPublicCasesValidation -Root $tempRoot
    $passed = $result.Errors.Count -eq 0
    if ($passed -ne $ShouldPass) {
        throw "Unexpected public case validation result for $Name`: $($result.Errors -join '; ')"
    }
    if (-not $ShouldPass -and -not [string]::IsNullOrWhiteSpace($Pattern)) {
        if (@($result.Errors | Where-Object { $_ -match $Pattern }).Count -eq 0) {
            throw "Public case fixture $Name did not report expected pattern $Pattern`: $($result.Errors -join '; ')"
        }
    }
}

try {
    New-Fixture -Capabilities @((New-Capability))
    Assert-Validation -ShouldPass $true -Name 'positive'

    $first = New-Capability
    $second = New-Capability
    New-Fixture -Capabilities @($first, $second)
    Assert-Validation -ShouldPass $false -Name 'duplicate id and card'

    $item = New-Capability
    $item.anti_triggers = @()
    New-Fixture -Capabilities @($item)
    Assert-Validation -ShouldPass $false -Name 'missing anti trigger'

    $item = New-Capability
    $item.status = 'unknown'
    New-Fixture -Capabilities @($item)
    Assert-Validation -ShouldPass $false -Name 'invalid status'

    $item = New-Capability
    $item.references = @('references/missing.md')
    New-Fixture -Capabilities @($item)
    Assert-Validation -ShouldPass $false -Name 'missing reference'

    $item = New-Capability
    $item.card_file = 'C:\Users\example\card.md'
    New-Fixture -Capabilities @($item)
    Assert-Validation -ShouldPass $false -Name 'absolute card path'

    $item = New-Capability
    $item.eval_ids.stable = @(999999)
    New-Fixture -Capabilities @($item)
    Assert-Validation -ShouldPass $false -Name 'missing eval'

    New-BenchmarkFixture
    Assert-BenchmarkValidation -ShouldPass $true -Name 'benchmark positive'

    New-BenchmarkFixture -Mutate { param($document) $document.tasks = @($document.tasks | Select-Object -First 9) }
    Assert-BenchmarkValidation -ShouldPass $false -Name 'benchmark insufficient tasks'

    New-BenchmarkFixture -Mutate { param($document) $document.reporting.no_unified_total_score = $false }
    Assert-BenchmarkValidation -ShouldPass $false -Name 'benchmark unified total'

    New-BenchmarkFixture -Mutate { param($document) $document.tasks[0].candidate_context.PSObject.Properties.Remove('mypm-v036') }
    Assert-BenchmarkValidation -ShouldPass $false -Name 'benchmark missing candidate context'

    New-BenchmarkFixture -Mutate { param($document) $document.tasks[0].fixture = 'evals/files/external-benchmark/missing.md' }
    Assert-BenchmarkValidation -ShouldPass $false -Name 'benchmark missing fixture'

    New-BenchmarkFixture -Mutate { param($document) $document.tasks[0].candidate_context.'mypm-v036' = @('../SKILL.md') }
    Assert-BenchmarkValidation -ShouldPass $false -Name 'benchmark unsafe candidate path'

    New-BenchmarkFixture -Mutate { param($document) $document.tasks[0].semantic_key = 'interview_summary' }
    Assert-BenchmarkValidation -ShouldPass $false -Name 'benchmark PRD task contract drift'

    New-PublicCaseFixture
    Assert-PublicCaseValidation -ShouldPass $true -Name 'public case positive'

    New-PublicCaseFixture -Mutate {
        param($fixtureRoot)
        $path = Join-Path $fixtureRoot 'examples\dry-run\case-manifest.json'
        $document = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
        $document.authorization.redistribution_allowed = $false
        Write-TestFile -Path $path -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
    Assert-PublicCaseValidation -ShouldPass $false -Name 'public case authorization' -Pattern 'does not allow redistribution'

    New-PublicCaseFixture -Mutate {
        param($fixtureRoot)
        $path = Join-Path $fixtureRoot 'examples\dry-run\case-manifest.json'
        $document = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
        $document.artifacts[0].sha256 = ('0' * 64)
        Write-TestFile -Path $path -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
    Assert-PublicCaseValidation -ShouldPass $false -Name 'public case hash' -Pattern 'hash mismatch'

    New-PublicCaseFixture -Mutate {
        param($fixtureRoot)
        $artifactPath = Join-Path $fixtureRoot 'examples\dry-run\deliverable.md'
        $content = [System.IO.File]::ReadAllText($artifactPath, $utf8) + "`n证据路径：C:\Users\example\private.txt`n"
        Write-TestFile -Path $artifactPath -Content $content
        $manifestPath = Join-Path $fixtureRoot 'examples\dry-run\case-manifest.json'
        $document = [System.IO.File]::ReadAllText($manifestPath, $utf8) | ConvertFrom-Json
        $document.artifacts[1].sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant()
        Write-TestFile -Path $manifestPath -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
    Assert-PublicCaseValidation -ShouldPass $false -Name 'public case sensitive path' -Pattern 'Windows user path'

    New-PublicCaseFixture -Mutate {
        param($fixtureRoot)
        $path = Join-Path $fixtureRoot 'examples\index.json'
        $document = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
        $document.active_cases = @('deskflow-export-reliability')
        Write-TestFile -Path $path -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
    Assert-PublicCaseValidation -ShouldPass $false -Name 'public case withdrawn index' -Pattern 'active and withdrawn|remains in active index'

    New-PublicCaseFixture -Mutate {
        param($fixtureRoot)
        $path = Join-Path $fixtureRoot 'examples\dry-run\case-manifest.json'
        $document = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
        $document.evidence[0].locator = ''
        Write-TestFile -Path $path -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
    Assert-PublicCaseValidation -ShouldPass $false -Name 'public case evidence locator' -Pattern 'empty locator'

    New-PublicCaseFixture -Mutate {
        param($fixtureRoot)
        $path = Join-Path $fixtureRoot 'examples\dry-run\case-manifest.json'
        $document = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
        $document.privacy.scan_findings = 1
        Write-TestFile -Path $path -Content (($document | ConvertTo-Json -Depth 40) + "`n")
    }
    Assert-PublicCaseValidation -ShouldPass $false -Name 'public case privacy findings' -Pattern 'privacy scan has findings'

    Write-Host 'v0.36 governance self-test passed: capabilities positive=1 negative=6; benchmark positive=1 negative=6; public cases positive=1 negative=6'
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
