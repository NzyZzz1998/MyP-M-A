$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert-ProviderRegistry($Data) {
    if ($Data.schema_version -ne 1 -or $Data.default_agent_budget -ne 0) { throw 'Invalid provider defaults' }
    $ids = @($Data.providers.id)
    if ($ids.Count -ne 4 -or @($ids | Sort-Object -Unique).Count -ne 4) { throw 'Provider identity drift' }
    foreach ($p in $Data.providers) {
        if (@($p.effects_default).Count -ne 0) { throw 'Implicit side effect' }
        if ($p.id -like 'matt-*' -and $p.explicit_selection -ne $true) { throw 'Matt selection boundary drift' }
        if ($p.upstream_commit -cnotmatch '^[0-9a-f]{40}$') { throw 'Unpinned provider' }
        if ($p.entry_sha256 -and $p.entry_sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid source hash' }
        if ($p.adapter -notmatch '^references/[a-z-]+\.md$' -or -not (Test-Path -LiteralPath (Join-Path $root $p.adapter))) { throw 'Missing adapter' }
    }
}
$raw = Get-Content -LiteralPath (Join-Path $root 'capabilities/provider-registry.json') -Raw -Encoding UTF8
Assert-ProviderRegistry ($raw | ConvertFrom-Json)
foreach ($mutation in @('budget', 'implicit', 'effects', 'identity')) {
    $changed = $raw | ConvertFrom-Json
    switch ($mutation) {
        'budget' { $changed.default_agent_budget = 2 }
        'implicit' { $changed.providers[0].explicit_selection = $false }
        'effects' { $changed.providers[0].effects_default = @('push') }
        'identity' { $changed.providers[0].upstream_commit = 'latest' }
    }
    $rejected = $false
    try { Assert-ProviderRegistry $changed } catch { $rejected = $true }
    if (-not $rejected) { throw "Missed provider mutation: $mutation" }
}
foreach ($item in @(
    @{ path='references/capability-routing.md'; tokens=@('references/external-provider-routing.md', 'matt-domain-modeling-pilot', 'matt-to-questionnaire-pilot') },
    @{ path='references/external-provider-routing.md'; tokens=@('host_exposed', 'adapter_ready', '嵌套', '预算默认 0', '文件适配') },
    @{ path='references/matt-pilot-adapters.md'; tokens=@('不新建第二份词汇库', '不机械重复', '不调用邮件/消息工具', '显式调用') },
    @{ path='references/matt-code-review-adapter.md'; tokens=@('Standards', 'Spec', 'dual-isolated', '非独立', '不修改原报告') },
    @{ path='references/code-review-scanner.md'; tokens=@('review_snapshot.py', '(path,status,layer)', 'skipped', '不能替换冻结副本') }
)) {
    $text = Get-Content -LiteralPath (Join-Path $root $item.path) -Raw -Encoding UTF8
    foreach ($token in $item.tokens) {
        if (-not $text.Contains($token)) { throw "Missing routing guard: $($item.path): $token" }
    }
}
$panel = Get-Content -LiteralPath (Join-Path $root 'evals/provider-routing-cases.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($panel.cases).Count -ne 14 -or @($panel.cases.id | Sort-Object -Unique).Count -ne 14) { throw 'Routing panel identity drift' }
foreach ($case in $panel.cases) {
    if ([string]::IsNullOrWhiteSpace($case.prompt) -or @($case.expected).Count -ne 3) { throw 'Invalid routing case' }
}
Write-Host 'Provider routing structural guards passed: 4 providers, 4 negative mutations, 14 scenario definitions; no model execution.'
