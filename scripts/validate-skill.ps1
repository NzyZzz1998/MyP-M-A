param(
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Error([string]$message) { $errors.Add($message) }
function Add-Warning([string]$message) { $warnings.Add($message) }

$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
$textFiles = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in '.md', '.json', '.yaml', '.ps1', '.csv', '.sql', '.log' }
$mojibakeMarkers = @([char]0xFFFD, [char]0x951B, [char]0x9286, [char]0x9235, [char]0x99A3, [char]0x95C1)

foreach ($file in $textFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, $strictUtf8)
    } catch {
        Add-Error "Non-UTF8 file: $($file.FullName)"
        continue
    }

    foreach ($marker in $mojibakeMarkers) {
        if ($content.Contains([string]$marker)) {
            Add-Error "Possible mojibake: $($file.FullName) contains U+$([int]$marker).ToString('X4')"
        }
    }
}

$skillPath = Join-Path $root 'SKILL.md'
$skill = [System.IO.File]::ReadAllText($skillPath, $strictUtf8)
$skillCharBudget = 5700
if ($skill.Length -gt $skillCharBudget) {
    Add-Error "SKILL.md context budget exceeded: $($skill.Length) chars > $skillCharBudget"
}
if (-not $skill.Contains('entry-leading-slash')) {
    Add-Error 'SKILL.md must preserve the leading slash in entry commands'
}

$stageCorePatterns = [ordered]@{
    review = '(?s)### `/review`.*?(?=### `/idea`)'
    idea = '(?s)### `/idea`.*?(?=### `/prd`)'
    prd = '(?s)### `/prd`.*?(?=### `/acceptance`)'
    acceptance = '(?s)### `/acceptance`.*?(?=### `/prompt`)'
    prompt = '(?s)### `/prompt`.*?(?=\r?\n## )'
}
$stageCoreBudget = 600
foreach ($stage in $stageCorePatterns.Keys) {
    $stageMatch = [regex]::Match($skill, $stageCorePatterns[$stage])
    if (-not $stageMatch.Success) {
        Add-Error "Cannot locate the core /$stage section in SKILL.md"
    } elseif ($stageMatch.Value.Length -gt $stageCoreBudget) {
        Add-Error "SKILL.md /$stage core is too dense ($($stageMatch.Value.Length) chars > $stageCoreBudget); keep details in its reference"
    }
}

$requiredLoadingRoutes = [ordered]@{
    review = @('references/review.md', 'references/code-review-scanner.md')
    idea = @('references/idea.md')
    prd = @('references/prd.md')
    acceptance = @('references/acceptance.md', 'references/tooling.md')
    prompt = @('references/prompt.md', 'references/workflow-control.md')
}
foreach ($route in $requiredLoadingRoutes.Keys) {
    foreach ($referencePath in $requiredLoadingRoutes[$route]) {
        $referenceLiteral = [string][char]96 + $referencePath + [string][char]96
        if (-not $skill.Contains($referenceLiteral)) {
            Add-Error "SKILL.md /$route route is missing required reference: $referencePath"
        }
    }
}

$frontmatterMatch = [regex]::Match($skill, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|$)')
if (-not $frontmatterMatch.Success) {
    Add-Error 'SKILL.md is missing valid YAML frontmatter'
} else {
    $allowedFrontmatterKeys = @('name', 'description', 'license', 'allowed-tools', 'metadata')
    $frontmatterKeys = @(
        [regex]::Matches($frontmatterMatch.Groups['yaml'].Value, '(?m)^(?<key>[A-Za-z0-9_-]+):') |
            ForEach-Object { $_.Groups['key'].Value }
    )
    foreach ($key in @($frontmatterKeys | Select-Object -Unique)) {
        if ($key -notin $allowedFrontmatterKeys) {
            Add-Error "Unexpected SKILL.md frontmatter key under official quick validator: $key"
        }
    }
    foreach ($duplicateKey in @($frontmatterKeys | Group-Object | Where-Object Count -gt 1)) {
        Add-Error "Duplicate SKILL.md frontmatter key: $($duplicateKey.Name)"
    }
}

$versionMatch = [regex]::Match($skill, '(?m)^\s+version:\s+"([^"]+)"\s*$')
if (-not $versionMatch.Success) {
    Add-Error 'SKILL.md is missing metadata.version'
    $skillVersion = $null
} else {
    $skillVersion = $versionMatch.Groups[1].Value
}

$descriptionMatch = [regex]::Match($skill, '(?m)^description:\s+"?(.+?)"?\s*$')
if (-not $descriptionMatch.Success -or -not $descriptionMatch.Groups[1].Value.StartsWith('Use when')) {
    Add-Error 'SKILL.md description must start with Use when'
}

$interfacePath = Join-Path $root 'agents\openai.yaml'
if (-not (Test-Path -LiteralPath $interfacePath)) {
    Add-Error 'agents/openai.yaml is required for the single MyP-M-A UI entry'
} else {
    $interfaceText = [System.IO.File]::ReadAllText($interfacePath, $strictUtf8)
    if (-not $interfaceText.Contains('display_name: "MyP-M-A"')) {
        Add-Error 'agents/openai.yaml must display MyP-M-A'
    }
    if (-not $interfaceText.Contains('short_description:')) {
        Add-Error 'agents/openai.yaml is missing short_description'
    }
    if (-not $interfaceText.Contains('$mypm')) {
        Add-Error 'agents/openai.yaml default_prompt must reference $mypm'
    }
}

# Multiple mypm manifests below the skill scan root create ambiguous duplicate entries.
$scanRoot = Split-Path -Parent $root
$mypmManifests = @()
foreach ($manifest in Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Filter 'SKILL.md') {
    try {
        $manifestText = [System.IO.File]::ReadAllText($manifest.FullName, $strictUtf8)
        if ([regex]::IsMatch($manifestText, '(?m)^name:\s*mypm\s*$')) {
            $mypmManifests += $manifest.FullName
        }
    } catch {
        continue
    }
}
if ($mypmManifests.Count -ne 1 -or $mypmManifests[0] -ne $skillPath) {
    Add-Error "Expected exactly one mypm SKILL.md under $scanRoot; found: $($mypmManifests -join ', ')"
}

$evalPath = Join-Path $root 'evals\evals.json'
try {
    $evalData = [System.IO.File]::ReadAllText($evalPath, $strictUtf8) | ConvertFrom-Json
} catch {
    Add-Error "Cannot parse evals/evals.json: $($_.Exception.Message)"
    $evalData = $null
}

if ($null -ne $evalData) {
    if ($evalData.skill_name -ne 'mypm') { Add-Error 'evals skill_name must be mypm' }
    if ($skillVersion -and $evalData.version -ne $skillVersion) {
        Add-Error "Version mismatch: SKILL=$skillVersion evals=$($evalData.version)"
    }
    if (@($evalData.evals).Count -lt 56) {
        Add-Error "Stable eval coverage regressed: $(@($evalData.evals).Count)"
    }

    $ids = @{}
    foreach ($eval in $evalData.evals) {
        if ($ids.ContainsKey([string]$eval.id)) {
            Add-Error "Duplicate eval id: $($eval.id)"
        } else {
            $ids[[string]$eval.id] = $true
        }

        $propertyNames = @($eval.PSObject.Properties.Name)
        if ($propertyNames -contains 'assertions') {
            Add-Error "Eval $($eval.id) still uses assertions; use expectations"
        }
        if (-not ($propertyNames -contains 'expectations') -or @($eval.expectations).Count -eq 0) {
            Add-Error "Eval $($eval.id) has no expectations"
        }
        foreach ($relativeFile in @($eval.files)) {
            if (-not (Test-Path -LiteralPath (Join-Path $root $relativeFile))) {
                Add-Error "Eval $($eval.id) file not found: $relativeFile"
            }
        }
    }
}

$challengePath = Join-Path $root 'evals\challenge-evals.json'
try {
    $challengeData = [System.IO.File]::ReadAllText($challengePath, $strictUtf8) | ConvertFrom-Json
} catch {
    Add-Error "Cannot parse evals/challenge-evals.json: $($_.Exception.Message)"
    $challengeData = $null
}

if ($null -ne $challengeData) {
    if ($challengeData.skill_name -ne 'mypm') { Add-Error 'challenge evals skill_name must be mypm' }
    if ($skillVersion -and $challengeData.target_version -ne $skillVersion) {
        Add-Error "Challenge target mismatch: SKILL=$skillVersion challenge=$($challengeData.target_version)"
    }
    if (@($challengeData.evals).Count -lt 10) {
        Add-Error "Challenge coverage too small: $(@($challengeData.evals).Count)"
    }

    $challengeIds = @{}
    $challengeNames = @{}
    foreach ($eval in $challengeData.evals) {
        $id = [string]$eval.id
        $name = [string]$eval.name
        if ($challengeIds.ContainsKey($id)) {
            Add-Error "Duplicate challenge eval id: $id"
        } else {
            $challengeIds[$id] = $true
        }
        if ($challengeNames.ContainsKey($name)) {
            Add-Error "Duplicate challenge eval name: $name"
        } else {
            $challengeNames[$name] = $true
        }
        if (-not $id.StartsWith('CH-')) {
            Add-Error "Challenge eval id must start with CH-: $id"
        }
        foreach ($requiredProperty in @('name', 'prompt', 'expected_output', 'files', 'expectations')) {
            if (-not (@($eval.PSObject.Properties.Name) -contains $requiredProperty)) {
                Add-Error "Challenge eval $id is missing $requiredProperty"
            }
        }
        if (@($eval.expectations).Count -lt 7) {
            Add-Error "Challenge eval $id needs at least 7 discriminating expectations"
        }
        foreach ($expectation in @($eval.expectations)) {
            if ([string]::IsNullOrWhiteSpace([string]$expectation)) {
                Add-Error "Challenge eval $id has an empty expectation"
            }
        }
        foreach ($relativeFile in @($eval.files)) {
            if (-not (Test-Path -LiteralPath (Join-Path $root $relativeFile))) {
                Add-Error "Challenge eval $id file not found: $relativeFile"
            }
        }
    }
}

$statusDocuments = @('README.md', 'notes\mypm-roadmap.md')
$statusRecords = @{}
$statusPattern = '<!-- project-status: version=([^;]+); state=([a-z-]+) -->'
$allowedProjectStates = @('candidate', 'local-committed', 'remote-synced')
foreach ($relativePath in $statusDocuments) {
    $statusPath = Join-Path $root $relativePath
    $statusText = [System.IO.File]::ReadAllText($statusPath, $strictUtf8)
    $statusMatch = [regex]::Match($statusText, $statusPattern)
    if (-not $statusMatch.Success) {
        Add-Error "Missing project-status marker in $relativePath"
        continue
    }

    $statusVersion = $statusMatch.Groups[1].Value
    $statusState = $statusMatch.Groups[2].Value
    if ($skillVersion -and $statusVersion -ne $skillVersion) {
        Add-Error "Project-status version mismatch in $relativePath`: SKILL=$skillVersion document=$statusVersion"
    }
    if ($statusState -notin $allowedProjectStates) {
        Add-Error "Unsupported project-status state in $relativePath`: $statusState"
    }
    $statusRecords[$relativePath] = "$statusVersion|$statusState"
}
if ($statusRecords.Count -eq $statusDocuments.Count) {
    $uniqueStatusRecords = @($statusRecords.Values | Select-Object -Unique)
    if ($uniqueStatusRecords.Count -ne 1) {
        Add-Error 'README.md and notes/mypm-roadmap.md project-status markers must match'
    }
}

if ($null -ne $evalData -and $null -ne $challengeData) {
    $stableExpectationTotal = [int](($evalData.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
    $challengeExpectationTotal = [int](($challengeData.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
    $combinedExpectationTotal = $stableExpectationTotal + $challengeExpectationTotal
    $combinedScorePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$combinedExpectationTotal))\b"
    $stableScorePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$stableExpectationTotal))\b"
    $challengeScorePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$challengeExpectationTotal))\b"
    # Keep the Chinese marker escaped so Windows PowerShell 5.1 does not
    # misdecode this script when the UTF-8 file has no BOM.
    $stablePendingPattern = "(?m)\u5F85\u8BC4\u6D4B\s*/\s*$([regex]::Escape([string]$stableExpectationTotal))\b"
    $challengePendingPattern = "(?m)\u5F85\u8BC4\u6D4B\s*/\s*$([regex]::Escape([string]$challengeExpectationTotal))\b"
    $stableNotRerunPattern = "(?m)\u672A\u5168\u91CF\u91CD\u8DD1\s*/\s*$([regex]::Escape([string]$stableExpectationTotal))\b"
    $challengeNotRerunPattern = "(?m)\u672A\u5168\u91CF\u91CD\u8DD1\s*/\s*$([regex]::Escape([string]$challengeExpectationTotal))\b"
    $projectState = if ($statusRecords.ContainsKey('README.md')) { ($statusRecords['README.md'] -split '\|')[1] } else { $null }
    $allowPendingScores = $projectState -eq 'candidate'

    foreach ($relativePath in @('README.md', 'CHANGELOG.md', 'notes\mypm-roadmap.md')) {
        $reportText = [System.IO.File]::ReadAllText((Join-Path $root $relativePath), $strictUtf8)
        if ([regex]::IsMatch($reportText, $combinedScorePattern)) {
            Add-Error "Stable and challenge eval scores must not be reported as a combined total in $relativePath"
        }
        if ((-not [regex]::IsMatch($reportText, $stableScorePattern)) -and (-not [regex]::IsMatch($reportText, $stableNotRerunPattern)) -and (-not ($allowPendingScores -and [regex]::IsMatch($reportText, $stablePendingPattern)))) {
            Add-Error "Missing separate stable eval score in $relativePath"
        }
        if ((-not [regex]::IsMatch($reportText, $challengeScorePattern)) -and (-not [regex]::IsMatch($reportText, $challengeNotRerunPattern)) -and (-not ($allowPendingScores -and [regex]::IsMatch($reportText, $challengePendingPattern)))) {
            Add-Error "Missing separate challenge eval score in $relativePath"
        }
    }
}

$triggerPath = Join-Path $root 'evals\trigger-evals.json'
try {
    $triggerData = [System.IO.File]::ReadAllText($triggerPath, $strictUtf8) | ConvertFrom-Json
    $positive = @($triggerData | Where-Object should_trigger).Count
    $negative = @($triggerData | Where-Object { -not $_.should_trigger }).Count
    if ($positive -lt 8 -or $negative -lt 8) {
        Add-Error "Trigger coverage too small: positive=$positive negative=$negative"
    }
    $triggerQueries = @{}
    foreach ($trigger in $triggerData) {
        $query = [string]$trigger.query
        if ([string]::IsNullOrWhiteSpace($query)) {
            Add-Error 'Trigger eval has an empty query'
        } elseif ($triggerQueries.ContainsKey($query)) {
            Add-Error "Duplicate trigger query: $query"
        } else {
            $triggerQueries[$query] = $true
        }
        if ($trigger.should_trigger -isnot [bool]) {
            Add-Error "Trigger should_trigger must be boolean: $query"
        }
    }
} catch {
    Add-Error "Cannot parse trigger-evals.json: $($_.Exception.Message)"
}

$releasePanelPath = Join-Path $root 'evals\release-panel.json'
try {
    $releasePanel = [System.IO.File]::ReadAllText($releasePanelPath, $strictUtf8) | ConvertFrom-Json
    $panelEntries = @($releasePanel.selection)
    if ($panelEntries.Count -ne 13) {
        Add-Error "Release panel must contain exactly 13 cases: $($panelEntries.Count)"
    }
    $panelKeys = @{}
    foreach ($entry in $panelEntries) {
        $suite = [string]$entry.suite
        $id = [string]$entry.id
        $key = "$suite`:$id"
        if ($panelKeys.ContainsKey($key)) {
            Add-Error "Duplicate release-panel entry: $key"
        } else {
            $panelKeys[$key] = $true
        }
        if ($suite -eq 'stable') {
            if ($null -eq $evalData -or -not (@($evalData.evals.id | ForEach-Object { [string]$_ }) -contains $id)) {
                Add-Error "Release-panel stable case not found: $id"
            }
        } elseif ($suite -eq 'challenge') {
            if ($null -eq $challengeData -or -not (@($challengeData.evals.id | ForEach-Object { [string]$_ }) -contains $id)) {
                Add-Error "Release-panel challenge case not found: $id"
            }
        } else {
            Add-Error "Unsupported release-panel suite: $suite"
        }
    }
    if (@($panelEntries | Where-Object suite -eq 'stable').Count -eq 0 -or @($panelEntries | Where-Object suite -eq 'challenge').Count -eq 0) {
        Add-Error 'Release panel must include both stable and challenge cases'
    }
} catch {
    Add-Error "Cannot parse evals/release-panel.json: $($_.Exception.Message)"
}

foreach ($qualityFile in @('evals\README.md', 'scripts\regression-workspace.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $qualityFile) -PathType Leaf)) {
        Add-Error "Missing v0.23 quality file: $qualityFile"
    }
}

$requiredEvaluationScripts = @(
    'scripts\regression-workspace.ps1',
    'scripts\grading-batches.ps1',
    'scripts\test-evaluation-pipeline.ps1',
    'scripts\generate-eval-viewer.ps1',
    'scripts\build-eval-panel.ps1'
)
foreach ($relativeScriptPath in $requiredEvaluationScripts) {
    $scriptPath = Join-Path $root $relativeScriptPath
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Add-Error "Missing evaluation script: $relativeScriptPath"
        continue
    }
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        Add-Error "$relativeScriptPath parse error: $($parseError.Message)"
    }
}

if ($Strict) {
    try {
        & (Join-Path $root 'scripts\test-evaluation-pipeline.ps1') | Out-Host
    } catch {
        Add-Error "Evaluation pipeline self-test failed: $($_.Exception.Message)"
    }
}

$runtimeFiles = @(Get-Item -LiteralPath $skillPath) + @(Get-ChildItem (Join-Path $root 'references') -File -Filter '*.md')
$runtimeText = ($runtimeFiles | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName, $strictUtf8) }) -join "`n"

foreach ($requiredMemoryRule in @('memory_mode', 'auto', 'suggest', 'off', 'memory-continue', 'memory-notes', 'memory-capture')) {
    if (-not $runtimeText.Contains($requiredMemoryRule)) {
        Add-Error "Missing v0.20 Memory rule: $requiredMemoryRule"
    }
}

foreach ($requiredMemoryEvidenceRule in @('unavailable', 'not-found', 'memory-only', 'verified-source')) {
    if (-not $runtimeText.Contains($requiredMemoryEvidenceRule)) {
        Add-Error "Missing Memory evidence-state rule: $requiredMemoryEvidenceRule"
    }
}

foreach ($requiredPromptRule in @('/prompt', 'next', 'continue', 'bugfix', 'acceptance', 'release', 'handoff', 'commit', 'push', 'tag', 'Release')) {
    if (-not $runtimeText.Contains($requiredPromptRule)) {
        Add-Error "Missing prompt rule: $requiredPromptRule"
    }
}

foreach ($requiredCompressionRule in @('L1', 'L2', 'L3', '300-600', '500-900', '800-1500')) {
    if (-not $runtimeText.Contains($requiredCompressionRule)) {
        Add-Error "Missing v0.22 prompt compression rule: $requiredCompressionRule"
    }
}

foreach ($requiredOfficialPromptRule in @('zero-shot', 'preserve-first', 'trim-first', 'tool-orchestration', 'retry-limit', 'stop-condition')) {
    if (-not $runtimeText.Contains($requiredOfficialPromptRule)) {
        Add-Error "Missing official prompt-guidance rule: $requiredOfficialPromptRule"
    }
}

$contractAnchors = @{
    'SKILL.md' = @(
        'contract:entry-isolation',
        'idea-no-fabricated-threshold',
        'contract:context-minimal-loading',
        'contract:guarded-output-scan'
    )
    'evals\README.md' = @(
        'contract:separate-eval-scores',
        'contract:eval-execution-isolation',
        'contract:eval-release-panel-lifecycle'
    )
    'references\roadmap.md' = @(
        'contract:roadmap-core-output',
        'contract:roadmap-stage-explicit'
    )
    'references\idea.md' = @(
        'contract:idea-core-output',
        'contract:idea-feedback-role-binding',
        'contract:idea-discovery-methods',
        'contract:idea-strategy-gtm-evidence'
    )
    'references\review.md' = @(
        'contract:review-core-output',
        'contract:review-route-and-visual',
        'contract:review-slimming-evidence',
        'contract:review-evidence-handoff',
        'contract:review-finding-evidence-source',
        'contract:review-default-handoff',
        'contract:review-explicit-idea-candidates',
        'contract:review-code-scanner-layer',
        'contract:review-strategy-consistency'
    )
    'references\prd.md' = @(
        'contract:prd-known-facts',
        'contract:prd-core-output',
        'contract:prd-hifi-gate',
        'contract:prd-async-idempotency',
        'contract:prd-ui-coupling',
        'contract:prd-async-acceptance-matrix',
        'contract:prd-prototype-five-part',
        'contract:prd-prototype-gate-table',
        'contract:prd-input-blocker-stop',
        'contract:prd-ai-agent-four-part',
        'contract:prd-prototype-simulation-browser',
        'contract:prd-ai-agent-resilience-governance',
        'contract:prd-ambiguous-ui-questions',
        'contract:prd-convergence-preserves-browser-gate',
        'contract:prd-prototype-atomic-output',
        'contract:prd-strategy-gtm-boundary'
    )
    'references\prompt.md' = @(
        'contract:prompt-identity',
        'contract:recipient-profile',
        'contract:single-verification',
        'contract:subagent-budget',
        'contract:prompt-preserve-core',
        'contract:prompt-only-generation',
        'contract:prompt-release-spine',
        'contract:prompt-generation-first-line',
        'contract:prompt-render-shell',
        'contract:prompt-prerequisite-evidence-stop',
        'contract:prompt-subagent-long-tail',
        'contract:prompt-document-only-boundary',
        'contract:prompt-concept-handoff-facts',
        'contract:prompt-release-gate-details'
    )
    'references\data-analysis.md' = @(
        'contract:kpi-data-contract',
        'contract:metric-object-snapshot',
        'contract:metric-four-counts',
        'contract:metric-observed-final-state'
    )
    'references\capability-routing.md' = @(
        'contract:capability-minimal-route',
        'contract:capability-evidence-package',
        'contract:capability-acceptance-tracks',
        'contract:capability-code-review-scanner',
        'contract:capability-discovery-pack',
        'contract:capability-strategy-gtm-pack',
        'contract:capability-runtime-probe'
    )
    'references\tooling.md' = @(
        'contract:tooling-code-review-scanner',
        'contract:artifact-brand-isolation',
        'contract:tooling-capability-state'
    )
    'references\code-review-scanner.md' = @(
        'contract:code-review-scanner-purpose',
        'contract:code-review-scanner-privacy',
        'contract:code-review-scanner-delegation',
        'contract:code-review-scanner-evidence-closure'
    )
    'references\discovery.md' = @(
        'contract:discovery-method-selection',
        'contract:discovery-evidence-traceability',
        'contract:discovery-simulation-boundary',
        'contract:discovery-return-to-idea'
    )
    'references\strategy-gtm.md' = @(
        'contract:strategy-gtm-method-selection',
        'contract:strategy-gtm-evidence-boundary',
        'contract:strategy-gtm-choice-and-exclusion',
    'contract:strategy-gtm-pricing-boundary',
    'contract:strategy-gtm-return-to-stage',
    'contract:strategy-gtm-framework-pressure',
    'contract:strategy-gtm-mutually-exclusive-options',
    'contract:strategy-gtm-output-density'
    )
    'references\case-library.md' = @(
        'contract:case-library-historical-boundary',
        'contract:case-library-no-fact-inheritance'
    )
    'references\memory-integration.md' = @(
        'contract:memory-conflict-inventory',
        'contract:memory-auto-restore-attempt',
        'contract:memory-provenance',
        'contract:memory-stable-write'
    )
    'references\red-team.md' = @('contract:load-bearing-assumptions')
    'references\intent-implementation-audit.md' = @(
        'contract:intent-implementation-audit',
        'contract:conditional-shipping-surfaces'
    )
    'references\acceptance.md' = @(
        'contract:acceptance-evidence-impact',
        'contract:acceptance-core-output',
        'contract:acceptance-tool-manifest',
        'contract:acceptance-unsigned-installer',
        'contract:acceptance-selective-inheritance',
        'contract:acceptance-release-gate',
        'contract:acceptance-explicit-inheritance',
        'contract:acceptance-release-prerequisites',
        'contract:acceptance-artifact-evidence-freshness',
        'contract:acceptance-gap-closure-triples',
        'contract:acceptance-gap-closure-table',
        'contract:acceptance-no-evidence-substitution',
        'contract:acceptance-concrete-failure-injection'
    )
}
foreach ($entry in $contractAnchors.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    $content = [System.IO.File]::ReadAllText($path, $strictUtf8)
    foreach ($anchor in $entry.Value) {
        if (-not $content.Contains($anchor)) {
            Add-Error "Missing contract anchor in $($entry.Key): $anchor"
        }
    }
}

if ($null -ne $evalData) {
    foreach ($requiredPromptEval in 46..50) {
        if (-not (@($evalData.evals.id) -contains $requiredPromptEval)) {
            Add-Error "Missing v0.21 prompt eval: $requiredPromptEval"
        }
    }
    foreach ($requiredCompressionEval in 51..56) {
        if (-not (@($evalData.evals.id) -contains $requiredCompressionEval)) {
            Add-Error "Missing v0.22 prompt compression eval: $requiredCompressionEval"
        }
    }
    foreach ($requiredOfficialPromptEval in 57..59) {
        if (-not (@($evalData.evals.id) -contains $requiredOfficialPromptEval)) {
            Add-Error "Missing official prompt-guidance eval: $requiredOfficialPromptEval"
        }
    }
    foreach ($requiredPrdQuestionEval in 60..63) {
        if (-not (@($evalData.evals.id) -contains $requiredPrdQuestionEval)) {
            Add-Error "Missing PRD question-quality eval: $requiredPrdQuestionEval"
        }
    }
    foreach ($requiredV026Eval in 64..69) {
        if (-not (@($evalData.evals.id) -contains $requiredV026Eval)) {
            Add-Error "Missing v0.26 stable eval: $requiredV026Eval"
        }
    }
    foreach ($requiredV027Eval in 70..77) {
        if (-not (@($evalData.evals.id) -contains $requiredV027Eval)) {
            Add-Error "Missing v0.27 stable eval: $requiredV027Eval"
        }
    }
    foreach ($requiredV027Challenge in @('CH-13', 'CH-14', 'CH-15', 'CH-16')) {
        if (-not (@($challengeData.evals.id) -contains $requiredV027Challenge)) {
            Add-Error "Missing v0.27 challenge eval: $requiredV027Challenge"
        }
    }
    foreach ($requiredV028Eval in 78..81) {
        if (-not (@($evalData.evals.id) -contains $requiredV028Eval)) {
            Add-Error "Missing v0.28 stable eval: $requiredV028Eval"
        }
    }
    foreach ($requiredV028Challenge in @('CH-17', 'CH-18')) {
        if (-not (@($challengeData.evals.id) -contains $requiredV028Challenge)) {
            Add-Error "Missing v0.28 challenge eval: $requiredV028Challenge"
        }
    }
    if (-not (@($evalData.evals.id) -contains 82)) {
        Add-Error 'Missing code-review scanner stable eval: 82'
    }
    if (-not (@($challengeData.evals.id) -contains 'CH-19')) {
        Add-Error 'Missing code-review scanner challenge eval: CH-19'
    }
    if (-not (@($evalData.evals.id) -contains 83)) {
        Add-Error 'Missing Discovery stable eval: 83'
    }
    if (-not (@($challengeData.evals.id) -contains 'CH-20')) {
        Add-Error 'Missing Discovery challenge eval: CH-20'
    }
    if (-not (@($evalData.evals.id) -contains 84)) {
        Add-Error 'Missing Strategy/GTM stable eval: 84'
    }
    if (-not (@($challengeData.evals.id) -contains 'CH-21')) {
        Add-Error 'Missing Strategy/GTM challenge eval: CH-21'
    }
}
$referenceRegex = [regex]'`((?:references|templates)/[^`]+\.md)`'
foreach ($file in $runtimeFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, $strictUtf8)
    foreach ($match in $referenceRegex.Matches($content)) {
        $target = Join-Path $root ($match.Groups[1].Value.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $target)) {
            Add-Error "Broken reference: $($file.Name) -> $($match.Groups[1].Value)"
        }
    }
}

foreach ($reference in Get-ChildItem (Join-Path $root 'references') -File -Filter '*.md') {
    if (-not $skill.Contains("references/$($reference.Name)") -and -not $runtimeText.Contains("references/$($reference.Name)")) {
        Add-Warning "Unrouted reference: $($reference.Name)"
    }
}

foreach ($template in Get-ChildItem (Join-Path $root 'templates') -File -Filter '*.md') {
    if (-not $runtimeText.Contains("templates/$($template.Name)")) {
        Add-Warning "Unrouted template: $($template.Name)"
    }
}

if ($Strict -and $warnings.Count -gt 0) {
    foreach ($warning in $warnings) { Add-Error $warning }
}

foreach ($warning in $warnings) { Write-Warning $warning }
if ($errors.Count -gt 0) {
    foreach ($item in $errors) { Write-Error $item }
    exit 1
}

Write-Host "MyP-M-A static validation passed: version=$skillVersion skill_chars=$($skill.Length)/$skillCharBudget evals=$(@($evalData.evals).Count) challenges=$(@($challengeData.evals).Count) triggers=$(@($triggerData).Count) files=$($textFiles.Count)"
exit 0
