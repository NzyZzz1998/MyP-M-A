param(
    [string]$PanelFile = 'evals\release-panel.json',
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Resolve-RepoFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
}

$panelPath = Resolve-RepoFile -Path $PanelFile
$panel = [System.IO.File]::ReadAllText($panelPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$stable = [System.IO.File]::ReadAllText((Join-Path $root 'evals\evals.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$challenge = [System.IO.File]::ReadAllText((Join-Path $root 'evals\challenge-evals.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$seen = @{}
$selected = [System.Collections.Generic.List[object]]::new()
foreach ($entry in @($panel.selection)) {
    $key = "$($entry.suite):$($entry.id)"
    if ($seen.ContainsKey($key)) {
        throw "Duplicate release-panel entry: $key"
    }
    $seen[$key] = $true

    $source = switch ([string]$entry.suite) {
        'stable' { @($stable.evals) }
        'challenge' { @($challenge.evals) }
        default { throw "Unsupported release-panel suite: $($entry.suite)" }
    }
    $match = @($source | Where-Object { [string]$_.id -eq [string]$entry.id })
    if ($match.Count -ne 1) {
        throw "Release-panel case not found or ambiguous: $key"
    }
    $selected.Add($match[0])
}

$result = [ordered]@{
    skill_name = 'mypm'
    display_name = 'MyP-M-A'
    version = [string]$stable.version
    purpose = [string]$panel.purpose
    evals = @($selected)
}

$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $outputFullPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllText(
    $outputFullPath,
    ($result | ConvertTo-Json -Depth 30) + [Environment]::NewLine,
    $utf8
)

Write-Host "Release panel created: $outputFullPath"
Write-Host "Cases=$($selected.Count) stable=$(@($panel.selection | Where-Object suite -eq 'stable').Count) challenge=$(@($panel.selection | Where-Object suite -eq 'challenge').Count)"
