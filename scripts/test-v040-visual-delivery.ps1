param(
    [string[]]$ManifestPath = @()
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Read-Utf8 {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing v0.40 file: $RelativePath" }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function Assert-True {
    param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Has-Property {
    param([object]$Object, [string]$Name)
    return $null -ne $Object -and $Name -in @($Object.PSObject.Properties.Name)
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Resolve-ManifestFile {
    param([Parameter(Mandatory = $true)][string]$ManifestRoot, [Parameter(Mandatory = $true)][string]$RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath)) { return $null }
    $fullRoot = [System.IO.Path]::GetFullPath($ManifestRoot).TrimEnd([char[]]@('\', '/'))
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $fullRoot $RelativePath))
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
    return $candidate
}

function Get-VisualManifestErrors {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [string]$ManifestRoot = ''
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @('schema_version', 'artifact_id', 'status', 'route', 'visual_type', 'decision_question', 'source', 'tool_probe', 'fact_map', 'files', 'browser_verification', 'accessibility', 'external_resources', 'fallback')) {
        if (-not (Has-Property $Manifest $name)) { $errors.Add("missing:$name") }
    }
    if ($errors.Count -gt 0) { return @($errors) }

    $tool = $Manifest.tool_probe
    foreach ($name in @('name', 'installed', 'callable', 'call_succeeded', 'version', 'commit', 'license', 'probed_at', 'evidence')) {
        if (-not (Has-Property $tool $name)) { $errors.Add("tool-missing:$name") }
    }
    if ((Has-Property $tool 'call_succeeded') -and [bool]$tool.call_succeeded -and (-not [bool]$tool.installed -or -not [bool]$tool.callable)) {
        $errors.Add('tool-success-without-installed-and-callable')
    }
    if ((Has-Property $tool 'call_succeeded') -and [bool]$tool.call_succeeded -and ([string]::IsNullOrWhiteSpace([string]$tool.probed_at) -or [string]::IsNullOrWhiteSpace([string]$tool.evidence))) {
        $errors.Add('tool-success-without-probe-evidence')
    }

    if ([string]$Manifest.status -eq 'formal') {
        foreach ($name in @('installed', 'callable', 'call_succeeded')) {
            if ($null -eq $tool.$name) { $errors.Add("formal-tool-state-unknown:$name") }
        }
        if ([string]::IsNullOrWhiteSpace([string]$Manifest.files.html)) { $errors.Add('formal-missing-html') }
        if ([string]::IsNullOrWhiteSpace([string]$Manifest.files.svg) -and [string]::IsNullOrWhiteSpace([string]$Manifest.files.png)) { $errors.Add('formal-missing-svg-or-png') }
        foreach ($name in @('desktop_screenshot', 'narrow_screenshot')) {
            if ([string]::IsNullOrWhiteSpace([string]$Manifest.files.$name)) { $errors.Add("formal-missing:$name") }
        }
        if (-not (Has-Property $Manifest.files 'sha256')) {
            $errors.Add('formal-missing-file-sha256')
        } else {
            foreach ($name in @('html', 'svg', 'png', 'desktop_screenshot', 'narrow_screenshot', 'fidelity_ledger')) {
                $relativePath = [string]$Manifest.files.$name
                if ([string]::IsNullOrWhiteSpace($relativePath)) { continue }
                $expectedHash = [string]$Manifest.files.sha256.$name
                if ([string]::IsNullOrWhiteSpace($expectedHash)) {
                    $errors.Add("formal-missing-sha256:$name")
                    continue
                }
                if (-not [string]::IsNullOrWhiteSpace($ManifestRoot)) {
                    $resolved = Resolve-ManifestFile -ManifestRoot $ManifestRoot -RelativePath $relativePath
                    if ($null -eq $resolved -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                        $errors.Add("formal-file-missing:$name")
                    } elseif ((Get-Sha256 -Path $resolved) -ne $expectedHash.ToLowerInvariant()) {
                        $errors.Add("formal-sha256-mismatch:$name")
                    }
                }
            }
        }
    }

    $browser = $Manifest.browser_verification
    foreach ($name in @('desktop', 'narrow', 'console_errors', 'page_errors', 'resource_errors', 'offline_core_visible')) {
        if (-not (Has-Property $browser $name)) { $errors.Add("browser-missing:$name") }
    }
    foreach ($name in @('desktop', 'narrow')) {
        if (-not (Has-Property $browser $name)) { continue }
        $viewport = $browser.$name
        foreach ($field in @('viewport', 'overflow', 'overlap', 'text_readable')) {
            if (-not (Has-Property $viewport $field)) { $errors.Add("browser-$name-missing:$field") }
        }
        if ((Has-Property $viewport 'viewport') -and [string]$viewport.viewport -notmatch '^\d+x\d+$') { $errors.Add("browser-$name-invalid-viewport") }
        if ((Has-Property $viewport 'overflow') -and [bool]$viewport.overflow) { $errors.Add("browser-$name-overflow") }
        if ((Has-Property $viewport 'overlap') -and [bool]$viewport.overlap) { $errors.Add("browser-$name-overlap") }
        if ((Has-Property $viewport 'text_readable') -and -not [bool]$viewport.text_readable) { $errors.Add("browser-$name-unreadable") }
    }
    if ((Has-Property $browser 'console_errors') -and [int]$browser.console_errors -ne 0) { $errors.Add('browser-console-errors') }
    if ((Has-Property $browser 'page_errors') -and [int]$browser.page_errors -ne 0) { $errors.Add('browser-page-errors') }
    if ((Has-Property $browser 'resource_errors') -and [int]$browser.resource_errors -ne 0) { $errors.Add('browser-resource-errors') }
    if ((Has-Property $browser 'offline_core_visible') -and -not [bool]$browser.offline_core_visible) { $errors.Add('offline-core-hidden') }

    $accessibility = $Manifest.accessibility
    if ([string]::IsNullOrWhiteSpace([string]$accessibility.alt_text)) { $errors.Add('accessibility-missing-alt') }
    if ([bool]$accessibility.color_is_only_signal) { $errors.Add('accessibility-color-only') }
    if (-not [bool]$accessibility.static_fallback) { $errors.Add('accessibility-missing-static-fallback') }

    foreach ($resource in @($Manifest.external_resources)) {
        foreach ($name in @('url', 'source', 'license', 'offline_behavior')) {
            if (-not (Has-Property $resource $name) -or [string]::IsNullOrWhiteSpace([string]$resource.$name)) { $errors.Add("external-resource-missing:$name") }
        }
    }

    $mode = [string]$Manifest.fact_map.mode
    if ($mode -eq 'numeric') {
        foreach ($fact in @($Manifest.fact_map.facts)) {
            foreach ($name in @('fact_id', 'source_locator', 'visual_element', 'source_value', 'rendered_value', 'unit')) {
                if (-not (Has-Property $fact $name)) { $errors.Add("numeric-fact-missing:$name") }
            }
            if ((Has-Property $fact 'source_value') -and (Has-Property $fact 'rendered_value') -and [string]$fact.source_value -ne [string]$fact.rendered_value) {
                $errors.Add("numeric-value-drift:$($fact.fact_id)")
            }
        }
    } elseif ($mode -eq 'semantic') {
        foreach ($fact in @($Manifest.fact_map.facts)) {
            foreach ($name in @('fact_id', 'source_locator', 'visual_element', 'element_type', 'evidence_state', 'value_or_relation')) {
                if (-not (Has-Property $fact $name) -or [string]::IsNullOrWhiteSpace([string]$fact.$name)) { $errors.Add("semantic-fact-missing:$name") }
            }
            if ((Has-Property $fact 'element_type') -and [string]$fact.element_type -eq 'edge' -and (-not (Has-Property $fact 'direction') -or [string]::IsNullOrWhiteSpace([string]$fact.direction))) {
                $errors.Add("semantic-edge-missing-direction:$($fact.fact_id)")
            }
        }
    } else {
        $errors.Add("unsupported-fact-map-mode:$mode")
    }

    if (-not [string]::IsNullOrWhiteSpace($ManifestRoot)) {
        foreach ($source in @($Manifest.source.objects)) {
            $sourcePath = [string]$source.path_or_id
            $expectedHash = [string]$source.sha256
            if ([string]::IsNullOrWhiteSpace($sourcePath) -or $sourcePath -match '^[a-z]+://' -or $sourcePath -eq '待填写') { continue }
            $resolved = Resolve-ManifestFile -ManifestRoot $ManifestRoot -RelativePath $sourcePath
            if ($null -eq $resolved -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                $errors.Add('source-file-missing')
            } elseif ([string]::IsNullOrWhiteSpace($expectedHash) -or (Get-Sha256 -Path $resolved) -ne $expectedHash.ToLowerInvariant()) {
                $errors.Add('source-sha256-mismatch')
            }
        }
    }
    return @($errors)
}

$skill = Read-Utf8 'SKILL.md'
$visual = Read-Utf8 'references/visual-delivery.md'
$chart = Read-Utf8 'references/chart-delivery.md'
$tooling = Read-Utf8 'references/tooling.md'
$routing = Read-Utf8 'references/capability-routing.md'
$strategy = Read-Utf8 'references/strategy-gtm.md'
$promptReference = Read-Utf8 'references/prompt.md'
$acceptanceReference = Read-Utf8 'references/acceptance.md'
$baseline = Read-Utf8 'notes/v0.40-baseline.json' | ConvertFrom-Json
$rules = Read-Utf8 'scripts/validation/rules.json' | ConvertFrom-Json
$stable = Read-Utf8 'evals/evals.json' | ConvertFrom-Json
$challenge = Read-Utf8 'evals/challenge-evals.json' | ConvertFrom-Json
$contracts = Read-Utf8 'evals/contract-registry.json' | ConvertFrom-Json
$capabilities = Read-Utf8 'capabilities/registry.json' | ConvertFrom-Json
$releasePanel = Read-Utf8 'evals/release-panel.json' | ConvertFrom-Json
$template = Read-Utf8 'templates/visual-manifest-template.json' | ConvertFrom-Json

$currentVersion = [regex]::Match($skill, 'version:\s*"([^"]+)"').Groups[1].Value
Assert-True ($currentVersion -in @('0.40.0', '0.41.0')) 'v0.40 historical self-test supports current versions 0.40.0 and 0.41.0'
foreach ($contract in @('visual-delivery-route', 'visual-fact-map', 'visual-formal-package', 'visual-redraw-fidelity')) {
    Assert-True $visual.Contains("contract:$contract") "Visual reference is missing contract: $contract"
}
Assert-True $chart.Contains('visual-chart-value-fidelity') 'Chart value fidelity contract is missing'
Assert-True ($tooling.Contains('installed / callable / call_succeeded / version / commit / license')) 'Six-field probe contract is missing'
Assert-True ($routing.Contains('references/visual-delivery.md')) 'Visual route is missing'
Assert-True ($visual.Contains('不得折叠成 `A -> C`') -and $visual.Contains('停止输出替代图')) 'Semantic edge and redraw stop contracts are missing'
Assert-True ($strategy.Contains('未分群的总体证据只能支持总体结论')) 'Unsegmented evidence boundary is missing'
Assert-True ($promptReference.Contains('不新增“重读全部证据”门禁') -and $acceptanceReference.Contains('不新增“重读全部证据”门禁')) 'Upstream acceptance inheritance contract is missing'
Assert-True (@(Get-VisualManifestErrors $template).Count -eq 0) 'Visual manifest template must pass draft validation'
Assert-True ($null -eq $template.tool_probe.installed -and $null -eq $template.tool_probe.callable -and $null -eq $template.tool_probe.call_succeeded) 'Visual manifest template must keep tool state unknown'

$requiredLoading = @($rules.required_loading_routes.PSObject.Properties | ForEach-Object { @($_.Value) })
foreach ($path in @('references/visual-delivery.md', 'references/chart-delivery.md', 'capabilities/visualization/decision-chart-adapter.md', 'capabilities/visualization/decision-diagram-adapter.md')) {
    Assert-True ($path -notin $requiredLoading) "Visual pilot must not be default-loaded: $path"
}

$budget = & (Join-Path $root 'scripts/measure-context-budget.ps1') | ConvertFrom-Json
if ($currentVersion -eq '0.40.0') {
    foreach ($route in @($budget.routes)) {
        $frozen = $baseline.context_budget_before_runtime_changes.routes.PSObject.Properties[$route.route].Value
        Assert-True ([int]$route.minimum.normalized_chars -le [int]$frozen.minimum) "Minimum context grew for $($route.route)"
        Assert-True ([int]$route.formal.normalized_chars -le [int]$frozen.formal) "Formal context grew for $($route.route)"
    }
    $normalizedSkill = (Read-Utf8 'SKILL.md') -replace "`r`n?", "`n"
    Assert-True ($normalizedSkill.Length -le [int]$baseline.context_budget_before_runtime_changes.skill_limit) 'SKILL.md exceeds frozen limit'
}

$diagramProbe = $baseline.diagram_design_observation
Assert-True ([bool]$diagramProbe.cache_installed -and -not [bool]$diagramProbe.current_session_skill_exposed -and -not [bool]$diagramProbe.call_succeeded) 'Frozen M0 diagram-design observation changed'
Assert-True ([string]$diagramProbe.package_version -eq '2.5.1' -and [string]$diagramProbe.skill_metadata_version -eq '2.4') 'Frozen M0 diagram-design version changed'
Assert-True ([string]$diagramProbe.commit -eq '9ec2497b85388ae6b31bd09c33ee11a71defcbca' -and [string]$diagramProbe.license -eq 'MIT') 'Frozen M0 diagram-design identity changed'
Assert-True ($tooling.Contains('`2.5.5`') -and $tooling.Contains('29917724f832f0dff2faf4ec583c6c603bed11ba') -and $tooling.Contains('每轮必须重探')) 'Current diagram-design observation contract is missing'
Assert-True ($chart.Contains('PolyForm Noncommercial 1.0.0') -and $chart.Contains('license-boundary:lieflat-noncommercial-only')) 'Lieflat commercial boundary is missing'

foreach ($id in @(103..106)) {
    Assert-True (@($stable.evals | Where-Object { [int]$_.id -eq $id }).Count -eq 1) "Stable v0.40 eval must exist once: $id"
    Assert-True (@($contracts.contracts | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count -eq 1) "Stable v0.40 eval must have one contract: $id"
}
foreach ($id in @('CH-35', 'CH-36', 'CH-37', 'CH-38', 'CH-39')) {
    Assert-True (@($challenge.evals | Where-Object { [string]$_.id -eq $id }).Count -eq 1) "Challenge v0.40 eval must exist once: $id"
    Assert-True (@($contracts.contracts | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains $id }).Count -eq 1) "Challenge v0.40 eval must have one contract: $id"
}

foreach ($item in @($releasePanel.selection_groups.delta)) {
    $eval = @(
        if ([string]$item.suite -eq 'stable') {
            $stable.evals | Where-Object { [string]$_.id -eq [string]$item.id }
        } else {
            $challenge.evals | Where-Object { [string]$_.id -eq [string]$item.id }
        }
    )
    Assert-True ($eval.Count -eq 1) "Release panel eval must exist once: $($item.suite)/$($item.id)"
    $firstLine = ([string]$eval[0].prompt -split "`n")[0]
    Assert-True ($firstLine -match '^/(review|idea|prd|acceptance|prompt)\b') "Release panel prompt has no explicit route: $($item.id)"
    Assert-True ([string]$item.route -eq $matches[0]) "Release panel route drifted for $($item.id): $($item.route) != $($matches[0])"
    $flat = @($releasePanel.selection | Where-Object { [string]$_.suite -eq [string]$item.suite -and [string]$_.id -eq [string]$item.id })
    Assert-True ($flat.Count -eq 1 -and [string]$flat[0].route -eq [string]$item.route) "Release panel flat/group route mismatch: $($item.id)"
}

$diagramCard = @($capabilities.capabilities | Where-Object { [string]$_.id -eq 'visualization.decision-diagram-adapter' })
$chartCard = @($capabilities.capabilities | Where-Object { [string]$_.id -eq 'visualization.decision-chart-adapter' })
Assert-True ($diagramCard.Count -eq 1 -and [string]$diagramCard[0].status -eq 'pilot') 'Diagram card must be a single pilot'
Assert-True ($chartCard.Count -eq 1 -and [string]$chartCard[0].status -eq 'pilot') 'Chart card must remain a single pilot'

$goodNumeric = $template | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$goodNumeric.status = 'formal'
$goodNumeric.tool_probe = [pscustomobject]@{name='none'; installed=$false; callable=$false; call_succeeded=$false; version=$null; commit=$null; license=$null; probed_at='2026-08-19T00:00:00Z'; evidence='No external tool used; local fixture only.'}
$goodNumeric.fact_map.mode = 'numeric'
$goodNumeric.fact_map.facts = @([pscustomobject]@{fact_id='N-1'; source_locator='data.csv:2'; visual_element='bar-review'; source_value='8999'; rendered_value='8999'; unit='chars'})
Assert-True (@(Get-VisualManifestErrors $goodNumeric).Count -eq 0) 'Positive numeric fixture should pass'

$goodSemantic = $template | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$goodSemantic.status = 'formal'
$goodSemantic.tool_probe = $goodNumeric.tool_probe
$goodSemantic.fact_map.facts = @(
    [pscustomobject]@{fact_id='S-1'; source_locator='a.md:1'; visual_element='node-a'; element_type='node'; evidence_state='confirmed'; value_or_relation='A'},
    [pscustomobject]@{fact_id='S-2'; source_locator='a.md:2'; visual_element='edge-a-b'; element_type='edge'; evidence_state='confirmed'; value_or_relation='A calls B'; direction='A->B'}
)
Assert-True (@(Get-VisualManifestErrors $goodSemantic).Count -eq 0) 'Positive semantic fixture should pass'

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mypm-v040-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
try {
    $fixtureFiles = [ordered]@{
        source = 'source.md'
        html = 'artifact.html'
        svg = 'artifact.svg'
        desktop_screenshot = 'desktop.png'
        narrow_screenshot = 'narrow.png'
    }
    foreach ($entry in $fixtureFiles.GetEnumerator()) {
        [System.IO.File]::WriteAllText((Join-Path $fixtureRoot $entry.Value), "fixture:$($entry.Key)", [System.Text.UTF8Encoding]::new($false))
    }

    $mechanical = $goodSemantic | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $mechanical.source.objects[0].path_or_id = $fixtureFiles.source
    $mechanical.source.objects[0].sha256 = Get-Sha256 -Path (Join-Path $fixtureRoot $fixtureFiles.source)
    $mechanical.files.html = $fixtureFiles.html
    $mechanical.files.svg = $fixtureFiles.svg
    $mechanical.files.png = $null
    $mechanical.files.desktop_screenshot = $fixtureFiles.desktop_screenshot
    $mechanical.files.narrow_screenshot = $fixtureFiles.narrow_screenshot
    $mechanical.files.sha256.html = Get-Sha256 -Path (Join-Path $fixtureRoot $fixtureFiles.html)
    $mechanical.files.sha256.svg = Get-Sha256 -Path (Join-Path $fixtureRoot $fixtureFiles.svg)
    $mechanical.files.sha256.png = $null
    $mechanical.files.sha256.desktop_screenshot = Get-Sha256 -Path (Join-Path $fixtureRoot $fixtureFiles.desktop_screenshot)
    $mechanical.files.sha256.narrow_screenshot = Get-Sha256 -Path (Join-Path $fixtureRoot $fixtureFiles.narrow_screenshot)
    Assert-True (@(Get-VisualManifestErrors -Manifest $mechanical -ManifestRoot $fixtureRoot).Count -eq 0) 'Mechanical manifest fixture should pass'

    $badHash = $mechanical | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $badHash.files.sha256.html = ('0' * 64)
    Assert-True ('formal-sha256-mismatch:html' -in @(Get-VisualManifestErrors -Manifest $badHash -ManifestRoot $fixtureRoot)) 'Artifact hash drift should fail'

    $badMissing = $mechanical | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $badMissing.files.html = 'missing.html'
    Assert-True ('formal-file-missing:html' -in @(Get-VisualManifestErrors -Manifest $badMissing -ManifestRoot $fixtureRoot)) 'Missing artifact should fail'

    $badViewport = $mechanical | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $badViewport.browser_verification.narrow.viewport = 'mobile'
    Assert-True ('browser-narrow-invalid-viewport' -in @(Get-VisualManifestErrors -Manifest $badViewport -ManifestRoot $fixtureRoot)) 'Invalid viewport detail should fail'

    $badSource = $mechanical | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $badSource.source.objects[0].sha256 = ('f' * 64)
    Assert-True ('source-sha256-mismatch' -in @(Get-VisualManifestErrors -Manifest $badSource -ManifestRoot $fixtureRoot)) 'Source hash drift should fail'
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

$badNumeric = $goodNumeric | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$badNumeric.fact_map.facts[0].rendered_value = '9000'
Assert-True ('numeric-value-drift:N-1' -in @(Get-VisualManifestErrors $badNumeric)) 'Numeric drift fixture should fail'

$badEdge = $goodSemantic | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$badEdge.fact_map.facts[1].direction = ''
Assert-True ('semantic-edge-missing-direction:S-2' -in @(Get-VisualManifestErrors $badEdge)) 'Missing edge direction should fail'

$badTool = $goodSemantic | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$badTool.tool_probe.callable = $false
$badTool.tool_probe.call_succeeded = $true
Assert-True ('tool-success-without-installed-and-callable' -in @(Get-VisualManifestErrors $badTool)) 'False tool success should fail'

$badExternal = $goodSemantic | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$badExternal.external_resources = @([pscustomobject]@{url='https://cdn.example/x.js'; source='example'})
Assert-True (@(Get-VisualManifestErrors $badExternal | Where-Object { $_ -like 'external-resource-missing:*' }).Count -gt 0) 'Unlicensed external resource should fail'

foreach ($path in @($ManifestPath)) {
    $resolvedManifest = [System.IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) { throw "Visual manifest not found: $resolvedManifest" }
    $manifest = [System.IO.File]::ReadAllText($resolvedManifest, $utf8) | ConvertFrom-Json
    $manifestErrors = @(Get-VisualManifestErrors -Manifest $manifest -ManifestRoot (Split-Path -Parent $resolvedManifest))
    if ($manifestErrors.Count -gt 0) { throw "Visual manifest failed: $resolvedManifest`n$($manifestErrors -join "`n")" }
}

Write-Host "v0.40 visual-delivery self-test passed: current=$currentVersion routes=2 stable=4 challenge=5 capabilities=2 default-load=0 mechanical=1 negative=8"
