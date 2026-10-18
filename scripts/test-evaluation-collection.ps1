$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'evals/evaluation-collection.json'
$index = Get-Content -LiteralPath (Join-Path $root 'evals/evaluation-collection-index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($index.config_sha256 -cne (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'Collection config hash is stale' }
if ($index.summary.cases -ne @($index.cases).Count) { throw 'Collection denominator mismatch' }
if (@($index.cases.uid | Sort-Object -Unique).Count -ne @($index.cases).Count) { throw 'Collection UID collision' }
foreach ($source in $index.sources) {
    $path = Join-Path $root $source.path
    if ($source.sha256 -cne (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()) { throw "Collection source is stale: $($source.path)" }
    if (@($index.cases | Where-Object source_path -EQ $source.path).Count -ne $source.count) { throw 'Source count mismatch' }
}
$owned = @($config.sources.path) + @($config.excluded_sources | Where-Object reason | ForEach-Object path)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'evals') -File) {
    if (($file.Name -like '*evals.json' -or $file.Name -like '*cases.json') -and ('evals/' + $file.Name) -notin $owned) { throw "Unregistered evaluation source: $($file.Name)" }
}
foreach ($case in $index.cases) {
    if ($case.kind -notin $config.kinds) { throw 'Unknown case evidence type' }
    if (($case.turn_count -gt 1) -ne ($case.kind -eq 'multi_turn')) { throw 'Multi-turn evidence lost' }
    $definition = $config.sources | Where-Object key -EQ $case.suite
    $data = Get-Content -LiteralPath (Join-Path $root $case.source_path) -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = if ($definition.shape -eq 'array') { @($data) } else { @($data.($definition.shape)) }
    $item = $items[$case.source_index]
    foreach ($asset in $case.files) {
        $inline = if ($item.fixture_files) { $item.fixture_files.PSObject.Properties[$asset.path] } else { $null }
        if ($null -ne $inline) {
            $bytes = [Text.Encoding]::UTF8.GetBytes([string]$inline.Value)
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
        } else { $hash = (Get-FileHash -LiteralPath (Join-Path $root $asset.path) -Algorithm SHA256).Hash.ToLowerInvariant() }
        if ($hash -cne $asset.sha256) { throw "Attachment hash is stale: $($case.uid) $($asset.path)" }
    }
}
Write-Host "Collection static check passed: $($index.summary.cases) source-owned cases; no model execution. Python preparation tests are separate."
