#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InventoryPath = 'reports/repository-inventory.json',
    [string]$OutputPath = 'reports/repository-quality.json',
    [string]$GitHubToken = $env:BROWSER_KITTY_GITHUB_TOKEN,
    [string]$ApiBaseUrl = 'https://api.github.com',
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

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$qualitySchemaPath = Join-Path $RepositoryRoot 'schema/repository-quality.schema.json'
$absoluteInventoryPath = Get-AbsolutePath -Path $InventoryPath

foreach ($requiredPath in @($appsPath, $qualitySchemaPath, $absoluteInventoryPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)
$inventory = Get-Content -LiteralPath $absoluteInventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$inventoryByAppId = @{}
foreach ($repository in @($inventory.repositories)) {
    $inventoryByAppId[[string]$repository.appId] = $repository
}

$headers = @{
    Accept                 = 'application/vnd.github+json'
    'User-Agent'           = 'browser-kitty-apps'
    'X-GitHub-Api-Version' = '2022-11-28'
}
if (-not [string]::IsNullOrWhiteSpace($GitHubToken)) {
    $headers.Authorization = "Bearer $GitHubToken"
}

function Invoke-GitHubGet {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int[]]$AllowedStatusCodes = @(200)
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Uri `
            -Headers $headers `
            -Method Get `
            -SkipHttpErrorCheck `
            -MaximumRedirection 5 `
            -TimeoutSec 30
    }
    catch {
        return [pscustomobject]@{
            StatusCode = 0
            Data       = $null
            Error      = $_.Exception.Message
        }
    }

    $statusCode = [int]$response.StatusCode
    $data = $null
    $errorMessage = $null

    if (-not [string]::IsNullOrWhiteSpace([string]$response.Content)) {
        try {
            $data = $response.Content | ConvertFrom-Json -Depth 100
        }
        catch {
            if ($AllowedStatusCodes -contains $statusCode) {
                $errorMessage = "GitHub returned invalid JSON (HTTP $statusCode)."
            }
        }
    }

    if (-not ($AllowedStatusCodes -contains $statusCode)) {
        if ($null -ne $data -and $null -ne $data.PSObject.Properties['message']) {
            $errorMessage = "HTTP $statusCode: $($data.message)"
        }
        else {
            $errorMessage = "HTTP $statusCode"
        }
    }

    return [pscustomobject]@{
        StatusCode = $statusCode
        Data       = $data
        Error      = $errorMessage
    }
}

function New-Issue {
    param(
        [Parameter(Mandatory)][ValidateSet('WARN', 'FAIL')][string]$Severity,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Message
    )

    return [pscustomobject]@{
        severity = $Severity
        code     = $Code
        path     = $Path
        message  = $Message
    }
}

function Test-PathInTree {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$PathSet,
        [Parameter(Mandatory)][string]$Path
    )

    return $PathSet.Contains($Path)
}

Write-Host 'Browser Kitty repository quality check'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host "Inventory: $absoluteInventoryPath"
Write-Host "Authenticated: $(-not [string]::IsNullOrWhiteSpace($GitHubToken))"
Write-Host ''

$results = [System.Collections.Generic.List[object]]::new()
$passCount = 0
$warnCount = 0
$failCount = 0
$lookupErrorCount = 0

foreach ($app in $apps) {
    $appId = [string]$app.id
    $repositoryName = [string]$app.repository
    Write-Host "Checking $repositoryName ..." -NoNewline

    if (-not $inventoryByAppId.ContainsKey($appId)) {
        $entry = [ordered]@{
            appId        = $appId
            name         = [string]$app.name
            repository   = $repositoryName
            registryStatus = [string]$app.status
            published    = [bool]$app.browserKitty.published
            lookupStatus = 'error'
            qualityStatus = 'FAIL'
            defaultBranch = $null
            treeTruncated = $false
            files        = $null
            issues       = @(
                New-Issue -Severity FAIL -Code 'inventory_missing' -Path $InventoryPath -Message 'Repository is missing from the repository inventory.'
            )
            error        = 'Repository inventory entry is missing.'
        }
        $results.Add([pscustomobject]$entry)
        $failCount++
        $lookupErrorCount++
        Write-Host ' FAIL (inventory missing)' -ForegroundColor Red
        continue
    }

    $inventoryEntry = $inventoryByAppId[$appId]
    if ([string]$inventoryEntry.lookupStatus -ne 'ok' -or -not [bool]$inventoryEntry.exists) {
        $entry = [ordered]@{
            appId        = $appId
            name         = [string]$app.name
            repository   = $repositoryName
            registryStatus = [string]$app.status
            published    = [bool]$app.browserKitty.published
            lookupStatus = 'error'
            qualityStatus = 'FAIL'
            defaultBranch = if ($null -eq $inventoryEntry.defaultBranch) { $null } else { [string]$inventoryEntry.defaultBranch }
            treeTruncated = $false
            files        = $null
            issues       = @(
                New-Issue -Severity FAIL -Code 'repository_unavailable' -Path $repositoryName -Message 'Repository is unavailable according to the repository inventory.'
            )
            error        = 'Cannot inspect files because the repository is unavailable.'
        }
        $results.Add([pscustomobject]$entry)
        $failCount++
        $lookupErrorCount++
        Write-Host ' FAIL (repository unavailable)' -ForegroundColor Red
        continue
    }

    $defaultBranch = [string]$inventoryEntry.defaultBranch
    if ([string]::IsNullOrWhiteSpace($defaultBranch)) {
        $entry = [ordered]@{
            appId        = $appId
            name         = [string]$app.name
            repository   = $repositoryName
            registryStatus = [string]$app.status
            published    = [bool]$app.browserKitty.published
            lookupStatus = 'error'
            qualityStatus = 'FAIL'
            defaultBranch = $null
            treeTruncated = $false
            files        = $null
            issues       = @(
                New-Issue -Severity FAIL -Code 'default_branch_missing' -Path $repositoryName -Message 'Default branch is missing from the repository inventory.'
            )
            error        = 'Default branch is unavailable.'
        }
        $results.Add([pscustomobject]$entry)
        $failCount++
        $lookupErrorCount++
        Write-Host ' FAIL (default branch missing)' -ForegroundColor Red
        continue
    }

    $encodedRepository = ($repositoryName -split '/', 2 | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $encodedBranch = [Uri]::EscapeDataString($defaultBranch)
    $treeUri = "$($ApiBaseUrl.TrimEnd('/'))/repos/$encodedRepository/git/trees/${encodedBranch}?recursive=1"
    $treeResponse = Invoke-GitHubGet -Uri $treeUri

    if ($treeResponse.StatusCode -ne 200 -or $null -eq $treeResponse.Data) {
        $message = if ([string]::IsNullOrWhiteSpace([string]$treeResponse.Error)) { 'Repository tree lookup failed.' } else { [string]$treeResponse.Error }
        $entry = [ordered]@{
            appId        = $appId
            name         = [string]$app.name
            repository   = $repositoryName
            registryStatus = [string]$app.status
            published    = [bool]$app.browserKitty.published
            lookupStatus = 'error'
            qualityStatus = 'FAIL'
            defaultBranch = $defaultBranch
            treeTruncated = $false
            files        = $null
            issues       = @(
                New-Issue -Severity FAIL -Code 'tree_lookup_failed' -Path $defaultBranch -Message $message
            )
            error        = $message
        }
        $results.Add([pscustomobject]$entry)
        $failCount++
        $lookupErrorCount++
        Write-Host ' FAIL (tree lookup)' -ForegroundColor Red
        continue
    }

    $treeTruncated = $false
    if ($null -ne $treeResponse.Data.PSObject.Properties['truncated']) {
        $treeTruncated = [bool]$treeResponse.Data.truncated
    }

    $pathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($item in @($treeResponse.Data.tree)) {
        if ([string]$item.type -eq 'blob') {
            [void]$pathSet.Add([string]$item.path)
        }
    }

    $files = [ordered]@{
        readme       = Test-PathInTree -PathSet $pathSet -Path 'README.md'
        license      = Test-PathInTree -PathSet $pathSet -Path 'LICENSE'
        appConfig    = Test-PathInTree -PathSet $pathSet -Path 'app.config.json'
        packageJson  = Test-PathInTree -PathSet $pathSet -Path 'package.json'
        favicon      = Test-PathInTree -PathSet $pathSet -Path 'assets/favicon.svg'
        screenshot   = Test-PathInTree -PathSet $pathSet -Path 'assets/screenshot.png'
        screenshotEn = Test-PathInTree -PathSet $pathSet -Path 'assets/screenshot-en.png'
    }

    $issues = [System.Collections.Generic.List[object]]::new()

    if ($treeTruncated) {
        $issues.Add((New-Issue -Severity WARN -Code 'tree_truncated' -Path $defaultBranch -Message 'GitHub returned a truncated recursive tree; file-presence results may be incomplete.'))
    }

    foreach ($required in @(
        @{ Key = 'readme';    Path = 'README.md';          Code = 'readme_missing';    Message = 'README.md is required.' },
        @{ Key = 'license';   Path = 'LICENSE';            Code = 'license_missing';   Message = 'LICENSE is required.' },
        @{ Key = 'appConfig'; Path = 'app.config.json';    Code = 'app_config_missing'; Message = 'app.config.json is required for managed Browser Kitty apps.' },
        @{ Key = 'favicon';   Path = 'assets/favicon.svg'; Code = 'favicon_missing';   Message = 'assets/favicon.svg is required.' }
    )) {
        if (-not [bool]$files[$required.Key]) {
            $issues.Add((New-Issue -Severity FAIL -Code $required.Code -Path $required.Path -Message $required.Message))
        }
    }

    $isPublishedRelease = [bool]$app.browserKitty.published -and ([string]$app.status -in @('stable', 'maintenance'))
    foreach ($screenshot in @(
        @{ Key = 'screenshot';   Path = 'assets/screenshot.png';    Code = 'screenshot_missing';    Message = 'Japanese/default screenshot is missing.' },
        @{ Key = 'screenshotEn'; Path = 'assets/screenshot-en.png'; Code = 'screenshot_en_missing'; Message = 'English screenshot is missing.' }
    )) {
        if (-not [bool]$files[$screenshot.Key]) {
            $severity = if ($isPublishedRelease) { 'FAIL' } else { 'WARN' }
            $message = if ($isPublishedRelease) {
                "$($screenshot.Message) Published stable/maintenance apps require release screenshots."
            }
            else {
                "$($screenshot.Message) Add it before the stable release."
            }
            $issues.Add((New-Issue -Severity $severity -Code $screenshot.Code -Path $screenshot.Path -Message $message))
        }
    }

    # package.json is intentionally informational. The current htmlapps-template does not require Node/package.json.
    $qualityStatus = 'PASS'
    if (@($issues | Where-Object { $_.severity -eq 'FAIL' }).Count -gt 0) {
        $qualityStatus = 'FAIL'
    }
    elseif (@($issues | Where-Object { $_.severity -eq 'WARN' }).Count -gt 0) {
        $qualityStatus = 'WARN'
    }

    switch ($qualityStatus) {
        'PASS' { $passCount++; Write-Host ' PASS' -ForegroundColor Green }
        'WARN' { $warnCount++; Write-Host " WARN ($($issues.Count) issue(s))" -ForegroundColor Yellow }
        'FAIL' { $failCount++; Write-Host " FAIL ($($issues.Count) issue(s))" -ForegroundColor Red }
    }

    $entry = [ordered]@{
        appId          = $appId
        name           = [string]$app.name
        repository     = $repositoryName
        registryStatus = [string]$app.status
        published      = [bool]$app.browserKitty.published
        lookupStatus   = 'ok'
        qualityStatus  = $qualityStatus
        defaultBranch  = $defaultBranch
        treeTruncated  = $treeTruncated
        files          = $files
        issues         = @($issues)
        error          = $null
    }
    $results.Add([pscustomobject]$entry)
}

$quality = [ordered]@{
    schemaVersion   = 1
    generatedAt     = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRegistry  = 'apps.json'
    sourceInventory = ($InventoryPath -replace '\\', '/')
    githubApi       = $ApiBaseUrl
    authenticated   = -not [string]::IsNullOrWhiteSpace($GitHubToken)
    policy          = [ordered]@{
        requiredCoreFiles = @('README.md', 'LICENSE', 'app.config.json', 'assets/favicon.svg')
        releaseScreenshotFiles = @('assets/screenshot.png', 'assets/screenshot-en.png')
        packageJsonRequired = $false
    }
    summary         = [ordered]@{
        registeredApps = $apps.Count
        checkedApps     = $results.Count
        pass            = $passCount
        warn            = $warnCount
        fail            = $failCount
        lookupErrors    = $lookupErrorCount
    }
    repositories    = @($results)
}

$qualityJson = $quality | ConvertTo-Json -Depth 30
if (-not (Test-Json -Json $qualityJson -SchemaFile $qualitySchemaPath)) {
    throw 'Generated repository quality report does not match schema/repository-quality.schema.json.'
}

if (-not $NoWrite) {
    $absoluteOutputPath = Get-AbsolutePath -Path $OutputPath
    $outputDirectory = Split-Path -Parent $absoluteOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $qualityJson | Set-Content -LiteralPath $absoluteOutputPath -Encoding utf8NoBOM
    Write-Host ''
    Write-Host "Quality report written: $absoluteOutputPath"
}

Write-Host ''
Write-Host "PASS: $passCount"
Write-Host "WARN: $warnCount"
Write-Host "FAIL: $failCount"
Write-Host "Lookup errors: $lookupErrorCount"

if ($failCount -gt 0) {
    exit 1
}
