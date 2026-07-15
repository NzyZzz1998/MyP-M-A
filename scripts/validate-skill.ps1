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

$triggerPath = Join-Path $root 'evals\trigger-evals.json'
try {
    $triggerData = [System.IO.File]::ReadAllText($triggerPath, $strictUtf8) | ConvertFrom-Json
    $positive = @($triggerData | Where-Object should_trigger).Count
    $negative = @($triggerData | Where-Object { -not $_.should_trigger }).Count
    if ($positive -lt 8 -or $negative -lt 8) {
        Add-Error "Trigger coverage too small: positive=$positive negative=$negative"
    }
} catch {
    Add-Error "Cannot parse trigger-evals.json: $($_.Exception.Message)"
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

Write-Host "MyP-M-A static validation passed: version=$skillVersion evals=$(@($evalData.evals).Count) triggers=$(@($triggerData).Count) files=$($textFiles.Count)"
exit 0
