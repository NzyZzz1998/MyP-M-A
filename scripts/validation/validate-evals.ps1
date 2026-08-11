. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmEvalsValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $stable = Read-MypmJson -Path (Join-Path $root 'evals\evals.json') -Result $result -Label 'evals/evals.json'
    $challenge = Read-MypmJson -Path (Join-Path $root 'evals\challenge-evals.json') -Result $result -Label 'evals/challenge-evals.json'
    $trigger = Read-MypmJson -Path (Join-Path $root 'evals\trigger-evals.json') -Result $result -Label 'evals/trigger-evals.json'
    $core = Read-MypmJson -Path (Join-Path $root 'evals\release-panel-core.json') -Result $result -Label 'evals/release-panel-core.json'
    $panel = Read-MypmJson -Path (Join-Path $root 'evals\release-panel.json') -Result $result -Label 'evals/release-panel.json'
    $quality = Read-MypmJson -Path (Join-Path $root 'evals\delivery-quality-rubric.json') -Result $result -Label 'evals/delivery-quality-rubric.json'

    if ($null -ne $stable) {
        $ids = @{}
        foreach ($eval in @($stable.evals)) {
            $id = [string]$eval.id
            if ($ids.ContainsKey($id)) { Add-MypmValidationError -Result $result -Message "Duplicate eval id: $id" } else { $ids[$id] = $true }
            if (@($eval.expectations).Count -eq 0) { Add-MypmValidationError -Result $result -Message "Eval $id has no expectations" }
            foreach ($file in @($eval.files)) {
                $path = Resolve-MypmPath -Root $root -RelativePath ([string]$file)
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-MypmValidationError -Result $result -Message "Eval $id file not found: $file" }
            }
        }
        $requiredStable = @(46..81) + @(82, 83, 84)
        foreach ($id in $requiredStable) {
            if (-not $ids.ContainsKey([string]$id)) { Add-MypmValidationError -Result $result -Message "Missing required stable eval: $id" }
        }
    }

    if ($null -ne $challenge) {
        $ids = @{}
        foreach ($eval in @($challenge.evals)) {
            $id = [string]$eval.id
            if ($ids.ContainsKey($id)) { Add-MypmValidationError -Result $result -Message "Duplicate challenge eval id: $id" } else { $ids[$id] = $true }
            if (-not $id.StartsWith('CH-')) { Add-MypmValidationError -Result $result -Message "Challenge eval id must start with CH-: $id" }
            if (@($eval.expectations).Count -lt 7) { Add-MypmValidationError -Result $result -Message "Challenge eval $id needs at least 7 expectations" }
        }
        foreach ($id in @('CH-13', 'CH-14', 'CH-15', 'CH-16', 'CH-17', 'CH-18', 'CH-19', 'CH-20', 'CH-21')) {
            if (-not $ids.ContainsKey($id)) { Add-MypmValidationError -Result $result -Message "Missing required challenge eval: $id" }
        }
    }

    if ($null -ne $trigger) {
        $positive = @($trigger | Where-Object should_trigger).Count
        $negative = @($trigger | Where-Object { -not $_.should_trigger }).Count
        if ($positive -lt 8 -or $negative -lt 8) { Add-MypmValidationError -Result $result -Message "Trigger coverage too small: positive=$positive negative=$negative" }
        $queries = @{}
        foreach ($case in @($trigger)) {
            $query = [string]$case.query
            if ([string]::IsNullOrWhiteSpace($query)) { Add-MypmValidationError -Result $result -Message 'Trigger eval has an empty query' }
            elseif ($queries.ContainsKey($query)) { Add-MypmValidationError -Result $result -Message "Duplicate trigger query: $query" }
            else { $queries[$query] = $true }
            if ($case.should_trigger -isnot [bool]) { Add-MypmValidationError -Result $result -Message "Trigger should_trigger must be boolean: $query" }
        }
    }

    $stableIds = if ($null -ne $stable) { @($stable.evals.id | ForEach-Object { [string]$_ }) } else { @() }
    $challengeIds = if ($null -ne $challenge) { @($challenge.evals.id | ForEach-Object { [string]$_ }) } else { @() }
    $coreKeys = @{}
    if ($null -ne $core) {
        $expectedCategories = @('idea', 'review', 'prd', 'acceptance', 'prompt', 'data', 'tools', 'memory', 'high-risk-evidence')
        if (@($core.selection).Count -ne 9) { Add-MypmValidationError -Result $result -Message "Release core must contain exactly 9 cases: $(@($core.selection).Count)" }
        foreach ($entry in @($core.selection)) {
            $key = "$($entry.suite):$($entry.id)"
            if ($coreKeys.ContainsKey($key)) { Add-MypmValidationError -Result $result -Message "Duplicate release-core entry: $key" } else { $coreKeys[$key] = $true }
            if ([string]$entry.category -notin $expectedCategories) { Add-MypmValidationError -Result $result -Message "Unsupported release-core category: $($entry.category)" }
            if ([string]$entry.suite -eq 'stable' -and [string]$entry.id -notin $stableIds) { Add-MypmValidationError -Result $result -Message "Release-core stable case not found: $($entry.id)" }
            if ([string]$entry.suite -eq 'challenge' -and [string]$entry.id -notin $challengeIds) { Add-MypmValidationError -Result $result -Message "Release-core challenge case not found: $($entry.id)" }
        }
        foreach ($category in $expectedCategories) {
            if (@($core.selection | Where-Object { [string]$_.category -eq $category }).Count -ne 1) {
                Add-MypmValidationError -Result $result -Message "Release core category must appear once: $category"
            }
        }
    }

    if ($null -ne $panel) {
        $panelEntries = @($panel.selection)
        $panelKeys = @{}
        foreach ($entry in $panelEntries) {
            $key = "$($entry.suite):$($entry.id)"
            if ($panelKeys.ContainsKey($key)) { Add-MypmValidationError -Result $result -Message "Duplicate release-panel entry: $key" } else { $panelKeys[$key] = $true }
            if ([string]$entry.suite -eq 'stable' -and [string]$entry.id -notin $stableIds) { Add-MypmValidationError -Result $result -Message "Release-panel stable case not found: $($entry.id)" }
            if ([string]$entry.suite -eq 'challenge' -and [string]$entry.id -notin $challengeIds) { Add-MypmValidationError -Result $result -Message "Release-panel challenge case not found: $($entry.id)" }
        }
        $mode = [string]$panel.mode
        if ($mode -eq 'release-panel' -and ($panelEntries.Count -lt 9 -or $panelEntries.Count -gt [int]$panel.max_cases)) {
            Add-MypmValidationError -Result $result -Message "Release panel size outside 9..$($panel.max_cases): $($panelEntries.Count)"
        }
        foreach ($key in $coreKeys.Keys) {
            if (-not $panelKeys.ContainsKey($key)) { Add-MypmValidationError -Result $result -Message "Release panel is missing fixed core: $key" }
        }
    }

    if ($null -ne $quality) {
        if ($null -ne $quality.aggregate_score) { Add-MypmValidationError -Result $result -Message 'Delivery quality aggregate score must be null' }
        $qualityIds = @($quality.dimensions | ForEach-Object { [string]$_.id })
        $expectedQualityIds = @('correctness', 'decision_clarity', 'redundancy', 'actionability', 'response_chars', 'duration_ms', 'valid_return_rate')
        foreach ($qualityId in $expectedQualityIds) {
            if ($qualityId -notin $qualityIds) { Add-MypmValidationError -Result $result -Message "Missing delivery quality dimension: $qualityId" }
        }
        if ($qualityIds.Count -ne $expectedQualityIds.Count) { Add-MypmValidationError -Result $result -Message "Delivery quality dimension count mismatch: $($qualityIds.Count)" }
        $duration = @($quality.dimensions | Where-Object { [string]$_.id -eq 'duration_ms' })[0]
        if ($null -eq $duration -or [string]$duration.missing -ne 'unavailable') { Add-MypmValidationError -Result $result -Message 'Delivery quality duration missing policy must be unavailable' }
        if ([double]$quality.cost_boundary.response_chars_increase_ratio -ne 0.15 -or
            [double]$quality.cost_boundary.median_duration_increase_ratio -ne 0.25) {
            Add-MypmValidationError -Result $result -Message 'Delivery quality cost thresholds must remain 0.15 and 0.25'
        }
    }

    $result.Metrics['stable'] = if ($null -ne $stable) { @($stable.evals).Count } else { 0 }
    $result.Metrics['challenge'] = if ($null -ne $challenge) { @($challenge.evals).Count } else { 0 }
    $result.Metrics['trigger'] = if ($null -ne $trigger) { @($trigger).Count } else { 0 }
    $result.Metrics['quality_dimensions'] = if ($null -ne $quality) { @($quality.dimensions).Count } else { 0 }
    return $result
}
