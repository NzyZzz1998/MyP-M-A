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
    $allowedStates = @('candidate', 'local-committed', 'remote-synced')
    $records = [System.Collections.Generic.List[string]]::new()
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
    }
    if ($records.Count -eq 2 -and @($records | Select-Object -Unique).Count -ne 1) {
        Add-MypmValidationError -Result $result -Message 'README.md and notes/mypm-roadmap.md project-status markers must match'
    }

    $result.Metrics['files'] = $files.Count
    $result.Metrics['version'] = $version
    return $result
}
