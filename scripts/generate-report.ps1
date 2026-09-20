#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InventoryPath = 'reports/repository-inventory.json',
    [string]$QualityPath = 'reports/repository-quality.json',
    [string]$PagesPath = 'reports/repository-pages.json',
    [string]$ReleasesPath = 'reports/repository-releases.json',
    [string]$RuntimePath = 'reports/repository-runtime.json',
    [string]$JsonOutputPath = 'reports/repository-status.json',
    [string]$MarkdownOutputPath = 'reports/repository-status.md',
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-AbsolutePath {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $RepositoryRoot $Path
}

function New-HealthIssue {
    param(
        [Parameter(Mandatory)][ValidateSet('WARN', 'FAIL')][string]$Severity,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message,
        [AllowNull()][string]$Path = $null
    )

    return [pscustomobject][ordered]@{
        severity = $Severity
        source   = $Source
        code     = $Code
        message  = $Message
        path     = $Path
    }
}

function Read-SourceReport {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.Generic.List[object]]$GlobalIssues
    )

    $absolutePath = Get-AbsolutePath -Path $Path
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        $message = "Source report is missing: $Path"
        $GlobalIssues.Add((New-HealthIssue -Severity FAIL -Source $Name -Code 'source_report_missing' -Message $message -Path $Path))
        return [pscustomobject]@{
            Name       = $Name
            Path       = ($Path -replace '\\', '/')
            Available  = $false
            GeneratedAt = $null
            Report     = $null
            Error      = $message
        }
    }

    try {
        $report = Get-Content -LiteralPath $absolutePath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
        $generatedAt = if ($null -ne $report.PSObject.Properties['generatedAt']) { [string]$report.generatedAt } else { $null }
        return [pscustomobject]@{
            Name       = $Name
            Path       = ($Path -replace '\\', '/')
            Available  = $true
            GeneratedAt = $generatedAt
            Report     = $report
            Error      = $null
        }
    }
    catch {
        $message = "Source report could not be parsed: $($_.Exception.Message)"
        $GlobalIssues.Add((New-HealthIssue -Severity FAIL -Source $Name -Code 'source_report_invalid' -Message $message -Path $Path))
        return [pscustomobject]@{
            Name       = $Name
            Path       = ($Path -replace '\\', '/')
            Available  = $false
            GeneratedAt = $null
            Report     = $null
            Error      = $message
        }
    }
}

function New-EntryMap {
    param(
        [AllowNull()]$Report,
        [Parameter(Mandatory)][string]$CollectionProperty
    )

    $map = @{}
    if ($null -eq $Report -or $null -eq $Report.PSObject.Properties[$CollectionProperty]) {
        return $map
    }

    foreach ($entry in @($Report.$CollectionProperty)) {
        if ($null -ne $entry.PSObject.Properties['appId']) {
            $appId = [string]$entry.appId
            if (-not [string]::IsNullOrWhiteSpace($appId)) {
                $map[$appId] = $entry
            }
        }
    }
    return $map
}

function Add-IssueObjects {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.List[object]]$Target,
        [Parameter(Mandatory)][string]$Source,
        [AllowNull()]$SourceIssues
    )

    foreach ($issue in @($SourceIssues)) {
        if ($null -eq $issue) { continue }
        $severity = if ($null -ne $issue.PSObject.Properties['severity'] -and [string]$issue.severity -eq 'FAIL') { 'FAIL' } else { 'WARN' }
        $code = if ($null -ne $issue.PSObject.Properties['code'] -and -not [string]::IsNullOrWhiteSpace([string]$issue.code)) { [string]$issue.code } else { 'unspecified' }
        $message = if ($null -ne $issue.PSObject.Properties['message'] -and -not [string]::IsNullOrWhiteSpace([string]$issue.message)) { [string]$issue.message } else { 'Issue reported without a message.' }
        $path = if ($null -ne $issue.PSObject.Properties['path']) { [string]$issue.path } else { $null }
        $Target.Add((New-HealthIssue -Severity $severity -Source $Source -Code $code -Message $message -Path $path))
    }
}

function Get-InventoryStatus {
    param([AllowNull()]$Entry)

    if ($null -eq $Entry) { return 'UNKNOWN' }
    if ([string]$Entry.lookupStatus -ne 'ok' -or -not [bool]$Entry.exists) { return 'FAIL' }
    if (@($Entry.warnings).Count -gt 0) { return 'WARN' }
    return 'PASS'
}

function Get-NamedStatus {
    param(
        [AllowNull()]$Entry,
        [Parameter(Mandatory)][string]$Property
    )

    if ($null -eq $Entry) { return 'UNKNOWN' }
    if ($null -eq $Entry.PSObject.Properties[$Property]) { return 'UNKNOWN' }
    $value = [string]$Entry.$Property
    if ($value -in @('PASS', 'WARN', 'FAIL')) { return $value }
    return 'UNKNOWN'
}

function Get-OverallStatus {
    param([Parameter(Mandatory)]$Checks)

    $values = @($Checks.inventory, $Checks.quality, $Checks.pages, $Checks.releases, $Checks.runtime)
    if ($values -contains 'FAIL' -or $values -contains 'UNKNOWN') { return 'FAIL' }
    if ($values -contains 'WARN') { return 'WARN' }
    return 'PASS'
}

function Escape-MarkdownTableValue {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return '' }
    return (($Value -replace '\r?\n', ' ') -replace '\|', '\|')
}

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$schemaPath = Join-Path $RepositoryRoot 'schema/repository-health.schema.json'
foreach ($requiredPath in @($appsPath, $schemaPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)
$globalIssues = [System.Collections.Generic.List[object]]::new()

$sourceDefinitions = [ordered]@{
    inventory = $InventoryPath
    quality   = $QualityPath
    pages     = $PagesPath
    releases  = $ReleasesPath
    runtime   = $RuntimePath
}
$sourceReports = @{}
$sourceMetadata = [ordered]@{}

foreach ($sourceName in $sourceDefinitions.Keys) {
    $source = Read-SourceReport -Name $sourceName -Path $sourceDefinitions[$sourceName] -GlobalIssues $globalIssues
    $sourceReports[$sourceName] = $source.Report
    $sourceMetadata[$sourceName] = [ordered]@{
        path        = $source.Path
        available   = [bool]$source.Available
        generatedAt = $source.GeneratedAt
        error       = $source.Error
    }
}

$inventoryMap = New-EntryMap -Report $sourceReports.inventory -CollectionProperty 'repositories'
$qualityMap = New-EntryMap -Report $sourceReports.quality -CollectionProperty 'repositories'
$pagesMap = New-EntryMap -Report $sourceReports.pages -CollectionProperty 'applications'
$releasesMap = New-EntryMap -Report $sourceReports.releases -CollectionProperty 'applications'
$runtimeMap = New-EntryMap -Report $sourceReports.runtime -CollectionProperty 'repositories'

Write-Host 'Browser Kitty repository health report'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host ''

$appResults = [System.Collections.Generic.List[object]]::new()
$passCount = 0
$warnCount = 0
$failCount = 0
$totalWarnings = 0
$totalFailures = 0

foreach ($app in $apps) {
    $appId = [string]$app.id
    $issues = [System.Collections.Generic.List[object]]::new()

    $inventoryEntry = if ($inventoryMap.ContainsKey($appId)) { $inventoryMap[$appId] } else { $null }
    $qualityEntry = if ($qualityMap.ContainsKey($appId)) { $qualityMap[$appId] } else { $null }
    $pagesEntry = if ($pagesMap.ContainsKey($appId)) { $pagesMap[$appId] } else { $null }
    $releasesEntry = if ($releasesMap.ContainsKey($appId)) { $releasesMap[$appId] } else { $null }
    $runtimeEntry = if ($runtimeMap.ContainsKey($appId)) { $runtimeMap[$appId] } else { $null }

    $checks = [ordered]@{
        inventory = if ($sourceMetadata['inventory'].available) { Get-InventoryStatus -Entry $inventoryEntry } else { 'UNKNOWN' }
        quality   = if ($sourceMetadata['quality'].available) { Get-NamedStatus -Entry $qualityEntry -Property 'qualityStatus' } else { 'UNKNOWN' }
        pages     = if ($sourceMetadata['pages'].available) { Get-NamedStatus -Entry $pagesEntry -Property 'pagesStatus' } else { 'UNKNOWN' }
        releases  = if ($sourceMetadata['releases'].available) { Get-NamedStatus -Entry $releasesEntry -Property 'releaseStatus' } else { 'UNKNOWN' }
        runtime   = if ($sourceMetadata['runtime'].available) { Get-NamedStatus -Entry $runtimeEntry -Property 'runtimeStatus' } else { 'UNKNOWN' }
    }

    foreach ($sourceName in $checks.Keys) {
        if ([string]$checks[$sourceName] -eq 'UNKNOWN' -and [bool]$sourceMetadata[$sourceName].available) {
            $issues.Add((New-HealthIssue -Severity FAIL -Source $sourceName -Code 'source_entry_missing' -Message "No $sourceName report entry exists for '$appId'." -Path $sourceMetadata[$sourceName].path))
        }
        elseif ([string]$checks[$sourceName] -eq 'UNKNOWN') {
            $issues.Add((New-HealthIssue -Severity FAIL -Source $sourceName -Code 'source_report_unavailable' -Message "The $sourceName source report is unavailable." -Path $sourceMetadata[$sourceName].path))
        }
    }

    if ($null -ne $inventoryEntry) {
        foreach ($warning in @($inventoryEntry.warnings)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
                $issues.Add((New-HealthIssue -Severity WARN -Source 'inventory' -Code 'inventory_warning' -Message ([string]$warning)))
            }
        }
        if ([string]$inventoryEntry.lookupStatus -ne 'ok') {
            $message = if ($null -ne $inventoryEntry.PSObject.Properties['error'] -and -not [string]::IsNullOrWhiteSpace([string]$inventoryEntry.error)) { [string]$inventoryEntry.error } else { 'Repository inventory lookup failed.' }
            $issues.Add((New-HealthIssue -Severity FAIL -Source 'inventory' -Code 'repository_lookup_failed' -Message $message))
        }
    }

    if ($null -ne $qualityEntry) { Add-IssueObjects -Target $issues -Source 'quality' -SourceIssues $qualityEntry.issues }
    if ($null -ne $pagesEntry) { Add-IssueObjects -Target $issues -Source 'pages' -SourceIssues $pagesEntry.issues }
    if ($null -ne $releasesEntry) { Add-IssueObjects -Target $issues -Source 'releases' -SourceIssues $releasesEntry.issues }
    if ($null -ne $runtimeEntry) { Add-IssueObjects -Target $issues -Source 'runtime' -SourceIssues $runtimeEntry.issues }

    $overallStatus = Get-OverallStatus -Checks ([pscustomobject]$checks)
    $warnIssues = @($issues | Where-Object { $_.severity -eq 'WARN' }).Count
    $failIssues = @($issues | Where-Object { $_.severity -eq 'FAIL' }).Count
    $totalWarnings += $warnIssues
    $totalFailures += $failIssues

    switch ($overallStatus) {
        'PASS' { $passCount++; Write-Host "$appId PASS" -ForegroundColor Green }
        'WARN' { $warnCount++; Write-Host "$appId WARN" -ForegroundColor Yellow }
        'FAIL' { $failCount++; Write-Host "$appId FAIL" -ForegroundColor Red }
    }

    $appResults.Add([pscustomobject][ordered]@{
        appId          = $appId
        name           = [string]$app.name
        nameJa         = [string]$app.nameJa
        repository     = [string]$app.repository
        registryStatus = [string]$app.status
        published      = [bool]$app.browserKitty.published
        version        = [string]$app.release.version
        overallStatus  = $overallStatus
        checks         = [pscustomobject]$checks
        issueCounts    = [pscustomobject][ordered]@{
            warn = $warnIssues
            fail = $failIssues
        }
        issues         = @($issues)
    })
}

$hasGlobalFail = @($globalIssues | Where-Object { $_.severity -eq 'FAIL' }).Count -gt 0
$overallStatus = if ($failCount -gt 0 -or $hasGlobalFail) { 'FAIL' } elseif ($warnCount -gt 0 -or $globalIssues.Count -gt 0) { 'WARN' } else { 'PASS' }

$report = [ordered]@{
    schemaVersion  = 1
    generatedAt    = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRegistry = 'apps.json'
    overallStatus  = $overallStatus
    sources        = [pscustomobject]$sourceMetadata
    summary        = [ordered]@{
        registeredApps = $apps.Count
        checkedApps    = $appResults.Count
        pass           = $passCount
        warn           = $warnCount
        fail           = $failCount
        warnings       = $totalWarnings
        failures       = $totalFailures
        globalIssues   = $globalIssues.Count
    }
    globalIssues   = @($globalIssues)
    applications   = @($appResults)
}

$reportJson = $report | ConvertTo-Json -Depth 40
if (-not (Test-Json -Json $reportJson -SchemaFile $schemaPath)) {
    throw 'Generated health report does not match schema/repository-health.schema.json.'
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Browser Kitty Repository Health')
$lines.Add('')
$lines.Add("Generated: $($report.generatedAt)")
$lines.Add('')
$lines.Add("Overall: **$overallStatus**")
$lines.Add('')
$lines.Add('## Summary')
$lines.Add('')
$lines.Add('| Status | Apps |')
$lines.Add('|---|---:|')
$lines.Add("| PASS | $passCount |")
$lines.Add("| WARN | $warnCount |")
$lines.Add("| FAIL | $failCount |")
$lines.Add('')
$lines.Add("Registered apps: **$($apps.Count)**  ")
$lines.Add("Warnings: **$totalWarnings**  ")
$lines.Add("Failures: **$totalFailures**  ")
$lines.Add("Global issues: **$($globalIssues.Count)**")
$lines.Add('')
$lines.Add('## Source reports')
$lines.Add('')
$lines.Add('| Source | Available | Generated |')
$lines.Add('|---|---|---|')
foreach ($sourceName in $sourceDefinitions.Keys) {
    $metadata = $sourceMetadata[$sourceName]
    $availableText = if ($metadata.available) { 'yes' } else { 'no' }
    $generatedText = if ([string]::IsNullOrWhiteSpace([string]$metadata.generatedAt)) { '-' } else { [string]$metadata.generatedAt }
    $lines.Add("| $sourceName | $availableText | $(Escape-MarkdownTableValue -Value $generatedText) |")
}
$lines.Add('')
$lines.Add('## Applications')
$lines.Add('')
$lines.Add('| Status | App | Version | Inventory | Quality | Pages | Release | Runtime | Issues |')
$lines.Add('|---|---|---:|---|---|---|---|---|---:|')
foreach ($entry in $appResults) {
    $issueTotal = [int]$entry.issueCounts.warn + [int]$entry.issueCounts.fail
    $lines.Add("| $($entry.overallStatus) | $(Escape-MarkdownTableValue -Value $entry.name) | $($entry.version) | $($entry.checks.inventory) | $($entry.checks.quality) | $($entry.checks.pages) | $($entry.checks.releases) | $($entry.checks.runtime) | $issueTotal |")
}
$lines.Add('')

if ($globalIssues.Count -gt 0) {
    $lines.Add('## Global issues')
    $lines.Add('')
    foreach ($issue in $globalIssues) {
        $lines.Add("- **$($issue.severity)** [$($issue.source)/$($issue.code)] $($issue.message)")
    }
    $lines.Add('')
}

$appsWithIssues = @($appResults | Where-Object { $_.issues.Count -gt 0 })
$lines.Add('## Issues')
$lines.Add('')
if ($appsWithIssues.Count -eq 0) {
    $lines.Add('No application issues detected.')
    $lines.Add('')
}
else {
    foreach ($entry in $appsWithIssues) {
        $lines.Add("### $($entry.name) — $($entry.overallStatus)")
        $lines.Add('')
        foreach ($issue in @($entry.issues | Sort-Object @{ Expression = { if ($_.severity -eq 'FAIL') { 0 } else { 1 } } }, source, code)) {
            $pathSuffix = if ([string]::IsNullOrWhiteSpace([string]$issue.path)) { '' } else { " (``$($issue.path)``)" }
            $lines.Add("- **$($issue.severity)** [$($issue.source)/$($issue.code)] $($issue.message)$pathSuffix")
        }
        $lines.Add('')
    }
}

$markdown = ($lines -join "`n") + "`n"

if (-not $NoWrite) {
    $absoluteJsonOutputPath = Get-AbsolutePath -Path $JsonOutputPath
    $absoluteMarkdownOutputPath = Get-AbsolutePath -Path $MarkdownOutputPath
    foreach ($outputPath in @($absoluteJsonOutputPath, $absoluteMarkdownOutputPath)) {
        $outputDirectory = Split-Path -Parent $outputPath
        if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
    }
    $reportJson | Set-Content -LiteralPath $absoluteJsonOutputPath -Encoding utf8NoBOM
    $markdown | Set-Content -LiteralPath $absoluteMarkdownOutputPath -Encoding utf8NoBOM
    Write-Host ''
    Write-Host "Health JSON written: $absoluteJsonOutputPath"
    Write-Host "Health Markdown written: $absoluteMarkdownOutputPath"
}

Write-Host ''
Write-Host "Overall: $overallStatus"
Write-Host "PASS: $passCount"
Write-Host "WARN: $warnCount"
Write-Host "FAIL: $failCount"
Write-Host "Warnings: $totalWarnings"
Write-Host "Failures: $totalFailures"
Write-Host "Global issues: $($globalIssues.Count)"

if ($overallStatus -eq 'FAIL') {
    exit 1
}
