#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$files = @(
    Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Filter '*.ps1' |
        Sort-Object FullName
)

if ($files.Count -eq 0) {
    throw "No PowerShell scripts were found under: $RepositoryRoot"
}

$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        [void]$utf8.GetString($bytes)
    }
    catch {
        $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $file.FullName)
        $failures.Add("${relativePath}: invalid UTF-8: $($_.Exception.Message)")
        continue
    }

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($null -ne $parseErrors) {
        foreach ($parseError in $parseErrors) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $file.FullName)
            $line = $parseError.Extent.StartLineNumber
            $column = $parseError.Extent.StartColumnNumber
            $failures.Add("${relativePath}:${line}:${column}: $($parseError.Message)")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "PowerShell preflight failed with $($failures.Count) error(s):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "[OK] PowerShell syntax/UTF-8 preflight passed for $($files.Count) script(s)." -ForegroundColor Green
