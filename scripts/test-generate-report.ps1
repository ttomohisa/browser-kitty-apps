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

    # Exercise the real status renderer with zero, one, and multiple warning reasons.
    # A pipeline must not unwrap the reason collection under strict mode.
    $generateStatusPath = Join-Path $PSScriptRoot 'generate-status.ps1'
    foreach ($case in @('all-pass', 'one-reason', 'multiple-reasons', 'failure-only')) {
        $fixture = Get-Content -LiteralPath $jsonOutput -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
        $warningCodes = switch ($case) {
            'one-reason' { @('screenshot_en_missing', 'screenshot_en_missing') }
            'multiple-reasons' { @('screenshot_en_missing', 'screenshot_en_missing', 'favicon_missing') }
            default { @() }
        }
        $warningCodes = @($warningCodes)
        for ($i = 0; $i -lt $warningCodes.Count; $i++) {
            $app = $fixture.applications[$i]
            $app.overallStatus = 'WARN'
            $app.checks.quality = 'WARN'
            $app.issueCounts.warn = 1
            $app.issues = @([pscustomobject]@{ severity = 'WARN'; source = 'quality'; code = $warningCodes[$i]; message = 'Fixture warning'; path = $null })
        }
        if ($warningCodes.Count -gt 0) {
            $fixture.overallStatus = 'WARN'
            $fixture.summary.pass -= $warningCodes.Count
            $fixture.summary.warn = $warningCodes.Count
            $fixture.summary.warnings = $warningCodes.Count
        }
        if ($case -eq 'failure-only') {
            $app = $fixture.applications[0]
            $app.overallStatus = 'FAIL'
            $app.checks.pages = 'FAIL'
            $app.issueCounts.fail = 1
            $app.issues = @([pscustomobject]@{ severity = 'FAIL'; source = 'pages'; code = 'pages_unavailable'; message = 'Fixture outage'; path = $null })
            $fixture.overallStatus = 'FAIL'
            $fixture.summary.pass--
            $fixture.summary.fail = 1
            $fixture.summary.failures = 1
        }
        $fixturePath = Join-Path $tempRoot "$case.json"
        $statusPath = Join-Path $tempRoot "$case.md"
        ($fixture | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $fixturePath -Encoding utf8NoBOM
        & $generateStatusPath -RepositoryRoot $RepositoryRoot -HealthReportPath $fixturePath -OutputPath $statusPath
        if (-not $?) { throw "Status renderer failed for $case." }
        $status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8
        if ($warningCodes.Count -eq 0 -and -not $status.Contains('No warnings detected.')) {
            throw "Status renderer omitted the zero-warning message for $case."
        }
        if ($case -eq 'all-pass' -and -not $status.Contains('All registered applications are PASS.')) {
            throw 'Status renderer omitted the all-pass message.'
        }
        if ($warningCodes.Count -gt 0 -and -not $status.Contains('| 2 | English screenshot missing | `screenshot_en_missing` |')) {
            throw "Status renderer failed to aggregate one warning reason for $case."
        }
        if ($case -eq 'multiple-reasons') {
            $first = $status.IndexOf('| 2 | English screenshot missing')
            $second = $status.IndexOf('| 1 | Favicon missing')
            if ($first -lt 0 -or $second -le $first) { throw 'Status renderer warning reasons are missing or incorrectly sorted.' }
        }
        if ($case -eq 'failure-only' -and (-not $status.Contains('Fixture outage') -or $status.Contains('All registered applications are PASS.'))) {
            throw 'Status renderer hid a failure-only report.'
        }
        Write-Host "[OK] Status renderer regression passed: $case."
    }

    Write-Host "[OK] Repository health report smoke test passed for $($apps.Count) app(s)." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
