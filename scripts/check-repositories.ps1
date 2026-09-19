#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = 'reports/repository-inventory.json',
    [string]$GitHubToken = $env:BROWSER_KITTY_GITHUB_TOKEN,
    [string]$ApiBaseUrl = 'https://api.github.com',
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$inventorySchemaPath = Join-Path $RepositoryRoot 'schema/repository-inventory.schema.json'
if (-not (Test-Path -LiteralPath $appsPath -PathType Leaf)) {
    throw "Required file not found: $appsPath"
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)

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
            Headers    = $null
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
            $errorMessage = "HTTP ${statusCode}: $($data.message)"
        }
        else {
            $errorMessage = "HTTP $statusCode"
        }
    }

    return [pscustomobject]@{
        StatusCode = $statusCode
        Data       = $data
        Error      = $errorMessage
        Headers    = $response.Headers
    }
}

function Get-AbsoluteOutputPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $RepositoryRoot $Path
}

Write-Host 'Browser Kitty repository inventory'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host "GitHub API: $ApiBaseUrl"
Write-Host "Authenticated: $(-not [string]::IsNullOrWhiteSpace($GitHubToken))"
Write-Host ''

$results = [System.Collections.Generic.List[object]]::new()
$missingCount = 0
$errorCount = 0
$warningCount = 0
$privateCount = 0
$archivedCount = 0
$releaseCount = 0

foreach ($app in $apps) {
    $repository = [string]$app.repository
    $encodedRepository = ($repository -split '/', 2 | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $repositoryUri = "$($ApiBaseUrl.TrimEnd('/'))/repos/$encodedRepository"

    Write-Host "Checking $repository ..." -NoNewline
    $repoResponse = Invoke-GitHubGet -Uri $repositoryUri -AllowedStatusCodes @(200, 404)

    $entryWarnings = [System.Collections.Generic.List[string]]::new()
    $entry = [ordered]@{
        appId             = [string]$app.id
        name              = [string]$app.name
        repository        = $repository
        registryStatus    = [string]$app.status
        registeredVersion = [string]$app.release.version
        lookupStatus      = 'ok'
        exists            = $true
        visibility        = $null
        private           = $null
        archived          = $null
        defaultBranch     = $null
        htmlUrl           = $null
        pushedAt          = $null
        updatedAt         = $null
        releaseLookupStatus = 'none'
        hasLatestRelease  = $false
        latestRelease     = $null
        warnings          = @()
        error             = $null
    }

    if ($repoResponse.StatusCode -eq 404) {
        $entry.lookupStatus = 'missing'
        $entry.exists = $false
        $entry.error = 'Repository was not found or is not accessible with the current token.'
        $missingCount++
        $errorCount++
        Write-Host ' MISSING' -ForegroundColor Red
        $results.Add([pscustomobject]$entry)
        continue
    }

    if ($repoResponse.StatusCode -ne 200 -or $null -eq $repoResponse.Data) {
        $entry.lookupStatus = 'error'
        $entry.exists = $false
        $entry.error = if ([string]::IsNullOrWhiteSpace([string]$repoResponse.Error)) {
            'Repository lookup failed.'
        }
        else {
            [string]$repoResponse.Error
        }
        $errorCount++
        Write-Host ' ERROR' -ForegroundColor Red
        $results.Add([pscustomobject]$entry)
        continue
    }

    $repo = $repoResponse.Data
    $entry.visibility = if ($null -ne $repo.PSObject.Properties['visibility']) { [string]$repo.visibility } elseif ([bool]$repo.private) { 'private' } else { 'public' }
    $entry.private = [bool]$repo.private
    $entry.archived = [bool]$repo.archived
    $entry.defaultBranch = [string]$repo.default_branch
    $entry.htmlUrl = [string]$repo.html_url
    $entry.pushedAt = [string]$repo.pushed_at
    $entry.updatedAt = [string]$repo.updated_at

    if ($entry.private) {
        $privateCount++
        $entryWarnings.Add('Repository is private; Browser Kitty application repositories are normally public.')
    }

    if ($entry.archived) {
        $archivedCount++
        if ([string]$app.status -ne 'archived') {
            $entryWarnings.Add("Repository is archived but registry status is '$($app.status)'.")
        }
    }
    elseif ([string]$app.status -eq 'archived') {
        $entryWarnings.Add('Registry status is archived but the GitHub repository is not archived.')
    }

    $releaseUri = "$repositoryUri/releases/latest"
    $releaseResponse = Invoke-GitHubGet -Uri $releaseUri -AllowedStatusCodes @(200, 404)

    if ($releaseResponse.StatusCode -eq 200 -and $null -ne $releaseResponse.Data) {
        $release = $releaseResponse.Data
        $entry.releaseLookupStatus = 'ok'
        $entry.hasLatestRelease = $true
        $entry.latestRelease = [ordered]@{
            tagName     = [string]$release.tag_name
            name        = if ($null -eq $release.name) { $null } else { [string]$release.name }
            draft       = [bool]$release.draft
            prerelease  = [bool]$release.prerelease
            publishedAt = if ($null -eq $release.published_at) { $null } else { [string]$release.published_at }
            htmlUrl     = [string]$release.html_url
        }
        $releaseCount++
    }
    elseif ($releaseResponse.StatusCode -ne 404) {
        $entry.releaseLookupStatus = 'error'
        $entryWarnings.Add("Latest Release lookup failed: $($releaseResponse.Error)")
        $errorCount++
    }

    $entry.warnings = @($entryWarnings)
    $warningCount += $entryWarnings.Count

    if ($entryWarnings.Count -gt 0) {
        Write-Host " OK ($($entryWarnings.Count) warning(s))" -ForegroundColor Yellow
    }
    else {
        Write-Host ' OK' -ForegroundColor Green
    }

    $results.Add([pscustomobject]$entry)
}

$inventory = [ordered]@{
    schemaVersion = 1
    generatedAt   = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRegistry = 'apps.json'
    githubApi     = $ApiBaseUrl
    authenticated = -not [string]::IsNullOrWhiteSpace($GitHubToken)
    summary       = [ordered]@{
        registeredApps       = $apps.Count
        checkedRepositories  = $results.Count
        existingRepositories = @($results | Where-Object { $_.exists }).Count
        missingRepositories  = $missingCount
        privateRepositories  = $privateCount
        archivedRepositories = $archivedCount
        withLatestRelease    = $releaseCount
        withoutLatestRelease = @($results | Where-Object { $_.exists -and -not $_.hasLatestRelease }).Count
        warnings             = $warningCount
        errors               = $errorCount
    }
    repositories  = @($results)
}

$inventoryJson = $inventory | ConvertTo-Json -Depth 20
if (Test-Path -LiteralPath $inventorySchemaPath -PathType Leaf) {
    if (-not (Test-Json -Json $inventoryJson -SchemaFile $inventorySchemaPath)) {
        throw 'Generated repository inventory does not match schema/repository-inventory.schema.json.'
    }
}
else {
    throw "Required file not found: $inventorySchemaPath"
}

if (-not $NoWrite) {
    $absoluteOutputPath = Get-AbsoluteOutputPath -Path $OutputPath
    $outputDirectory = Split-Path -Parent $absoluteOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $inventoryJson | Set-Content -LiteralPath $absoluteOutputPath -Encoding utf8NoBOM
    Write-Host ''
    Write-Host "Inventory written: $absoluteOutputPath"
}

Write-Host ''
Write-Host "Existing: $($inventory.summary.existingRepositories)/$($inventory.summary.registeredApps)"
Write-Host "Private: $($inventory.summary.privateRepositories)"
Write-Host "Archived: $($inventory.summary.archivedRepositories)"
Write-Host "Latest Release found: $($inventory.summary.withLatestRelease)"
Write-Host "Warnings: $($inventory.summary.warnings)"
Write-Host "Errors: $($inventory.summary.errors)"

if ($errorCount -gt 0) {
    exit 1
}
