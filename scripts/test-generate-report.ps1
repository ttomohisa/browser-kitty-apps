#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$generateReportPath = Join-Path $PSScriptRoot 'generate-report.ps1'
if (-not (Test-Path -LiteralPath $appsPath -PathType Leaf)) {
    throw "apps.json not found: $appsPath"
}
if (-not (Test-Path -LiteralPath $generateReportPath -PathType Leaf)) {
    throw "generate-report.ps1 not found: $generateReportPath"
}

$apps = @((Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100).apps)
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("browser-kitty-health-smoke-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $generatedAt = [DateTimeOffset]::UtcNow.ToString('o')

    $inventory = [ordered]@{
        schemaVersion = 1
        generatedAt = $generatedAt
        repositories = @($apps | ForEach-Object {
            [ordered]@{
                appId = [string]$_.id
                exists = $true
                lookupStatus = 'ok'
                warnings = @()
            }
        })
    }

    $quality = [ordered]@{
        schemaVersion = 1
        generatedAt = $generatedAt
        repositories = @($apps | ForEach-Object {
            [ordered]@{
                appId = [string]$_.id
                qualityStatus = 'PASS'
                issues = @()
            }
        })
    }

    $pages = [ordered]@{
        schemaVersion = 1
        generatedAt = $generatedAt
        applications = @($apps | ForEach-Object {
            [ordered]@{
                appId = [string]$_.id
                pagesStatus = 'PASS'
                issues = @()
            }
        })
    }

    $releases = [ordered]@{
        schemaVersion = 1
        generatedAt = $generatedAt
        applications = @($apps | ForEach-Object {
            [ordered]@{
                appId = [string]$_.id
                releaseStatus = 'PASS'
                issues = @()
            }
        })
    }

    $runtime = [ordered]@{
        schemaVersion = 1
        generatedAt = $generatedAt
        repositories = @($apps | ForEach-Object {
            [ordered]@{
                appId = [string]$_.id
                runtimeStatus = 'PASS'
                issues = @()
            }
        })
    }

    $paths = @{}
    foreach ($item in @(
        @{ Name = 'inventory'; Value = $inventory },
        @{ Name = 'quality'; Value = $quality },
        @{ Name = 'pages'; Value = $pages },
        @{ Name = 'releases'; Value = $releases },
        @{ Name = 'runtime'; Value = $runtime }
    )) {
        $path = Join-Path $tempRoot ("$($item.Name).json")
        ($item.Value | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $path -Encoding utf8NoBOM
        $paths[$item.Name] = $path
    }

    $jsonOutput = Join-Path $tempRoot 'repository-status.json'
    $markdownOutput = Join-Path $tempRoot 'repository-status.md'

    & $generateReportPath `
        -RepositoryRoot $RepositoryRoot `
        -InventoryPath $paths.inventory `
        -QualityPath $paths.quality `
        -PagesPath $paths.pages `
        -ReleasesPath $paths.releases `
        -RuntimePath $paths.runtime `
        -JsonOutputPath $jsonOutput `
        -MarkdownOutputPath $markdownOutput

    $reportCommandSucceeded = $?
    if (-not $reportCommandSucceeded) {
        throw 'generate-report.ps1 smoke test returned an unsuccessful command status.'
    }
    if (-not (Test-Path -LiteralPath $jsonOutput -PathType Leaf)) {
        throw 'Smoke test did not generate repository-status.json.'
    }
    if (-not (Test-Path -LiteralPath $markdownOutput -PathType Leaf)) {
        throw 'Smoke test did not generate repository-status.md.'
    }

    $report = Get-Content -LiteralPath $jsonOutput -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
    if ([string]$report.overallStatus -ne 'PASS') {
        throw "Smoke test expected PASS but got '$($report.overallStatus)'."
    }
    if ([int]$report.summary.checkedApps -ne $apps.Count) {
        throw "Smoke test checkedApps mismatch: expected $($apps.Count), got $($report.summary.checkedApps)."
    }
    if ([int]$report.summary.globalIssues -ne 0) {
        throw "Smoke test expected an empty global issue collection."
    }

    Write-Host "[OK] Repository health report smoke test passed for $($apps.Count) app(s)." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
