#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$HealthReportPath = 'reports/repository-status.json',
    [string]$OutputPath = 'STATUS.md'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-AbsolutePath {
    param([Parameter(Mandatory)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $RepositoryRoot $Path
}

function Escape-MarkdownTableValue {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '' }
    return (($Value -replace '\r?\n', ' ') -replace '\|', '\|')
}

function Get-IssueLabel {
    param(
        [Parameter(Mandatory)][string]$Code,
        [AllowNull()][string]$Message
    )

    switch ($Code) {
        'screenshot_en_missing' { return 'English screenshot missing' }
        'screenshot_missing' { return 'Default / Japanese screenshot missing' }
        'favicon_missing' { return 'Favicon missing' }
        'legacy_app_config_missing' { return 'Legacy app config missing' }
        'legacy_app_config_unavailable' { return 'Legacy runtime metadata unavailable' }
        'build_output_unknown' { return 'Build output metadata incomplete' }
        'runtime_network_policy_unknown' { return 'Runtime network policy metadata incomplete' }
        'app_config_version_mismatch' { return 'Registry / app.config version mismatch' }
        'release_version_mismatch' { return 'Registry / latest release version mismatch' }
        'registered_version_tag_missing' { return 'Registered version tag missing' }
        'wasm_dependency_not_declared' { return 'WASM dependency is not declared in registry metadata' }
        'repository_lookup_failed' { return 'Repository lookup failed' }
        'source_report_unavailable' { return 'Health source report unavailable' }
        'source_entry_missing' { return 'Health source entry missing' }
        default {
            if (-not [string]::IsNullOrWhiteSpace($Message)) { return $Message }
            return ($Code -replace '_', ' ')
        }
    }
}

$healthPath = Get-AbsolutePath -Path $HealthReportPath
$schemaPath = Join-Path $RepositoryRoot 'schema/repository-health.schema.json'
foreach ($requiredPath in @($healthPath, $schemaPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$raw = Get-Content -LiteralPath $healthPath -Raw -Encoding UTF8
if (-not (Test-Json -Json $raw -SchemaFile $schemaPath)) {
    throw 'Repository health JSON does not match schema/repository-health.schema.json.'
}
$report = $raw | ConvertFrom-Json -Depth 100
$apps = @($report.applications)

$reasonCounts = @{}
$reasonLabels = @{}
foreach ($app in $apps) {
    foreach ($issue in @($app.issues)) {
        if ([string]$issue.severity -ne 'WARN') { continue }
        $code = [string]$issue.code
        if ([string]::IsNullOrWhiteSpace($code)) { $code = 'unspecified' }
        if (-not $reasonCounts.ContainsKey($code)) {
            $reasonCounts[$code] = 0
            $reasonLabels[$code] = Get-IssueLabel -Code $code -Message ([string]$issue.message)
        }
        $reasonCounts[$code] = [int]$reasonCounts[$code] + 1
    }
}

$reasonRows = @(
    foreach ($code in $reasonCounts.Keys) {
        [pscustomobject]@{
            Code = [string]$code
            Label = [string]$reasonLabels[$code]
            Count = [int]$reasonCounts[$code]
        }
    }
) | Sort-Object @{ Expression = { $_.Count }; Descending = $true }, Label

$failApps = @($apps | Where-Object { [string]$_.overallStatus -eq 'FAIL' } | Sort-Object name)
$attentionApps = @($apps | Where-Object { [string]$_.overallStatus -ne 'PASS' } | Sort-Object @{ Expression = { if ([string]$_.overallStatus -eq 'FAIL') { 0 } else { 1 } } }, name)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Browser Kitty Repository Health')
$lines.Add('')
$lines.Add('[Live Repository Health](https://github.com/ttomohisa/browser-kitty-apps/actions/workflows/repository-health.yml) · [App catalog](CATALOG.md) · [Browser Kitty](https://browser-kitty.com/)')
$lines.Add('')
$lines.Add('> This file is generated from `reports/repository-status.json`. A committed copy is a snapshot; the GitHub Actions Job Summary is the live view.')
$lines.Add('')
$lines.Add("Last checked: **$([string]$report.generatedAt)**")
$lines.Add('')
$overallText = if ([string]$report.overallStatus -eq 'FAIL') { 'FAIL — blocking problems detected' } elseif ([string]$report.overallStatus -eq 'WARN') { 'WARN — no blocking failures, follow-up items remain' } else { 'PASS — no detected issues' }
$lines.Add('## Overall')
$lines.Add('')
$lines.Add("**$overallText**")
$lines.Add('')
$lines.Add('| Status | Apps |')
$lines.Add('|---|---:|')
$lines.Add("| PASS | $([int]$report.summary.pass) |")
$lines.Add("| WARN | $([int]$report.summary.warn) |")
$lines.Add("| FAIL | $([int]$report.summary.fail) |")
$lines.Add('')
$lines.Add("Registered apps: **$([int]$report.summary.registeredApps)**  ")
$lines.Add("Warnings: **$([int]$report.summary.warnings)**  ")
$lines.Add("Failures: **$([int]$report.summary.failures)**  ")
$lines.Add("Global issues: **$([int]$report.summary.globalIssues)**")
$lines.Add('')

$lines.Add('## Blocking problems')
$lines.Add('')
if ($failApps.Count -eq 0 -and [int]$report.summary.globalIssues -eq 0) {
    $lines.Add('No blocking application failures were detected.')
    $lines.Add('')
}
else {
    foreach ($app in $failApps) {
        $failIssues = @($app.issues | Where-Object { [string]$_.severity -eq 'FAIL' })
        $lines.Add("### $([string]$app.name)")
        $lines.Add('')
        foreach ($issue in $failIssues) {
            $label = Get-IssueLabel -Code ([string]$issue.code) -Message ([string]$issue.message)
            $lines.Add("- **$([string]$issue.source)** — ${label}: $([string]$issue.message)")
        }
        $lines.Add('')
    }
    foreach ($issue in @($report.globalIssues | Where-Object { [string]$_.severity -eq 'FAIL' })) {
        $lines.Add("- **Global** [$([string]$issue.source)/$([string]$issue.code)] $([string]$issue.message)")
    }
    $lines.Add('')
}

$lines.Add('## Warnings by reason')
$lines.Add('')
if ($reasonRows.Count -eq 0) {
    $lines.Add('No warnings detected.')
    $lines.Add('')
}
else {
    $lines.Add('| Count | Reason | Code |')
    $lines.Add('|---:|---|---|')
    foreach ($reason in $reasonRows) {
        $codeText = '`' + (Escape-MarkdownTableValue -Value $reason.Code) + '`'
        $lines.Add("| $($reason.Count) | $(Escape-MarkdownTableValue -Value $reason.Label) | $codeText |")
    }
    $lines.Add('')
}

$lines.Add('## Apps needing attention')
$lines.Add('')
if ($attentionApps.Count -eq 0) {
    $lines.Add('All registered applications are PASS.')
    $lines.Add('')
}
else {
    $lines.Add('| Status | App | Inventory | Quality | Pages | Release | Runtime | Issues | Reasons |')
    $lines.Add('|---|---|---|---|---|---|---|---:|---|')
    foreach ($app in $attentionApps) {
        $labels = [System.Collections.Generic.List[string]]::new()
        foreach ($issue in @($app.issues)) {
            $label = Get-IssueLabel -Code ([string]$issue.code) -Message ([string]$issue.message)
            if (-not $labels.Contains($label)) { $labels.Add($label) }
        }
        $issueTotal = [int]$app.issueCounts.warn + [int]$app.issueCounts.fail
        $reasonText = if ($labels.Count -gt 0) { $labels -join '; ' } else { '—' }
        $lines.Add("| $([string]$app.overallStatus) | $(Escape-MarkdownTableValue -Value ([string]$app.name)) | $([string]$app.checks.inventory) | $([string]$app.checks.quality) | $([string]$app.checks.pages) | $([string]$app.checks.releases) | $([string]$app.checks.runtime) | $issueTotal | $(Escape-MarkdownTableValue -Value $reasonText) |")
    }
    $lines.Add('')
}

$lines.Add('## Status meanings')
$lines.Add('')
$lines.Add('- **PASS** — no issue was detected by the current checks.')
$lines.Add('- **WARN** — non-blocking repository hygiene, legacy migration, or metadata debt needs follow-up.')
$lines.Add('- **FAIL** — a blocking publication, repository, or runtime problem needs attention.')
$lines.Add('')
$lines.Add('The detailed machine-readable report remains `reports/repository-status.json`; the detailed source-oriented Markdown report remains `reports/repository-status.md`.')
$lines.Add('')

$content = (($lines -join "`n").TrimEnd() + "`n")
$output = Get-AbsolutePath -Path $OutputPath
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($output, $content, $utf8NoBom)

Write-Host "Human-readable health status written: $output"
Write-Host "Overall: $([string]$report.overallStatus)"
Write-Host "Attention apps: $($attentionApps.Count)"
Write-Host "Warning reasons: $($reasonRows.Count)"
