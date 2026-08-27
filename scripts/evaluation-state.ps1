function Get-MypmEvaluationStateMap {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$AllowLegacy
    )

    $path = Join-Path $Root 'evals\eval-state-registry.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        if ($AllowLegacy) { return @{} }
        throw 'Missing persistent evaluation state registry'
    }
    $data = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([int]$data.schema_version -ne 1) { throw 'Unsupported evaluation state registry schema' }
    $decisions = @{}
    foreach ($decision in @($data.decisions)) {
        $id = [string]$decision.id
        if ([string]::IsNullOrWhiteSpace($id) -or $decisions.ContainsKey($id) -or [string]::IsNullOrWhiteSpace([string]$decision.reason)) {
            throw "Invalid evaluation lifecycle decision: $id"
        }
        $relative = [string]$decision.evidence
        if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative)) { throw "Decision evidence must be repository-relative: $id" }
        $evidence = [System.IO.Path]::GetFullPath((Join-Path $Root $relative))
        $prefix = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $evidence.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $evidence -PathType Leaf)) {
            throw "Decision evidence is missing or outside the repository: $id"
        }
        $decisions[$id] = $decision
    }
    $states = @{}
    foreach ($record in @($data.records)) {
        $key = "$([string]$record.suite):$([string]$record.id)"
        if ([string]$record.suite -notin @('stable', 'challenge', 'trigger') -or [string]::IsNullOrWhiteSpace([string]$record.id) -or $states.ContainsKey($key)) {
            throw "Invalid or duplicate evaluation state key: $key"
        }
        $history = @($record.history)
        if ($history.Count -eq 0) { throw "Evaluation state history is empty: $key" }
        $previousVersion = [version]'0.0.0'
        $previousState = $null
        foreach ($event in $history) {
            $state = [string]$event.state
            if ($state -notin @('core', 'active', 'canary', 'archived', 'retired')) { throw "Unsupported persistent lifecycle state: $key" }
            $eventVersion = $null
            if (-not [version]::TryParse([string]$event.version, [ref]$eventVersion) -or $eventVersion -lt $previousVersion) { throw "Invalid lifecycle version order: $key" }
            if (-not $decisions.ContainsKey([string]$event.decision_id)) { throw "Lifecycle transition has no decision: $key" }
            if ($null -ne $previousState -and $state -eq $previousState) { throw "Lifecycle history contains a duplicate state transition: $key" }
            if ($previousState -eq 'retired') { throw "Retired case cannot be silently reactivated: $key" }
            if ($state -in @('archived', 'retired')) {
                $lastValidVersion = $null
                if (-not [version]::TryParse([string]$event.last_valid_version, [ref]$lastValidVersion) -or $lastValidVersion -gt $eventVersion) { throw "Inactive state requires a last valid version: $key" }
            }
            $previousVersion = $eventVersion
            $previousState = $state
        }
        $states[$key] = [ordered]@{ state = $previousState; history = $history; latest = $history[-1] }
    }
    foreach ($key in @($states.Keys)) {
        foreach ($event in @($states[$key].history | Where-Object { [string]$_.state -eq 'retired' })) {
            $successor = "$([string]$event.successor.suite):$([string]$event.successor.id)"
            if ($successor -eq $key -or -not $states.ContainsKey($successor) -or [string]$states[$successor].state -in @('archived', 'retired')) {
                throw "Retired case requires an active, non-self successor: $key"
            }
        }
    }
    return $states
}
