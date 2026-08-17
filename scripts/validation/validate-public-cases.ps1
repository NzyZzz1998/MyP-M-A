. (Join-Path $PSScriptRoot 'common.ps1')

function Test-MypmPublicCaseRelativePath {
    param([string]$CaseRoot, [string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
        return $false
    }
    $resolved = Resolve-MypmPath -Root $CaseRoot -RelativePath $RelativePath
    return Test-MypmPathInsideRoot -Root $CaseRoot -Path $resolved
}

function Invoke-MypmPublicCasesValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $examplesRoot = Join-Path $root 'examples'
    $schema = Read-MypmJson -Path (Join-Path $examplesRoot 'case-manifest.schema.json') -Result $result -Label 'examples/case-manifest.schema.json'
    $index = Read-MypmJson -Path (Join-Path $examplesRoot 'index.json') -Result $result -Label 'examples/index.json'
    if ($null -in @($schema, $index)) { return $result }

    if ([int]$index.schema_version -ne 1) {
        Add-MypmValidationError -Result $result -Message "Unsupported public case index schema_version: $($index.schema_version)"
    }
    if ('active_cases' -notin @($index.PSObject.Properties.Name) -or 'withdrawn_case_ids' -notin @($index.PSObject.Properties.Name)) {
        Add-MypmValidationError -Result $result -Message 'Public case index must define active_cases and withdrawn_case_ids'
        return $result
    }

    $activeIds = @($index.active_cases | ForEach-Object { [string]$_ })
    $withdrawnIds = @($index.withdrawn_case_ids | ForEach-Object { [string]$_ })
    foreach ($group in @(@{ Name = 'active'; Values = $activeIds }, @{ Name = 'withdrawn'; Values = $withdrawnIds })) {
        $seen = @{}
        foreach ($id in @($group.Values)) {
            if ($id -notmatch '^[a-z][a-z0-9-]+$') {
                Add-MypmValidationError -Result $result -Message "Invalid $($group.Name) public case id: $id"
            } elseif ($seen.ContainsKey($id)) {
                Add-MypmValidationError -Result $result -Message "Duplicate $($group.Name) public case id: $id"
            } else {
                $seen[$id] = $true
            }
        }
    }
    foreach ($id in $activeIds) {
        if ($id -in $withdrawnIds) {
            Add-MypmValidationError -Result $result -Message "Public case cannot be active and withdrawn: $id"
        }
    }

    $manifestPaths = @(Get-ChildItem -LiteralPath $examplesRoot -Recurse -Filter 'case-manifest.json' -File)
    $manifestIds = @{}
    $allowedStatuses = @('draft', 'review', 'approved', 'published', 'withdrawn')
    $allowedSources = @('synthetic', 'user-owned', 'public-licensed')
    $allowedEvidenceStates = @('confirmed', 'inferred', 'unknown')
    $sensitivePatterns = [ordered]@{
        'Windows user path' = '(?i)\b[A-Z]:\\Users\\[^\\\s]+'
        'POSIX user path' = '(?i)(?:/Users/|/home/)[^/\s]+'
        'email' = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
        'phone' = '(?<!\d)(?:\+?86[- ]?)?1[3-9]\d{9}(?!\d)'
        'private IPv4' = '\b(?:10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.(?:\d{1,3}\.)\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.(?:\d{1,3}\.)\d{1,3})\b'
        'API token' = '(?i)\b(?:sk-|ghp_|github_pat_)[A-Za-z0-9_-]{12,}\b'
        'credential assignment' = '(?i)\b(?:password|passwd|api[_-]?key|access[_-]?token)\s*[:=]\s*[^\s<>]{4,}'
        'private repository URL' = '(?i)https?://(?:www\.)?github\.com/[^/\s]+/[^/\s]+(?:\.git)?(?:\?[^\s]*)?\s+private\b'
    }

    foreach ($manifestPath in $manifestPaths) {
        $caseRoot = Split-Path -Parent $manifestPath.FullName
        $manifestLabel = Get-MypmRelativePath -Root $root -Path $manifestPath.FullName
        $manifest = Read-MypmJson -Path $manifestPath.FullName -Result $result -Label $manifestLabel
        if ($null -eq $manifest) { continue }

        $required = @('schema_version', 'case_id', 'title_zh', 'status', 'source_type', 'authorization', 'privacy', 'versions', 'artifacts', 'evidence', 'third_party_content', 'withdrawal')
        foreach ($property in $required) {
            if ($property -notin @($manifest.PSObject.Properties.Name)) {
                Add-MypmValidationError -Result $result -Message "$manifestLabel is missing $property"
            }
        }

        $id = [string]$manifest.case_id
        if ([int]$manifest.schema_version -ne 1) { Add-MypmValidationError -Result $result -Message "Unsupported public case manifest schema_version: $id" }
        if ($id -notmatch '^[a-z][a-z0-9-]+$') { Add-MypmValidationError -Result $result -Message "Invalid public case id: $id" }
        if ($manifestIds.ContainsKey($id)) {
            Add-MypmValidationError -Result $result -Message "Duplicate public case manifest id: $id"
        } else {
            $manifestIds[$id] = $manifest
        }

        $status = [string]$manifest.status
        if ($status -notin $allowedStatuses) { Add-MypmValidationError -Result $result -Message "Public case $id has unsupported status: $status" }
        if ([string]$manifest.source_type -notin $allowedSources) { Add-MypmValidationError -Result $result -Message "Public case $id has unsupported source_type: $($manifest.source_type)" }
        if (-not [bool]$manifest.authorization.redistribution_allowed) { Add-MypmValidationError -Result $result -Message "Public case authorization does not allow redistribution: $id" }
        if ([int]$manifest.privacy.scan_findings -ne 0) { Add-MypmValidationError -Result $result -Message "Public case privacy scan has findings: $id" }
        if ([string]$manifest.privacy.manual_review_status -ne 'passed') { Add-MypmValidationError -Result $result -Message "Public case manual privacy review did not pass: $id" }

        $artifactPaths = @{}
        foreach ($artifact in @($manifest.artifacts)) {
            $relative = [string]$artifact.path
            if (-not (Test-MypmPublicCaseRelativePath -CaseRoot $caseRoot -RelativePath $relative)) {
                Add-MypmValidationError -Result $result -Message "Public case artifact path is unsafe: $id/$relative"
                continue
            }
            $key = $relative.Replace('\', '/').ToLowerInvariant()
            if ($artifactPaths.ContainsKey($key)) {
                Add-MypmValidationError -Result $result -Message "Duplicate public case artifact path: $id/$relative"
                continue
            }
            $artifactPaths[$key] = $artifact
            $resolved = Resolve-MypmPath -Root $caseRoot -RelativePath $relative
            if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                Add-MypmValidationError -Result $result -Message "Public case artifact not found: $id/$relative"
                continue
            }
            $expectedHash = ([string]$artifact.sha256).ToLowerInvariant()
            $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash.ToLowerInvariant()
            if ($expectedHash -notmatch '^[0-9a-f]{64}$' -or $expectedHash -ne $actualHash) {
                Add-MypmValidationError -Result $result -Message "Public case artifact hash mismatch: $id/$relative"
            }
            $content = Read-MypmUtf8Text -Path $resolved -Result $result -Label (Get-MypmRelativePath -Root $root -Path $resolved)
            if ($null -ne $content) {
                foreach ($patternName in $sensitivePatterns.Keys) {
                    if ($content -match $sensitivePatterns[$patternName]) {
                        Add-MypmValidationError -Result $result -Message "Public case artifact contains $patternName`: $id/$relative"
                    }
                }
            }
        }

        foreach ($controlPath in @(
            [string]$manifest.authorization.evidence_file,
            [string]$manifest.privacy.scan_report,
            [string]$manifest.privacy.manual_review_file
        )) {
            $key = $controlPath.Replace('\', '/').ToLowerInvariant()
            if (-not $artifactPaths.ContainsKey($key)) {
                Add-MypmValidationError -Result $result -Message "Public case control file is not registered as an artifact: $id/$controlPath"
            }
        }

        $claimIds = @{}
        foreach ($claim in @($manifest.evidence)) {
            $claimId = [string]$claim.claim_id
            if ([string]::IsNullOrWhiteSpace($claimId)) {
                Add-MypmValidationError -Result $result -Message "Public case contains an empty claim id: $id"
            } elseif ($claimIds.ContainsKey($claimId)) {
                Add-MypmValidationError -Result $result -Message "Duplicate public case claim id: $id/$claimId"
            } else {
                $claimIds[$claimId] = $true
            }
            $artifactKey = ([string]$claim.artifact).Replace('\', '/').ToLowerInvariant()
            if (-not $artifactPaths.ContainsKey($artifactKey)) { Add-MypmValidationError -Result $result -Message "Public case claim references missing artifact: $id/$claimId" }
            if ([string]::IsNullOrWhiteSpace([string]$claim.locator)) { Add-MypmValidationError -Result $result -Message "Public case claim has an empty locator: $id/$claimId" }
            if ([string]$claim.state -notin $allowedEvidenceStates) { Add-MypmValidationError -Result $result -Message "Public case claim has unsupported state: $id/$claimId" }
        }

        if ($status -in @('approved', 'published') -and $id -notin $activeIds) {
            Add-MypmValidationError -Result $result -Message "Approved or published public case is missing from active index: $id"
        }
        if ($status -eq 'withdrawn') {
            if ($id -in $activeIds) { Add-MypmValidationError -Result $result -Message "Withdrawn public case remains in active index: $id" }
            if ($id -notin $withdrawnIds) { Add-MypmValidationError -Result $result -Message "Withdrawn public case is missing from withdrawn index: $id" }
            if ($null -eq $manifest.withdrawal) {
                Add-MypmValidationError -Result $result -Message "Withdrawn public case is missing withdrawal audit: $id"
            } else {
                foreach ($property in @('reason', 'requested_at', 'removed_from_index_at', 'audit_file')) {
                    if ([string]::IsNullOrWhiteSpace([string]$manifest.withdrawal.$property)) {
                        Add-MypmValidationError -Result $result -Message "Withdrawn public case is missing $property`: $id"
                    }
                }
                $auditKey = ([string]$manifest.withdrawal.audit_file).Replace('\', '/').ToLowerInvariant()
                if (-not $artifactPaths.ContainsKey($auditKey)) { Add-MypmValidationError -Result $result -Message "Withdrawal audit is not registered as an artifact: $id" }
            }
        } elseif ($null -ne $manifest.withdrawal) {
            Add-MypmValidationError -Result $result -Message "Non-withdrawn public case has withdrawal data: $id"
        }
    }

    foreach ($id in $activeIds) {
        if (-not $manifestIds.ContainsKey($id)) { Add-MypmValidationError -Result $result -Message "Active public case manifest not found: $id" }
    }
    foreach ($id in $withdrawnIds) {
        if (-not $manifestIds.ContainsKey($id)) { Add-MypmValidationError -Result $result -Message "Withdrawn public case manifest not found: $id" }
    }

    $result.Metrics['manifests'] = $manifestPaths.Count
    $result.Metrics['active'] = $activeIds.Count
    $result.Metrics['withdrawn'] = $withdrawnIds.Count
    return $result
}
