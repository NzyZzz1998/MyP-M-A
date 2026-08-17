. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmDocsValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $extensions = @('.md', '.json', '.yaml', '.ps1', '.csv', '.sql', '.log')
    $markers = @([char]0xFFFD, [char]0x951B, [char]0x9286, [char]0x9235, [char]0x99A3, [char]0x95C1)
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in $extensions })

    foreach ($file in $files) {
        $relative = Get-MypmRelativePath -Root $root -Path $file.FullName
        $text = Read-MypmUtf8Text -Path $file.FullName -Result $result -Label $relative
        if ($null -eq $text) { continue }
        foreach ($marker in $markers) {
            if ($text.Contains([string]$marker)) {
                Add-MypmValidationError -Result $result -Message "Possible mojibake: $relative contains U+$([int]$marker).ToString('X4')"
            }
        }
    }

    $skillPath = Join-Path $root 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        Add-MypmValidationError -Result $result -Message 'Missing SKILL.md'
        return $result
    }
    $skill = Read-MypmUtf8Text -Path $skillPath -Result $result -Label 'SKILL.md'
    if ($null -eq $skill) { return $result }
    $frontmatter = [regex]::Match($skill, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|$)')
    if (-not $frontmatter.Success) {
        Add-MypmValidationError -Result $result -Message 'SKILL.md is missing valid YAML frontmatter'
    } elseif (-not [regex]::IsMatch($frontmatter.Groups['yaml'].Value, '(?m)^name:\s*mypm\s*$')) {
        Add-MypmValidationError -Result $result -Message 'SKILL.md frontmatter name must be mypm'
    }
    $version = Get-MypmSkillVersion -SkillText $skill
    if (-not $version) { Add-MypmValidationError -Result $result -Message 'SKILL.md is missing metadata.version' }

    $statusPattern = '<!-- project-status: version=([^;]+); state=([a-z-]+) -->'
    $allowedStates = @('candidate', 'stable-local-pending', 'local-committed', 'remote-synced')
    $records = [System.Collections.Generic.List[string]]::new()
    $stateByDocument = @{}
    foreach ($relative in @('README.md', 'notes/mypm-roadmap.md')) {
        $path = Resolve-MypmPath -Root $root -RelativePath $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-MypmValidationError -Result $result -Message "Missing status document: $relative"
            continue
        }
        $text = Read-MypmUtf8Text -Path $path -Result $result -Label $relative
        if ($null -eq $text) { continue }
        $match = [regex]::Match($text, $statusPattern)
        if (-not $match.Success) {
            Add-MypmValidationError -Result $result -Message "Missing project-status marker in $relative"
            continue
        }
        $state = $match.Groups[2].Value
        if ($state -notin $allowedStates) { Add-MypmValidationError -Result $result -Message "Unsupported project-status state in $relative`: $state" }
        if ($version -and $match.Groups[1].Value -ne $version) {
            Add-MypmValidationError -Result $result -Message "Project-status version mismatch in $relative`: SKILL=$version document=$($match.Groups[1].Value)"
        }
        $records.Add("$($match.Groups[1].Value)|$state")
        $stateByDocument[$relative] = $state
    }
    if ($records.Count -eq 2 -and @($records | Select-Object -Unique).Count -ne 1) {
        Add-MypmValidationError -Result $result -Message 'README.md and notes/mypm-roadmap.md project-status markers must match'
    }

    $stable = Read-MypmJson -Path (Join-Path $root 'evals\evals.json') -Result $result -Label 'evals/evals.json'
    $challenge = Read-MypmJson -Path (Join-Path $root 'evals\challenge-evals.json') -Result $result -Label 'evals/challenge-evals.json'
    if ($null -ne $stable -and $null -ne $challenge) {
        $stableTotal = [int](($stable.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
        $challengeTotal = [int](($challenge.evals | ForEach-Object { @($_.expectations).Count } | Measure-Object -Sum).Sum)
        $combinedTotal = $stableTotal + $challengeTotal
        $combinedPattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$combinedTotal))\b"
        $stablePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$stableTotal))\b"
        $challengePattern = "(?m)\b\d+\s*/\s*$([regex]::Escape([string]$challengeTotal))\b"
        $stablePending = "(?m)\u5F85\u8BC4\u6D4B\s*/\s*$([regex]::Escape([string]$stableTotal))\b"
        $challengePending = "(?m)\u5F85\u8BC4\u6D4B\s*/\s*$([regex]::Escape([string]$challengeTotal))\b"
        $stableNotRerun = "(?m)\u672A\u5168\u91CF\u91CD\u8DD1\s*/\s*$([regex]::Escape([string]$stableTotal))\b"
        $challengeNotRerun = "(?m)\u672A\u5168\u91CF\u91CD\u8DD1\s*/\s*$([regex]::Escape([string]$challengeTotal))\b"
        $allowPending = $stateByDocument['README.md'] -eq 'candidate'
        foreach ($relative in @('README.md', 'CHANGELOG.md', 'notes/mypm-roadmap.md')) {
            $path = Resolve-MypmPath -Root $root -RelativePath $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                Add-MypmValidationError -Result $result -Message "Missing evaluation status document: $relative"
                continue
            }
            $text = Read-MypmUtf8Text -Path $path -Result $result -Label $relative
            if ($null -eq $text) { continue }
            if ([regex]::IsMatch($text, $combinedPattern)) { Add-MypmValidationError -Result $result -Message "Stable and challenge eval scores must not be reported as a combined total in $relative" }
            if ((-not [regex]::IsMatch($text, $stablePattern)) -and (-not [regex]::IsMatch($text, $stableNotRerun)) -and (-not ($allowPending -and [regex]::IsMatch($text, $stablePending)))) {
                Add-MypmValidationError -Result $result -Message "Missing separate stable eval score in $relative"
            }
            if ((-not [regex]::IsMatch($text, $challengePattern)) -and (-not [regex]::IsMatch($text, $challengeNotRerun)) -and (-not ($allowPending -and [regex]::IsMatch($text, $challengePending)))) {
                Add-MypmValidationError -Result $result -Message "Missing separate challenge eval score in $relative"
            }
        }
    }

    $runtimeFiles = @(Get-Item -LiteralPath $skillPath) + @(Get-ChildItem -LiteralPath (Join-Path $root 'references') -File -Filter '*.md')
    $runtimeText = ($runtimeFiles | ForEach-Object { Read-MypmUtf8Text -Path $_.FullName -Result $result -Label (Get-MypmRelativePath -Root $root -Path $_.FullName) }) -join "`n"
    $referenceRegex = [regex]'`((?:references|templates)/[^`]+\.md)`'
    foreach ($file in $runtimeFiles) {
        $text = Read-MypmUtf8Text -Path $file.FullName -Result $result -Label (Get-MypmRelativePath -Root $root -Path $file.FullName)
        if ($null -eq $text) { continue }
        foreach ($match in $referenceRegex.Matches($text)) {
            $target = Resolve-MypmPath -Root $root -RelativePath $match.Groups[1].Value
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { Add-MypmValidationError -Result $result -Message "Broken reference: $($file.Name) -> $($match.Groups[1].Value)" }
        }
    }
    foreach ($reference in Get-ChildItem -LiteralPath (Join-Path $root 'references') -File -Filter '*.md') {
        if (-not $skill.Contains("references/$($reference.Name)") -and -not $runtimeText.Contains("references/$($reference.Name)")) { Add-MypmValidationWarning -Result $result -Message "Unrouted reference: $($reference.Name)" }
    }
    foreach ($template in Get-ChildItem -LiteralPath (Join-Path $root 'templates') -File -Filter '*.md') {
        if (-not $runtimeText.Contains("templates/$($template.Name)")) { Add-MypmValidationWarning -Result $result -Message "Unrouted template: $($template.Name)" }
    }

    $result.Metrics['files'] = $files.Count
    $result.Metrics['version'] = $version
    return $result
}
