param(
    [string]$ManifestFile = 'evals\context-budget.json',
    [string]$Route = '',
    [ValidateSet('Json', 'Markdown')]
    [string]$Format = 'Json',
    [string]$OutputPath = '',
    [string]$BaselineVersion = '',
    [string]$RootPath = ''
)

$ErrorActionPreference = 'Stop'
$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
$outputUtf8 = [System.Text.UTF8Encoding]::new($false)
$defaultRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RootDirectory {
    param([string]$RequestedPath)

    $candidate = if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $defaultRoot } else { $RequestedPath }
    $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
        throw "Skill root is not a directory: $candidate"
    }
    return [System.IO.Path]::GetFullPath($resolved.Path).TrimEnd('\', '/')
}

function Resolve-ManifestPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $Root $Path }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
}

function Resolve-BudgetFile {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Context budget contains an empty file path.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Context budget paths must be relative to the Skill root: $RelativePath"
    }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    $rootPrefix = $Root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Context budget path escapes the Skill root: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Context budget file not found: $RelativePath"
    }
    return $candidate
}

function Get-ProfileStats {
    param(
        [Parameter(Mandatory = $true)][object[]]$Files,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $seen = @{}
    $fileResults = [System.Collections.Generic.List[object]]::new()
    $characterTotal = 0L
    $byteTotal = 0L

    foreach ($relativePathValue in $Files) {
        $relativePath = [string]$relativePathValue
        $key = $relativePath.Replace('/', '\').ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            throw "Duplicate context budget file: $relativePath"
        }
        $seen[$key] = $true

        $resolvedPath = Resolve-BudgetFile -RelativePath $relativePath -Root $Root
        $content = [System.IO.File]::ReadAllText($resolvedPath, $strictUtf8)
        $normalized = $content.Replace("`r`n", "`n").Replace("`r", "`n")
        $characters = [long]$normalized.Length
        $bytes = [long][System.Text.Encoding]::UTF8.GetByteCount($normalized)
        $characterTotal += $characters
        $byteTotal += $bytes
        $fileResults.Add([ordered]@{
            path = $relativePath.Replace('\', '/')
            normalized_chars = $characters
            utf8_bytes = $bytes
        })
    }

    return [ordered]@{
        files = @($fileResults)
        normalized_chars = $characterTotal
        utf8_bytes = $byteTotal
    }
}

function Test-Percent {
    param(
        $Value,
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$AllowMissing
    )

    if ($null -eq $Value) {
        if ($AllowMissing) { return }
        throw "Missing context budget threshold: $Name"
    }
    $number = 0.0
    if (-not [double]::TryParse([string]$Value, [ref]$number) -or $number -lt 0 -or $number -gt 100) {
        throw "Invalid context budget threshold $Name`: $Value"
    }
}

function New-Comparison {
    param(
        [Parameter(Mandatory = $true)]$Current,
        [Parameter(Mandatory = $true)]$Baseline,
        [Parameter(Mandatory = $true)][double]$MaxIncreasePercent,
        [Nullable[double]]$ReductionTargetPercent
    )

    $baselineChars = [long]$Baseline.normalized_chars
    $baselineBytes = [long]$Baseline.utf8_bytes
    if ($baselineChars -le 0 -or $baselineBytes -le 0) {
        throw 'Context budget baseline values must be positive.'
    }

    $charDelta = [long]$Current.normalized_chars - $baselineChars
    $byteDelta = [long]$Current.utf8_bytes - $baselineBytes
    $charPercent = [math]::Round(($charDelta * 100.0) / $baselineChars, 2)
    $bytePercent = [math]::Round(($byteDelta * 100.0) / $baselineBytes, 2)
    $reductionPercent = [math]::Round(-$charPercent, 2)

    $status = 'within_increase_limit'
    if ($charDelta -eq 0 -and $byteDelta -eq 0) {
        $status = 'baseline'
    } elseif ($charPercent -gt $MaxIncreasePercent) {
        $status = 'increase_exceeded'
    } elseif ($null -ne $ReductionTargetPercent -and $reductionPercent -lt [double]$ReductionTargetPercent) {
        $status = 'target_not_met'
    } elseif ($null -ne $ReductionTargetPercent) {
        $status = 'target_met'
    }

    return [ordered]@{
        baseline_normalized_chars = $baselineChars
        normalized_chars_delta = $charDelta
        normalized_chars_change_percent = $charPercent
        baseline_utf8_bytes = $baselineBytes
        utf8_bytes_delta = $byteDelta
        utf8_bytes_change_percent = $bytePercent
        reduction_percent = $reductionPercent
        status = $status
    }
}

function Write-AtomicText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $fullPath
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $temporaryPath = "$fullPath.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    $backupPath = "$fullPath.$PID.$([guid]::NewGuid().ToString('N')).bak"
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, $outputUtf8)
        if ([System.IO.File]::Exists($fullPath)) {
            [System.IO.File]::Replace($temporaryPath, $fullPath, $backupPath)
            [System.IO.File]::Delete($backupPath)
        } else {
            [System.IO.File]::Move($temporaryPath, $fullPath)
        }
    } finally {
        if ([System.IO.File]::Exists($temporaryPath)) {
            [System.IO.File]::Delete($temporaryPath)
        }
        if ([System.IO.File]::Exists($backupPath)) {
            [System.IO.File]::Delete($backupPath)
        }
    }
}

function Convert-ReportToMarkdown {
    param([Parameter(Mandatory = $true)]$Report)

    function Expand-UnicodeText {
        param([Parameter(Mandatory = $true)][string]$Value)
        return [regex]::Unescape($Value)
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add((Expand-UnicodeText '# MyP-M-A \u4e0a\u4e0b\u6587\u9884\u7b97\u62a5\u544a'))
    $lines.Add('')
    $lines.Add((Expand-UnicodeText '- \u57fa\u7ebf\u7248\u672c\uff1a') + "``$($Report.baseline_version)``")
    $lines.Add((Expand-UnicodeText '- \u751f\u6210\u65f6\u95f4\uff1a') + $Report.generated_at)
    $lines.Add((Expand-UnicodeText '- \u89c4\u8303\u5316\uff1a') + "$($Report.normalization.newlines) / $($Report.normalization.character_count) / $($Report.normalization.byte_count)")
    $lines.Add('')
    $lines.Add((Expand-UnicodeText '| \u5165\u53e3 | \u914d\u7f6e | \u5f53\u524d\u5b57\u7b26 | \u57fa\u7ebf\u5b57\u7b26 | \u53d8\u5316 | \u72b6\u6001 |'))
    $lines.Add('|---|---|---:|---:|---:|---|')
    foreach ($routeResult in @($Report.routes)) {
        foreach ($profileName in @('minimum', 'formal') + @($routeResult.profiles.PSObject.Properties.Name)) {
            $profile = if ($profileName -eq 'minimum') { $routeResult.minimum } elseif ($profileName -eq 'formal') { $routeResult.formal } else { $routeResult.profiles.$profileName }
            $lines.Add("| ``$($routeResult.route)`` | ``$profileName`` | $($profile.normalized_chars) | $($profile.comparison.baseline_normalized_chars) | $($profile.comparison.normalized_chars_change_percent)% | ``$($profile.comparison.status)`` |")
        }
    }
    $lines.Add('')
    $averageText = if ($null -eq $Report.heavy_route_summary.average_formal_reduction_percent) { 'unavailable' } else { "$($Report.heavy_route_summary.average_formal_reduction_percent)%" }
    $lines.Add((Expand-UnicodeText '- \u56db\u4e2a\u91cd\u5165\u53e3\u6b63\u5f0f\u52a0\u8f7d\u5e73\u5747\u4e0b\u964d\uff1a') + $averageText)
    $lines.Add((Expand-UnicodeText '- \u91cd\u5165\u53e3\u76ee\u6807\uff1a') + "$($Report.heavy_route_summary.target_percent)%")
    $lines.Add((Expand-UnicodeText '- \u5f53\u524d\u72b6\u6001\uff1a') + "``$($Report.heavy_route_summary.status)``")
    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

$root = Resolve-RootDirectory -RequestedPath $RootPath
$manifestPath = Resolve-ManifestPath -Path $ManifestFile -Root $root
$manifest = [System.IO.File]::ReadAllText($manifestPath, $strictUtf8) | ConvertFrom-Json

if ([int]$manifest.schema_version -ne 1) {
    throw "Unsupported context budget schema_version: $($manifest.schema_version)"
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.baseline_version)) {
    throw 'Context budget baseline_version is required.'
}
if ($BaselineVersion -and $BaselineVersion -ne [string]$manifest.baseline_version) {
    throw "Requested baseline is unavailable: $BaselineVersion"
}
Test-Percent -Value $manifest.heavy_route_average_target_percent -Name 'heavy_route_average_target_percent'

$routeNames = @{}
$selectedRoutes = [System.Collections.Generic.List[object]]::new()
foreach ($routeConfig in @($manifest.routes)) {
    $routeName = [string]$routeConfig.route
    if ([string]::IsNullOrWhiteSpace($routeName)) {
        throw 'Context budget contains an empty route.'
    }
    if ($routeNames.ContainsKey($routeName)) {
        throw "Duplicate context budget route: $routeName"
    }
    $routeNames[$routeName] = $true
    if (-not $Route -or $Route -eq $routeName) {
        $selectedRoutes.Add($routeConfig)
    }
}
if ($Route -and -not $routeNames.ContainsKey($Route)) {
    throw "Unknown context budget route: $Route"
}
if ($selectedRoutes.Count -eq 0) {
    throw 'Context budget has no routes to measure.'
}

$routeResults = [System.Collections.Generic.List[object]]::new()
$heavyReductions = [System.Collections.Generic.List[double]]::new()
foreach ($routeConfig in $selectedRoutes) {
    $routeName = [string]$routeConfig.route
    Test-Percent -Value $routeConfig.target.max_increase_percent -Name "$routeName.max_increase_percent"
    Test-Percent -Value $routeConfig.target.formal_reduction_percent -Name "$routeName.formal_reduction_percent"
    Test-Percent -Value $routeConfig.target.pilot_reduction_percent -Name "$routeName.pilot_reduction_percent" -AllowMissing

    $minimumFiles = @($routeConfig.minimum_files)
    $formalFiles = @($minimumFiles) + @($routeConfig.formal_files)
    $minimum = Get-ProfileStats -Files $minimumFiles -Root $root
    $formal = Get-ProfileStats -Files $formalFiles -Root $root
    $minimum.comparison = New-Comparison -Current $minimum -Baseline $routeConfig.baseline.minimum -MaxIncreasePercent ([double]$routeConfig.target.max_increase_percent)
    $formal.comparison = New-Comparison -Current $formal -Baseline $routeConfig.baseline.formal -MaxIncreasePercent ([double]$routeConfig.target.max_increase_percent) -ReductionTargetPercent ([double]$routeConfig.target.formal_reduction_percent)

    $profileResults = [ordered]@{}
    foreach ($profileProperty in @($routeConfig.profiles.PSObject.Properties)) {
        $profileName = [string]$profileProperty.Name
        $profileFiles = @($formalFiles) + @($profileProperty.Value.files)
        $profileBaseline = $routeConfig.baseline.profiles.$profileName
        if ($null -eq $profileBaseline) {
            throw "Missing context budget baseline for $routeName profile $profileName"
        }
        $profile = Get-ProfileStats -Files $profileFiles -Root $root
        $profile.comparison = New-Comparison -Current $profile -Baseline $profileBaseline -MaxIncreasePercent ([double]$routeConfig.target.max_increase_percent)
        $profileResults[$profileName] = $profile
    }

    if ([bool]$routeConfig.target.counts_toward_heavy_average) {
        $heavyReductions.Add([double]$formal.comparison.reduction_percent)
    }
    $routeResults.Add([ordered]@{
        route = $routeName
        target = $routeConfig.target
        minimum = $minimum
        formal = $formal
        profiles = [pscustomobject]$profileResults
    })
}

$heavyAverage = if ($heavyReductions.Count -eq 0) { $null } else { [math]::Round((($heavyReductions | Measure-Object -Average).Average), 2) }
$heavyTarget = [double]$manifest.heavy_route_average_target_percent
$heavyStatus = if ($null -eq $heavyAverage) { 'not_applicable' } elseif (@($heavyReductions | Where-Object { $_ -ne 0 }).Count -eq 0) { 'baseline' } elseif ($heavyAverage -ge $heavyTarget) { 'target_met' } else { 'target_not_met' }

$report = [ordered]@{
    schema_version = 1
    generated_at = [DateTime]::UtcNow.ToString('o')
    root = $root.Replace('\', '/')
    manifest = $manifestPath.Replace('\', '/')
    baseline_version = [string]$manifest.baseline_version
    normalization = $manifest.normalization
    routes = @($routeResults)
    heavy_route_summary = [ordered]@{
        route_count = $heavyReductions.Count
        average_formal_reduction_percent = $heavyAverage
        target_percent = $heavyTarget
        status = $heavyStatus
    }
}

$content = if ($Format -eq 'Markdown') {
    Convert-ReportToMarkdown -Report ([pscustomobject]$report)
} else {
    ($report | ConvertTo-Json -Depth 30) + [Environment]::NewLine
}

if ($OutputPath) {
    Write-AtomicText -Path $OutputPath -Content $content
    Write-Host "Context budget report written: $([System.IO.Path]::GetFullPath($OutputPath))"
} else {
    Write-Output $content
}
