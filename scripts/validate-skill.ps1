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

foreach ($qualityFile in @('evals\README.md', 'scripts\regression-workspace.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $qualityFile) -PathType Leaf)) {
        Add-Error "Missing v0.23 quality file: $qualityFile"
    }
}

$regressionScriptPath = Join-Path $root 'scripts\regression-workspace.ps1'
if (Test-Path -LiteralPath $regressionScriptPath -PathType Leaf) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($regressionScriptPath, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        Add-Error "regression-workspace.ps1 parse error: $($parseError.Message)"
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

Write-Host "MyP-M-A static validation passed: version=$skillVersion evals=$(@($evalData.evals).Count) challenges=$(@($challengeData.evals).Count) triggers=$(@($triggerData).Count) files=$($textFiles.Count)"
exit 0
