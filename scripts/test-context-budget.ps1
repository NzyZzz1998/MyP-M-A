$ErrorActionPreference = 'Stop'
$measureScript = Join-Path $PSScriptRoot 'measure-context-budget.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mypm-context-budget-" + [guid]::NewGuid().ToString('N'))
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Write-TestFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $threw = $false
    try {
        & $Action
    } catch {
        $threw = $true
    }
    if (-not $threw) {
        throw "Expected failure was not raised: $Name"
    }
}

try {
    Write-TestFile -Path (Join-Path $tempRoot 'SKILL.md') -Content 'alpha'
    Write-TestFile -Path (Join-Path $tempRoot 'references\a.md') -Content (([string][char]0x4E2D) + ([char]0x6587))
    Write-TestFile -Path (Join-Path $tempRoot 'templates\t.md') -Content 'x'
    Write-TestFile -Path (Join-Path $tempRoot 'references\profile.md') -Content 'z'

    $manifest = @'
{
  "schema_version": 1,
  "baseline_version": "test",
  "normalization": {
    "newlines": "LF",
    "character_count": ".NET string Length",
    "byte_count": "UTF-8 without BOM",
    "path_base": "skill root",
    "file_order": "manifest order"
  },
  "heavy_route_average_target_percent": 15,
  "skill_char_budget": 5700,
  "routes": [
    {
      "route": "/test",
      "minimum_files": ["SKILL.md", "references/a.md"],
      "formal_files": ["templates/t.md"],
      "profiles": {"extended": {"files": ["references/profile.md"]}},
      "baseline": {
        "minimum": {"normalized_chars": 7, "utf8_bytes": 11},
        "formal": {"normalized_chars": 8, "utf8_bytes": 12},
        "profiles": {"extended": {"normalized_chars": 9, "utf8_bytes": 13}}
      },
      "target": {
        "counts_toward_heavy_average": true,
        "formal_reduction_percent": 15,
        "max_increase_percent": 5
      }
    }
  ]
}
'@
    $manifestPath = Join-Path $tempRoot 'evals\context-budget.json'
    Write-TestFile -Path $manifestPath -Content $manifest

    $first = Join-Path $tempRoot 'out\first.json'
    $second = Join-Path $tempRoot 'out\second.json'
    & $measureScript -RootPath $tempRoot -ManifestFile $manifestPath -OutputPath $first -Format Json
    & $measureScript -RootPath $tempRoot -ManifestFile $manifestPath -OutputPath $second -Format Json
    $firstData = [System.IO.File]::ReadAllText($first, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $secondData = [System.IO.File]::ReadAllText($second, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $firstData.generated_at = $null
    $secondData.generated_at = $null
    $firstComparable = $firstData | ConvertTo-Json -Depth 30 -Compress
    $secondComparable = $secondData | ConvertTo-Json -Depth 30 -Compress
    if ($firstComparable -ne $secondComparable) {
        throw 'Repeated context budget reports are not deterministic.'
    }
    if ($firstData.routes[0].minimum.normalized_chars -ne 7 -or $firstData.routes[0].formal.normalized_chars -ne 8) {
        throw 'Context budget fixture totals are incorrect.'
    }
    & $measureScript -RootPath $tempRoot -ManifestFile $manifestPath -OutputPath $first -Format Json
    if (-not (Test-Path -LiteralPath $first -PathType Leaf)) {
        throw 'Atomic overwrite did not preserve the output file.'
    }

    $missingManifest = Join-Path $tempRoot 'evals\missing.json'
    Write-TestFile -Path $missingManifest -Content $manifest.Replace('references/a.md', 'references/missing.md')
    Assert-Throws -Name 'missing file' -Action { & $measureScript -RootPath $tempRoot -ManifestFile $missingManifest | Out-Null }

    $duplicateManifest = Join-Path $tempRoot 'evals\duplicate.json'
    Write-TestFile -Path $duplicateManifest -Content $manifest.Replace('"templates/t.md"', '"references/a.md"')
    Assert-Throws -Name 'duplicate file' -Action { & $measureScript -RootPath $tempRoot -ManifestFile $duplicateManifest | Out-Null }

    $escapeManifest = Join-Path $tempRoot 'evals\escape.json'
    Write-TestFile -Path $escapeManifest -Content $manifest.Replace('references/a.md', '../outside.md')
    Assert-Throws -Name 'path escape' -Action { & $measureScript -RootPath $tempRoot -ManifestFile $escapeManifest | Out-Null }

    Assert-Throws -Name 'unknown route' -Action { & $measureScript -RootPath $tempRoot -ManifestFile $manifestPath -Route '/missing' | Out-Null }
    Assert-Throws -Name 'unknown baseline' -Action { & $measureScript -RootPath $tempRoot -ManifestFile $manifestPath -BaselineVersion 'other' | Out-Null }

    Write-Host 'Context budget self-test passed: cases=6'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
