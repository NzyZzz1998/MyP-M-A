$script:MypmStrictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
$script:MypmUtf8NoBom = [System.Text.UTF8Encoding]::new($false)

function New-MypmValidationResult {
    return [pscustomobject]@{
        Errors = [System.Collections.Generic.List[string]]::new()
        Warnings = [System.Collections.Generic.List[string]]::new()
        Metrics = [ordered]@{}
    }
}

function Add-MypmValidationError {
    param($Result, [string]$Message)
    $Result.Errors.Add($Message)
}

function Add-MypmValidationWarning {
    param($Result, [string]$Message)
    $Result.Warnings.Add($Message)
}

function Read-MypmUtf8Text {
    param(
        [string]$Path,
        $Result,
        [string]$Label
    )

    try {
        return [System.IO.File]::ReadAllText($Path, $script:MypmStrictUtf8)
    } catch {
        Add-MypmValidationError -Result $Result -Message "Non-UTF8 file: $Label"
        return $null
    }
}

function Read-MypmJson {
    param(
        [string]$Path,
        $Result,
        [string]$Label
    )

    $text = Read-MypmUtf8Text -Path $Path -Result $Result -Label $Label
    if ($null -eq $text) { return $null }
    try {
        return ($text | ConvertFrom-Json)
    } catch {
        Add-MypmValidationError -Result $Result -Message "Cannot parse $Label`: $($_.Exception.Message)"
        return $null
    }
}

function Get-MypmTextHash {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($script:MypmUtf8NoBom.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha.Dispose()
    }
}

function Get-MypmRelativePath {
    param([string]$Root, [string]$Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return $pathFull }
    return ($pathFull.Substring($rootFull.Length) -replace '\\', '/')
}

function Resolve-MypmPath {
    param([string]$Root, [string]$RelativePath)
    return [System.IO.Path]::GetFullPath((Join-Path $Root ($RelativePath -replace '/', '\')))
}

function Test-MypmPathInsideRoot {
    param([string]$Root, [string]$Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    return $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-MypmSkillVersion {
    param([string]$SkillText)
    $match = [regex]::Match($SkillText, '(?m)^\s+version:\s+"([^"]+)"\s*$')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}
