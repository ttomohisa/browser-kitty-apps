#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$HealthReportPath = '',
    [string]$OutputJsonPath = '',
    [string]$OutputMarkdownPath = '',
    [switch]$RequireHealthReport
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($HealthReportPath)) {
    $HealthReportPath = Join-Path $RepositoryRoot 'reports/repository-status.json'
}
elseif (-not [System.IO.Path]::IsPathRooted($HealthReportPath)) {
    $HealthReportPath = Join-Path $RepositoryRoot $HealthReportPath
}

if ([string]::IsNullOrWhiteSpace($OutputJsonPath)) {
    $OutputJsonPath = Join-Path $RepositoryRoot 'reports/release-candidate.json'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputJsonPath)) {
    $OutputJsonPath = Join-Path $RepositoryRoot $OutputJsonPath
}

if ([string]::IsNullOrWhiteSpace($OutputMarkdownPath)) {
    $OutputMarkdownPath = Join-Path $RepositoryRoot 'reports/release-candidate.md'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputMarkdownPath)) {
    $OutputMarkdownPath = Join-Path $RepositoryRoot $OutputMarkdownPath
}

$checks = [System.Collections.Generic.List[object]]::new()

function Add-RcCheck {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
        [Parameter(Mandatory)][string]$Message
    )
    $script:checks.Add([ordered]@{
        id = $Id
        status = $Status
        message = $Message
    })
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required JSON file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        $value = $raw | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Invalid JSON: $Path`n$($_.Exception.Message)"
    }
    return @{ Raw = $raw; Value = $value }
}

Write-Host 'Browser Kitty release readiness check'
Write-Host "Repository: $RepositoryRoot"

$versionPath = Join-Path $RepositoryRoot 'VERSION'
$version = ''
$semverPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    Add-RcCheck -Id 'version_file' -Status 'FAIL' -Message 'VERSION is missing.'
}
else {
    $version = (Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8).Trim()
    if ($version -notmatch $semverPattern) {
        Add-RcCheck -Id 'version_file' -Status 'FAIL' -Message "VERSION is not valid Semantic Versioning: $version"
    }
    else {
        Add-RcCheck -Id 'version_file' -Status 'PASS' -Message "VERSION is $version."
    }
}

$requiredFiles = @(
    'README.md',
    'README.ja.md',
    'CATALOG.md',
    'STATUS.md',
    'CHANGELOG.md',
    'LICENSE',
    'REGISTRY_SPEC.md',
    'RELEASE_CHECKLIST.md',
    'OPERATIONS.md',
    'apps.json',
    'categories.json',
    'generated/apps.public.json',
    'generated/README.md',
    'schema/apps.schema.json',
    'schema/public-apps.schema.json',
    'schema/repository-health.schema.json',
    'schema/release-candidate.schema.json',
    'scripts/check-powershell.ps1',
    'scripts/check-registry.ps1',
    'scripts/generate-public-export.ps1',
    'scripts/generate-catalog.ps1',
    'scripts/generate-status.ps1',
    'scripts/generate-report.ps1',
    'scripts/test-generate-report.ps1',
    '.github/workflows/validate-registry.yml',
    '.github/workflows/repository-health.yml',
    'standards/BROWSER_KITTY_GUIDE.md'
)
$missingFiles = @(
    foreach ($relativePath in $requiredFiles) {
        $fullPath = Join-Path $RepositoryRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $relativePath
        }
    }
)
if ($missingFiles.Count -gt 0) {
    Add-RcCheck -Id 'required_files' -Status 'FAIL' -Message ("Required files are missing: " + ($missingFiles -join ', '))
}
else {
    Add-RcCheck -Id 'required_files' -Status 'PASS' -Message "All $($requiredFiles.Count) release-required files are present."
}

$readmePath = Join-Path $RepositoryRoot 'README.md'
$readmeJaPath = Join-Path $RepositoryRoot 'README.ja.md'
$changelogPath = Join-Path $RepositoryRoot 'CHANGELOG.md'
$specPath = Join-Path $RepositoryRoot 'REGISTRY_SPEC.md'
if (-not [string]::IsNullOrWhiteSpace($version)) {
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
        $match = [regex]::Match($readme, '(?m)^## v(?<version>[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\s*$')
        if (-not $match.Success -or $match.Groups['version'].Value -cne $version) {
            $found = if ($match.Success) { $match.Groups['version'].Value } else { '<none>' }
            Add-RcCheck -Id 'readme_version' -Status 'FAIL' -Message "README first version heading is $found; expected $version."
        }
        else {
            Add-RcCheck -Id 'readme_version' -Status 'PASS' -Message "README current version matches $version."
        }
    }

    if (Test-Path -LiteralPath $readmeJaPath -PathType Leaf) {
        $readmeJa = Get-Content -LiteralPath $readmeJaPath -Raw -Encoding UTF8
        $match = [regex]::Match($readmeJa, '(?m)^## v(?<version>[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\s*$')
        if (-not $match.Success -or $match.Groups['version'].Value -cne $version) {
            $found = if ($match.Success) { $match.Groups['version'].Value } else { '<none>' }
            Add-RcCheck -Id 'readme_ja_version' -Status 'FAIL' -Message "README.ja.md first version heading is $found; expected $version."
        }
        else {
            Add-RcCheck -Id 'readme_ja_version' -Status 'PASS' -Message "README.ja.md current version matches $version."
        }
    }

    if (Test-Path -LiteralPath $changelogPath -PathType Leaf) {
        $changelog = Get-Content -LiteralPath $changelogPath -Raw -Encoding UTF8
        $match = [regex]::Match($changelog, '(?m)^##\s+(?:\[)?v?(?<version>[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)(?:\])?(?:\s|$)')
        if (-not $match.Success -or $match.Groups['version'].Value -cne $version) {
            $found = if ($match.Success) { $match.Groups['version'].Value } else { '<none>' }
            Add-RcCheck -Id 'changelog_version' -Status 'FAIL' -Message "CHANGELOG first release entry is $found; expected $version."
        }
        else {
            Add-RcCheck -Id 'changelog_version' -Status 'PASS' -Message "CHANGELOG current release matches $version."
        }
    }

    if (Test-Path -LiteralPath $specPath -PathType Leaf) {
        $spec = Get-Content -LiteralPath $specPath -Raw -Encoding UTF8
        $match = [regex]::Match($spec, '(?m)^Version:\s+(?<version>[0-9]+\.[0-9]+\.[0-9]+)(?:\s+current\s+/\s+1\.0\.0\s+target|\s+production)\s*$')
        if (-not $match.Success -or $match.Groups['version'].Value -cne $version) {
            $found = if ($match.Success) { $match.Groups['version'].Value } else { '<none>' }
            Add-RcCheck -Id 'spec_version' -Status 'FAIL' -Message "REGISTRY_SPEC current version is $found; expected $version."
        }
        else {
            Add-RcCheck -Id 'spec_version' -Status 'PASS' -Message "REGISTRY_SPEC current version matches $version."
        }
    }
}

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$categoriesPath = Join-Path $RepositoryRoot 'categories.json'
$publicExportPath = Join-Path $RepositoryRoot 'generated/apps.public.json'
$appsSchemaPath = Join-Path $RepositoryRoot 'schema/apps.schema.json'
$publicSchemaPath = Join-Path $RepositoryRoot 'schema/public-apps.schema.json'
$healthSchemaPath = Join-Path $RepositoryRoot 'schema/repository-health.schema.json'
$rcSchemaPath = Join-Path $RepositoryRoot 'schema/release-candidate.schema.json'

$appsFile = Read-JsonFile -Path $appsPath
$categoriesFile = Read-JsonFile -Path $categoriesPath
$publicFile = Read-JsonFile -Path $publicExportPath

if (Test-Json -Json $appsFile.Raw -SchemaFile $appsSchemaPath) {
    Add-RcCheck -Id 'registry_schema' -Status 'PASS' -Message 'apps.json matches schema/apps.schema.json.'
}
else {
    Add-RcCheck -Id 'registry_schema' -Status 'FAIL' -Message 'apps.json does not match schema/apps.schema.json.'
}

if (Test-Json -Json $publicFile.Raw -SchemaFile $publicSchemaPath) {
    Add-RcCheck -Id 'public_export_schema' -Status 'PASS' -Message 'generated/apps.public.json matches its schema.'
}
else {
    Add-RcCheck -Id 'public_export_schema' -Status 'FAIL' -Message 'generated/apps.public.json does not match schema/public-apps.schema.json.'
}

$registeredApps = @($appsFile.Value.apps)
$publishedApps = @($registeredApps | Where-Object { [bool]$_.browserKitty.published })
$categories = @($categoriesFile.Value.categories)
$exportedApps = @($publicFile.Value.apps)

if ($publishedApps.Count -ne $exportedApps.Count) {
    Add-RcCheck -Id 'public_export_count' -Status 'FAIL' -Message "Published app count ($($publishedApps.Count)) does not match public export ($($exportedApps.Count))."
}
else {
    Add-RcCheck -Id 'public_export_count' -Status 'PASS' -Message "Public export contains all $($publishedApps.Count) published apps."
}

$publishedIds = @($publishedApps | ForEach-Object { [string]$_.id } | Sort-Object)
$exportedIds = @($exportedApps | ForEach-Object { [string]$_.id } | Sort-Object)
if (($publishedIds -join "`n") -cne ($exportedIds -join "`n")) {
    Add-RcCheck -Id 'public_export_ids' -Status 'FAIL' -Message 'Public export app IDs do not exactly match the published registry set.'
}
else {
    Add-RcCheck -Id 'public_export_ids' -Status 'PASS' -Message 'Public export app IDs match the published registry set.'
}

$nonReleasePublished = @($publishedApps | Where-Object { ([string]$_.status) -notin @('stable', 'maintenance') })
if ($nonReleasePublished.Count -gt 0) {
    Add-RcCheck -Id 'published_lifecycle' -Status 'FAIL' -Message ("Published apps are not release-state stable/maintenance: " + (($nonReleasePublished | ForEach-Object { [string]$_.id }) -join ', '))
}
else {
    Add-RcCheck -Id 'published_lifecycle' -Status 'PASS' -Message 'All published apps are stable or maintenance.'
}

$health = [ordered]@{
    required = [bool]$RequireHealthReport
    available = $false
    overallStatus = $null
    pass = $null
    warn = $null
    fail = $null
    warnings = $null
    failures = $null
}

if (Test-Path -LiteralPath $HealthReportPath -PathType Leaf) {
    $healthFile = Read-JsonFile -Path $HealthReportPath
    if (-not (Test-Json -Json $healthFile.Raw -SchemaFile $healthSchemaPath)) {
        Add-RcCheck -Id 'repository_health' -Status 'FAIL' -Message 'Repository Health report does not match schema/repository-health.schema.json.'
    }
    else {
        $health.available = $true
        $health.overallStatus = [string]$healthFile.Value.overallStatus
        $health.pass = [int]$healthFile.Value.summary.pass
        $health.warn = [int]$healthFile.Value.summary.warn
        $health.fail = [int]$healthFile.Value.summary.fail
        $health.warnings = [int]$healthFile.Value.summary.warnings
        $health.failures = [int]$healthFile.Value.summary.failures

        if ([int]$healthFile.Value.summary.registeredApps -ne $registeredApps.Count -or [int]$healthFile.Value.summary.checkedApps -ne $registeredApps.Count) {
            Add-RcCheck -Id 'repository_health_coverage' -Status 'FAIL' -Message "Repository Health coverage does not match registered app count $($registeredApps.Count)."
        }
        else {
            Add-RcCheck -Id 'repository_health_coverage' -Status 'PASS' -Message "Repository Health covers all $($registeredApps.Count) registered apps."
        }

        if ($health.overallStatus -eq 'FAIL' -or $health.fail -gt 0 -or $health.failures -gt 0) {
            Add-RcCheck -Id 'repository_health' -Status 'FAIL' -Message "Repository Health has blocking failures: apps=$($health.fail), failures=$($health.failures)."
        }
        elseif ($health.overallStatus -eq 'WARN') {
            Add-RcCheck -Id 'repository_health' -Status 'WARN' -Message "Repository Health has no FAILs and retains $($health.warnings) warning(s) across $($health.warn) app(s)."
        }
        else {
            Add-RcCheck -Id 'repository_health' -Status 'PASS' -Message 'Repository Health is PASS with no blocking failures.'
        }
    }
}
elseif ($RequireHealthReport) {
    Add-RcCheck -Id 'repository_health' -Status 'FAIL' -Message "Repository Health report is required but missing: $HealthReportPath"
}
else {
    Add-RcCheck -Id 'repository_health' -Status 'PASS' -Message 'Repository Health is not required for the static RC validation pass.'
}

$passCount = @($checks | Where-Object { $_.status -eq 'PASS' }).Count
$warnCount = @($checks | Where-Object { $_.status -eq 'WARN' }).Count
$failCount = @($checks | Where-Object { $_.status -eq 'FAIL' }).Count
$overallStatus = if ($failCount -gt 0) { 'FAIL' } elseif ($warnCount -gt 0) { 'WARN' } else { 'PASS' }

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    releaseVersion = $version
    overallStatus = $overallStatus
    summary = [ordered]@{
        registeredApps = $registeredApps.Count
        publishedApps = $publishedApps.Count
        categories = $categories.Count
        checks = $checks.Count
        pass = $passCount
        warn = $warnCount
        fail = $failCount
    }
    checks = @($checks)
    health = $health
}

$json = $report | ConvertTo-Json -Depth 20
if (-not (Test-Json -Json $json -SchemaFile $rcSchemaPath)) {
    throw 'Generated release-readiness report does not match schema/release-candidate.schema.json.'
}

$outputDirectory = Split-Path -Parent $OutputJsonPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputJsonPath, (($json -replace "`r`n", "`n").TrimEnd() + "`n"), $utf8NoBom)

$markdown = [System.Collections.Generic.List[string]]::new()
$markdown.Add('# Browser Kitty Apps Release Readiness')
$markdown.Add('')
$markdown.Add("Generated: $($report.generatedAt)")
$markdown.Add('')
$markdown.Add("Version: **$version**")
$markdown.Add('')
$markdown.Add("Overall: **$overallStatus**")
$markdown.Add('')
$markdown.Add('## Summary')
$markdown.Add('')
$markdown.Add('| Item | Value |')
$markdown.Add('|---|---:|')
$markdown.Add("| Registered apps | $($registeredApps.Count) |")
$markdown.Add("| Published apps | $($publishedApps.Count) |")
$markdown.Add("| Categories | $($categories.Count) |")
$markdown.Add("| RC checks | $($checks.Count) |")
$markdown.Add("| PASS | $passCount |")
$markdown.Add("| WARN | $warnCount |")
$markdown.Add("| FAIL | $failCount |")
$markdown.Add('')
$markdown.Add('## Checks')
$markdown.Add('')
$markdown.Add('| Status | Check | Result |')
$markdown.Add('|---|---|---|')
foreach ($check in $checks) {
    $message = ([string]$check.message).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
    $markdown.Add("| $($check.status) | $($check.id) | $message |")
}
$markdown.Add('')
$markdown.Add('## Repository Health')
$markdown.Add('')
if ($health.available) {
    $markdown.Add("Overall: **$($health.overallStatus)**  ")
    $markdown.Add("Apps: PASS $($health.pass) / WARN $($health.warn) / FAIL $($health.fail)  ")
    $markdown.Add("Issues: warnings $($health.warnings) / failures $($health.failures)")
}
else {
    $markdown.Add('Not included in this static RC pass.')
}
$markdownText = (($markdown -join "`n").TrimEnd() + "`n")
[System.IO.File]::WriteAllText($OutputMarkdownPath, $markdownText, $utf8NoBom)

Write-Host "Release readiness JSON written: $OutputJsonPath"
Write-Host "Release readiness Markdown written: $OutputMarkdownPath"
Write-Host "Overall: $overallStatus"
Write-Host "PASS: $passCount"
Write-Host "WARN: $warnCount"
Write-Host "FAIL: $failCount"
if ($health.available) {
    Write-Host "Health: $($health.overallStatus) (PASS $($health.pass) / WARN $($health.warn) / FAIL $($health.fail))"
}

if ($failCount -gt 0) {
    exit 1
}
