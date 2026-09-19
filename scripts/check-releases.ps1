#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InventoryPath = 'reports/repository-inventory.json',
    [string]$OutputPath = 'reports/repository-releases.json',
    [string]$GitHubToken = $env:BROWSER_KITTY_GITHUB_TOKEN,
    [string]$ApiBaseUrl = 'https://api.github.com',
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$schemaPath = Join-Path $RepositoryRoot 'schema/repository-releases.schema.json'
$absoluteInventoryPath = if ([System.IO.Path]::IsPathRooted($InventoryPath)) { $InventoryPath } else { Join-Path $RepositoryRoot $InventoryPath }

foreach ($requiredPath in @($appsPath, $schemaPath, $absoluteInventoryPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)
$inventory = Get-Content -LiteralPath $absoluteInventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100

$inventoryByAppId = @{}
foreach ($entry in @($inventory.repositories)) {
    $inventoryByAppId[[string]$entry.appId] = $entry
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
    }
}

function Get-AbsoluteOutputPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $RepositoryRoot $Path
}

function New-Issue {
    param(
        [Parameter(Mandatory)][ValidateSet('WARN', 'FAIL')][string]$Severity,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message
    )

    return [pscustomobject]@{
        severity = $Severity
        code     = $Code
        message  = $Message
    }
}

function Normalize-VersionTag {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $trimmed = $Value.Trim()
    if ($trimmed.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $trimmed.Substring(1)
    }
    return $trimmed
}

Write-Host 'Browser Kitty release/version check'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host "Authenticated: $(-not [string]::IsNullOrWhiteSpace($GitHubToken))"
Write-Host ''

$results = [System.Collections.Generic.List[object]]::new()
$passCount = 0
$warnCount = 0
$failCount = 0
$lookupErrorCount = 0

foreach ($app in $apps) {
    $appId = [string]$app.id
    $repository = [string]$app.repository
    $registeredVersion = [string]$app.release.version
    Write-Host "Checking $repository ..." -NoNewline

    $issues = [System.Collections.Generic.List[object]]::new()
    $defaultBranch = $null
    $appConfigLookupStatus = 'error'
    $appConfigVersion = $null
    $registryMatchesAppConfig = $null
    $releaseLookupStatus = 'error'
    $releaseTag = $null
    $registryMatchesRelease = $null
    $tagLookupStatus = 'error'
    $tagCount = 0
    $matchingVersionTag = $null
    $tags = @()
    $errorMessage = $null

    if (-not $inventoryByAppId.ContainsKey($appId)) {
        $issues.Add((New-Issue -Severity FAIL -Code 'inventory_missing' -Message 'Repository is missing from repository-inventory.json.'))
        $errorMessage = 'Repository inventory entry is missing.'
        $lookupErrorCount++
    }
    else {
        $inventoryEntry = $inventoryByAppId[$appId]
        if ([string]$inventoryEntry.lookupStatus -ne 'ok' -or -not [bool]$inventoryEntry.exists) {
            $issues.Add((New-Issue -Severity FAIL -Code 'repository_unavailable' -Message 'Repository is unavailable according to repository-inventory.json.'))
            $errorMessage = 'Repository is unavailable.'
            $lookupErrorCount++
        }
        else {
            $defaultBranch = [string]$inventoryEntry.defaultBranch
            $encodedRepository = ($repository -split '/', 2 | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
            $encodedBranch = [Uri]::EscapeDataString($defaultBranch)
            $repositoryUri = "$($ApiBaseUrl.TrimEnd('/'))/repos/$encodedRepository"

            $configUri = "${repositoryUri}/contents/app.config.json?ref=$encodedBranch"
            $configResponse = Invoke-GitHubGet -Uri $configUri
            if ($configResponse.StatusCode -eq 200 -and $null -ne $configResponse.Data -and $null -ne $configResponse.Data.PSObject.Properties['content']) {
                try {
                    $base64 = ([string]$configResponse.Data.content) -replace '\s', ''
                    $configJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64))
                    $config = $configJson | ConvertFrom-Json -Depth 100
                    $appConfigVersion = [string]$config.version
                    $appConfigLookupStatus = 'ok'
                    $registryMatchesAppConfig = $registeredVersion -eq $appConfigVersion
                    if (-not $registryMatchesAppConfig) {
                        $issues.Add((New-Issue -Severity WARN -Code 'app_config_version_mismatch' -Message "Registry version '$registeredVersion' differs from app.config.json version '$appConfigVersion'."))
                    }
                }
                catch {
                    $appConfigLookupStatus = 'error'
                    $issues.Add((New-Issue -Severity FAIL -Code 'app_config_invalid' -Message "app.config.json could not be decoded or parsed: $($_.Exception.Message)"))
                    $lookupErrorCount++
                }
            }
            else {
                $appConfigLookupStatus = 'error'
                $message = if ([string]::IsNullOrWhiteSpace([string]$configResponse.Error)) { 'app.config.json lookup failed.' } else { [string]$configResponse.Error }
                $issues.Add((New-Issue -Severity FAIL -Code 'app_config_lookup_failed' -Message $message))
                $lookupErrorCount++
            }

            $releaseLookupStatus = [string]$inventoryEntry.releaseLookupStatus
            if ($releaseLookupStatus -eq 'ok' -and [bool]$inventoryEntry.hasLatestRelease -and $null -ne $inventoryEntry.latestRelease) {
                $releaseTag = [string]$inventoryEntry.latestRelease.tagName
                $registryMatchesRelease = (Normalize-VersionTag -Value $releaseTag) -eq $registeredVersion
                if (-not $registryMatchesRelease) {
                    $issues.Add((New-Issue -Severity WARN -Code 'release_version_mismatch' -Message "Registry version '$registeredVersion' differs from latest GitHub Release tag '$releaseTag'."))
                }
            }
            elseif ($releaseLookupStatus -eq 'none') {
                $registryMatchesRelease = $null
            }
            else {
                $issues.Add((New-Issue -Severity FAIL -Code 'release_lookup_failed' -Message 'Latest Release lookup failed in repository-inventory.json.'))
                $lookupErrorCount++
            }

            $tagsUri = "${repositoryUri}/git/matching-refs/tags/"
            $tagsResponse = Invoke-GitHubGet -Uri $tagsUri
            if ($tagsResponse.StatusCode -eq 200) {
                $tagLookupStatus = if (@($tagsResponse.Data).Count -eq 0) { 'none' } else { 'ok' }
                $tags = @(
                    $tagsResponse.Data |
                        ForEach-Object { [string]$_.ref } |
                        Where-Object { $_.StartsWith('refs/tags/', [System.StringComparison]::Ordinal) } |
                        ForEach-Object { $_.Substring('refs/tags/'.Length) }
                )
                $tagCount = $tags.Count
                $matchingVersionTag = @($tags | Where-Object { (Normalize-VersionTag -Value $_) -eq $registeredVersion } | Select-Object -First 1)
                if ($matchingVersionTag.Count -gt 0) {
                    $matchingVersionTag = [string]$matchingVersionTag[0]
                }
                else {
                    $matchingVersionTag = $null
                    if ($tagCount -gt 0) {
                        $issues.Add((New-Issue -Severity WARN -Code 'registered_version_tag_missing' -Message "Repository has tags, but none matches registry version '$registeredVersion' (accepted forms: '$registeredVersion' or 'v$registeredVersion')."))
                    }
                }
            }
            else {
                $tagLookupStatus = 'error'
                $message = if ([string]::IsNullOrWhiteSpace([string]$tagsResponse.Error)) { 'Tag lookup failed.' } else { [string]$tagsResponse.Error }
                $issues.Add((New-Issue -Severity FAIL -Code 'tag_lookup_failed' -Message $message))
                $lookupErrorCount++
            }
        }
    }

    $hasFail = @($issues | Where-Object { $_.severity -eq 'FAIL' }).Count -gt 0
    $hasWarn = @($issues | Where-Object { $_.severity -eq 'WARN' }).Count -gt 0
    $releaseStatus = if ($hasFail) { 'FAIL' } elseif ($hasWarn) { 'WARN' } else { 'PASS' }

    switch ($releaseStatus) {
        'PASS' { $passCount++; Write-Host ' PASS' -ForegroundColor Green }
        'WARN' { $warnCount++; Write-Host ' WARN' -ForegroundColor Yellow }
        'FAIL' { $failCount++; Write-Host ' FAIL' -ForegroundColor Red }
    }

    $results.Add([pscustomobject][ordered]@{
        appId                    = $appId
        name                     = [string]$app.name
        repository               = $repository
        registryStatus           = [string]$app.status
        registeredVersion        = $registeredVersion
        defaultBranch            = $defaultBranch
        releaseStatus            = $releaseStatus
        appConfigLookupStatus    = $appConfigLookupStatus
        appConfigVersion         = $appConfigVersion
        registryMatchesAppConfig = $registryMatchesAppConfig
        releaseLookupStatus      = $releaseLookupStatus
        latestReleaseTag         = $releaseTag
        registryMatchesRelease   = $registryMatchesRelease
        tagLookupStatus          = $tagLookupStatus
        tagCount                 = $tagCount
        matchingVersionTag       = $matchingVersionTag
        tags                     = @($tags)
        issues                   = @($issues)
        error                    = $errorMessage
    })
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt   = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRegistry = 'apps.json'
    sourceInventory = $InventoryPath
    githubApi     = $ApiBaseUrl
    authenticated = -not [string]::IsNullOrWhiteSpace($GitHubToken)
    policy = [ordered]@{
        missingReleaseIsFailure    = $false
        missingTagsIsFailure       = $false
        versionMismatchSeverity    = 'WARN'
        acceptedTagForms           = @('<version>', 'v<version>')
    }
    summary = [ordered]@{
        registeredApps = $apps.Count
        checkedApps    = $results.Count
        pass           = $passCount
        warn           = $warnCount
        fail           = $failCount
        lookupErrors   = $lookupErrorCount
    }
    applications = @($results)
}

$reportJson = $report | ConvertTo-Json -Depth 30
if (-not (Test-Json -Json $reportJson -SchemaFile $schemaPath)) {
    throw 'Generated Release report does not match schema/repository-releases.schema.json.'
}

if (-not $NoWrite) {
    $absoluteOutputPath = Get-AbsoluteOutputPath -Path $OutputPath
    $outputDirectory = Split-Path -Parent $absoluteOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $reportJson | Set-Content -LiteralPath $absoluteOutputPath -Encoding utf8NoBOM
    Write-Host ''
    Write-Host "Release report written: $absoluteOutputPath"
}

Write-Host ''
Write-Host "PASS: $passCount"
Write-Host "WARN: $warnCount"
Write-Host "FAIL: $failCount"
Write-Host "Lookup errors: $lookupErrorCount"

if ($failCount -gt 0) {
    exit 1
}
