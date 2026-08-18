. (Join-Path $PSScriptRoot 'common.ps1')

function Invoke-MypmCoreValidation {
    param([Parameter(Mandatory = $true)][string]$Root)

    $result = New-MypmValidationResult
    $root = [System.IO.Path]::GetFullPath($Root)
    $rules = Read-MypmJson -Path (Join-Path $PSScriptRoot 'rules.json') -Result $result -Label 'scripts/validation/rules.json'
    $skillPath = Join-Path $root 'SKILL.md'
    if ($null -eq $rules -or -not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { Add-MypmValidationError -Result $result -Message 'Missing SKILL.md' }
        return $result
    }
    $skill = Read-MypmUtf8Text -Path $skillPath -Result $result -Label 'SKILL.md'
    if ($null -eq $skill) { return $result }

    if ($skill.Length -gt [int]$rules.skill_char_budget) {
        Add-MypmValidationError -Result $result -Message "SKILL.md context budget exceeded: $($skill.Length) chars > $($rules.skill_char_budget)"
    }
    if (-not $skill.Contains('entry-leading-slash')) { Add-MypmValidationError -Result $result -Message 'SKILL.md must preserve the leading slash in entry commands' }

    $stagePatterns = [ordered]@{
        review = '(?s)### `/review`.*?(?=### `/idea`)'
        idea = '(?s)### `/idea`.*?(?=### `/prd`)'
        prd = '(?s)### `/prd`.*?(?=### `/acceptance`)'
        acceptance = '(?s)### `/acceptance`.*?(?=### `/prompt`)'
        prompt = '(?s)### `/prompt`.*?(?=\r?\n## )'
    }
    foreach ($stage in $stagePatterns.Keys) {
        $match = [regex]::Match($skill, $stagePatterns[$stage])
        if (-not $match.Success) {
            Add-MypmValidationError -Result $result -Message "Cannot locate the core /$stage section in SKILL.md"
        } elseif ($match.Value.Length -gt [int]$rules.stage_core_budget) {
            Add-MypmValidationError -Result $result -Message "SKILL.md /$stage core is too dense ($($match.Value.Length) chars > $($rules.stage_core_budget)); keep details in its reference"
        }
    }

    foreach ($routeProperty in @($rules.required_loading_routes.PSObject.Properties)) {
        foreach ($referencePath in @($routeProperty.Value)) {
            $literal = [string][char]96 + [string]$referencePath + [string][char]96
            if (-not $skill.Contains($literal)) { Add-MypmValidationError -Result $result -Message "SKILL.md /$($routeProperty.Name) route is missing required reference: $referencePath" }
        }
    }

    $frontmatter = [regex]::Match($skill, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|$)')
    if (-not $frontmatter.Success) {
        Add-MypmValidationError -Result $result -Message 'SKILL.md is missing valid YAML frontmatter'
    } else {
        $keys = @([regex]::Matches($frontmatter.Groups['yaml'].Value, '(?m)^(?<key>[A-Za-z0-9_-]+):') | ForEach-Object { $_.Groups['key'].Value })
        foreach ($key in @($keys | Select-Object -Unique)) {
            if ($key -notin @($rules.allowed_frontmatter_keys)) { Add-MypmValidationError -Result $result -Message "Unexpected SKILL.md frontmatter key under official quick validator: $key" }
        }
        foreach ($duplicate in @($keys | Group-Object | Where-Object Count -gt 1)) { Add-MypmValidationError -Result $result -Message "Duplicate SKILL.md frontmatter key: $($duplicate.Name)" }
    }
    $version = Get-MypmSkillVersion -SkillText $skill
    if (-not $version) { Add-MypmValidationError -Result $result -Message 'SKILL.md is missing metadata.version' }
    $description = [regex]::Match($skill, '(?m)^description:\s+"?(.+?)"?\s*$')
    if (-not $description.Success -or -not $description.Groups[1].Value.StartsWith('Use when')) { Add-MypmValidationError -Result $result -Message 'SKILL.md description must start with Use when' }

    $interfacePath = Join-Path $root 'agents\openai.yaml'
    if (-not (Test-Path -LiteralPath $interfacePath -PathType Leaf)) {
        Add-MypmValidationError -Result $result -Message 'agents/openai.yaml is required for the single MyP-M-A UI entry'
    } else {
        $interface = Read-MypmUtf8Text -Path $interfacePath -Result $result -Label 'agents/openai.yaml'
        if ($null -ne $interface) {
            if (-not $interface.Contains('display_name: "MyP-M-A"')) { Add-MypmValidationError -Result $result -Message 'agents/openai.yaml must display MyP-M-A' }
            if (-not $interface.Contains('short_description:')) { Add-MypmValidationError -Result $result -Message 'agents/openai.yaml is missing short_description' }
            if (-not $interface.Contains('$mypm')) { Add-MypmValidationError -Result $result -Message 'agents/openai.yaml default_prompt must reference $mypm' }
        }
    }

    $scanRoot = Split-Path -Parent $root
    $manifests = [System.Collections.Generic.List[string]]::new()
    foreach ($manifest in Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Filter 'SKILL.md') {
        try {
            $text = [System.IO.File]::ReadAllText($manifest.FullName, $script:MypmStrictUtf8)
            if ([regex]::IsMatch($text, '(?m)^name:\s*mypm\s*$')) { $manifests.Add($manifest.FullName) }
        } catch { continue }
    }
    if ($manifests.Count -ne 1 -or $manifests[0] -ne $skillPath) { Add-MypmValidationError -Result $result -Message "Expected exactly one mypm SKILL.md under $scanRoot; found: $($manifests -join ', ')" }

    foreach ($relative in @($rules.required_quality_files)) {
        if (-not (Test-Path -LiteralPath (Resolve-MypmPath -Root $root -RelativePath ([string]$relative)) -PathType Leaf)) { Add-MypmValidationError -Result $result -Message "Missing quality file: $relative" }
    }
    foreach ($relative in @($rules.required_evaluation_scripts)) {
        $path = Resolve-MypmPath -Root $root -RelativePath ([string]$relative)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-MypmValidationError -Result $result -Message "Missing evaluation script: $relative"
            continue
        }
        $scriptText = Read-MypmUtf8Text -Path $path -Result $result -Label ([string]$relative)
        if ($null -eq $scriptText) { continue }
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($scriptText, $path, [ref]$tokens, [ref]$parseErrors)
        foreach ($parseError in @($parseErrors)) { Add-MypmValidationError -Result $result -Message "$relative parse error: $($parseError.Message)" }
    }

    $result.Metrics['version'] = $version
    $result.Metrics['skill_chars'] = $skill.Length
    $result.Metrics['skill_budget'] = [int]$rules.skill_char_budget
    return $result
}
