. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmRuntimeValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $rules = Read-MypmJson -Path (Join-Path $PSScriptRoot 'rules.json') -Result $result -Label 'scripts/validation/rules.json'
    $skillPath = Join-Path $root 'SKILL.md'
    $referenceRoot = Join-Path $root 'references'
    if ($null -eq $rules -or -not (Test-Path -LiteralPath $skillPath -PathType Leaf) -or -not (Test-Path -LiteralPath $referenceRoot -PathType Container)) {
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { Add-MypmValidationError -Result $result -Message 'Missing SKILL.md' }
        if (-not (Test-Path -LiteralPath $referenceRoot -PathType Container)) { Add-MypmValidationError -Result $result -Message 'Missing references directory' }
        return $result
    }

    $runtimeFiles = @(Get-Item -LiteralPath $skillPath) + @(Get-ChildItem -LiteralPath $referenceRoot -File -Filter '*.md')
    $runtimeParts = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $runtimeFiles) {
        $relative = Get-MypmRelativePath -Root $root -Path $file.FullName
        $text = Read-MypmUtf8Text -Path $file.FullName -Result $result -Label $relative
        if ($null -ne $text) { $runtimeParts.Add($text) }
    }
    $runtimeText = $runtimeParts -join "`n"

    foreach ($category in @($rules.runtime_terms.PSObject.Properties)) {
        foreach ($term in @($category.Value)) {
            if (-not $runtimeText.Contains([string]$term)) { Add-MypmValidationError -Result $result -Message "Missing $($category.Name) runtime rule: $term" }
        }
    }

    $requiredLiterals = [ordered]@{
        'SKILL.md' = @('contract:entry-isolation', 'idea-no-fabricated-threshold', 'contract:context-minimal-loading', 'contract:guarded-output-scan', 'contract:work-mode-resolution')
        'evals/README.md' = @('contract:separate-eval-scores', 'contract:eval-execution-isolation', 'contract:eval-release-panel-lifecycle')
        'references/roadmap.md' = @('contract:roadmap-core-output', 'contract:roadmap-stage-explicit')
        'references/idea.md' = @('contract:idea-core-output', 'contract:idea-feedback-role-binding', 'contract:idea-discovery-methods', 'contract:idea-strategy-gtm-evidence')
        'references/review.md' = @(
            'contract:review-core-output', 'contract:review-route-and-visual', 'contract:review-slimming-evidence',
            'contract:review-evidence-handoff', 'contract:review-finding-evidence-source', 'contract:review-default-handoff',
            'contract:review-explicit-idea-candidates', 'contract:review-code-scanner-layer', 'contract:review-strategy-consistency'
        )
        'references/prd.md' = @(
            'contract:prd-known-facts', 'contract:prd-core-output', 'contract:prd-hifi-gate', 'contract:prd-async-idempotency',
            'contract:prd-ui-coupling', 'contract:prd-async-acceptance-matrix', 'contract:prd-prototype-five-part',
            'contract:prd-prototype-gate-table', 'contract:prd-input-blocker-stop', 'contract:prd-ai-agent-four-part',
            'contract:prd-prototype-simulation-browser', 'contract:prd-ai-agent-resilience-governance',
            'contract:prd-ambiguous-ui-questions', 'contract:prd-convergence-preserves-browser-gate',
            'contract:prd-prototype-atomic-output', 'contract:prd-strategy-gtm-boundary'
            'contract:work-mode-pm-ownership'
        )
        'references/prompt.md' = @(
            'contract:prompt-identity', 'contract:recipient-profile', 'contract:single-verification', 'contract:subagent-budget',
            'contract:prompt-preserve-core', 'contract:prompt-only-generation', 'contract:prompt-release-spine',
            'contract:prompt-generation-first-line', 'contract:prompt-render-shell', 'contract:prompt-prerequisite-evidence-stop',
            'contract:prompt-subagent-long-tail', 'contract:prompt-document-only-boundary',
            'contract:prompt-concept-handoff-facts', 'contract:prompt-release-gate-details'
            'contract:work-mode-inheritance'
        )
        'references/data-analysis.md' = @('contract:kpi-data-contract', 'contract:metric-object-snapshot', 'contract:metric-four-counts', 'contract:metric-observed-final-state')
        'references/capability-routing.md' = @(
            'contract:capability-minimal-route', 'contract:capability-evidence-package', 'contract:capability-acceptance-tracks',
            'contract:capability-code-review-scanner', 'contract:capability-discovery-pack', 'contract:capability-strategy-gtm-pack',
            'contract:capability-runtime-probe'
        )
        'references/tooling.md' = @('contract:tooling-code-review-scanner', 'contract:artifact-brand-isolation', 'contract:tooling-capability-state')
        'references/code-review-scanner.md' = @(
            'contract:code-review-scanner-purpose', 'contract:code-review-scanner-privacy',
            'contract:code-review-scanner-delegation', 'contract:code-review-scanner-evidence-closure'
        )
        'references/discovery.md' = @(
            'contract:discovery-method-selection', 'contract:discovery-evidence-traceability',
            'contract:discovery-simulation-boundary', 'contract:discovery-return-to-idea'
        )
        'references/strategy-gtm.md' = @(
            'contract:strategy-gtm-method-selection', 'contract:strategy-gtm-evidence-boundary',
            'contract:strategy-gtm-choice-and-exclusion', 'contract:strategy-gtm-pricing-boundary',
            'contract:strategy-gtm-return-to-stage', 'contract:strategy-gtm-framework-pressure',
            'contract:strategy-gtm-mutually-exclusive-options', 'contract:strategy-gtm-output-density'
        )
        'references/case-library.md' = @('contract:case-library-historical-boundary', 'contract:case-library-no-fact-inheritance')
        'references/memory-integration.md' = @(
            'contract:memory-conflict-inventory', 'contract:memory-auto-restore-attempt',
            'contract:memory-provenance', 'contract:memory-stable-write'
        )
        'references/red-team.md' = @('contract:load-bearing-assumptions')
        'references/intent-implementation-audit.md' = @('contract:intent-implementation-audit', 'contract:conditional-shipping-surfaces')
        'references/acceptance.md' = @(
            'contract:acceptance-evidence-impact', 'contract:acceptance-core-output', 'contract:acceptance-tool-manifest',
            'contract:acceptance-unsigned-installer', 'contract:acceptance-selective-inheritance', 'contract:acceptance-release-gate',
            'contract:acceptance-explicit-inheritance', 'contract:acceptance-release-prerequisites',
            'contract:acceptance-artifact-evidence-freshness', 'contract:acceptance-gap-closure-triples',
            'contract:acceptance-gap-closure-table', 'contract:acceptance-no-evidence-substitution',
            'contract:acceptance-concrete-failure-injection'
            'contract:work-mode-acceptance-boundary'
        )
        'references/work-mode-boundary.md' = @('contract:work-mode-fact-parity')
        'references/development-handoff.md' = @('contract:work-mode-handoff-authorization')
        'templates/prd-template.md' = @('contract:work-mode-vibe-depth')
        'templates/prd-team-template.md' = @('contract:work-mode-team-template')
    }
    $literalCount = 0
    foreach ($entry in $requiredLiterals.GetEnumerator()) {
        $path = Resolve-MypmPath -Root $root -RelativePath $entry.Key
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-MypmValidationError -Result $result -Message "Missing runtime contract file: $($entry.Key)"
            continue
        }
        $text = Read-MypmUtf8Text -Path $path -Result $result -Label $entry.Key
        if ($null -eq $text) { continue }
        foreach ($literal in $entry.Value) {
            $literalCount++
            if (-not $text.Contains([string]$literal)) { Add-MypmValidationError -Result $result -Message "Missing contract anchor in $($entry.Key): $literal" }
        }
    }

    $result.Metrics['runtime_files'] = $runtimeFiles.Count
    $result.Metrics['runtime_chars'] = $runtimeText.Length
    $result.Metrics['required_literals'] = $literalCount
    return $result
}
