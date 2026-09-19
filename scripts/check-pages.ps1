#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = 'reports/repository-pages.json',
    [int]$TimeoutSec = 30,
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$schemaPath = Join-Path $RepositoryRoot 'schema/repository-pages.schema.json'
if (-not (Test-Path -LiteralPath $appsPath -PathType Leaf)) {
    throw "Required file not found: $appsPath"
}
if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw "Required file not found: $schemaPath"
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)

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

$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $true
$handler.MaxAutomaticRedirections = 5
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
$client.DefaultRequestHeaders.UserAgent.ParseAdd('browser-kitty-apps')

Write-Host 'Browser Kitty GitHub Pages check'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host "Timeout: ${TimeoutSec}s"
Write-Host ''

$results = [System.Collections.Generic.List[object]]::new()
$passCount = 0
$warnCount = 0
$failCount = 0
$errorCount = 0

try {
    foreach ($app in $apps) {
        $appId = [string]$app.id
        $url = [string]$app.pages.url
        $published = [bool]$app.browserKitty.published
        Write-Host "Checking $url ..." -NoNewline

        $lookupStatus = 'ok'
        $statusCode = $null
        $finalUrl = $null
        $contentType = $null
        $errorMessage = $null
        $issues = [System.Collections.Generic.List[object]]::new()
        $response = $null
        $request = $null

        try {
            $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $url)
            $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()

            if ([int]$response.StatusCode -in @(405, 501)) {
                $response.Dispose()
                $request.Dispose()
                $response = $null
                $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $url)
                $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            }

            $statusCode = [int]$response.StatusCode
            if ($null -ne $response.RequestMessage -and $null -ne $response.RequestMessage.RequestUri) {
                $finalUrl = [string]$response.RequestMessage.RequestUri.AbsoluteUri
            }
            if ($null -ne $response.Content -and $null -ne $response.Content.Headers.ContentType) {
                $contentType = [string]$response.Content.Headers.ContentType.MediaType
            }
        }
        catch {
            $lookupStatus = 'error'
            $errorMessage = $_.Exception.Message
            $errorCount++
        }
        finally {
            if ($null -ne $response) {
                $response.Dispose()
            }
            if ($null -ne $request) {
                $request.Dispose()
            }
        }

        if ($lookupStatus -eq 'error') {
            $severity = if ($published) { 'FAIL' } else { 'WARN' }
            $issues.Add((New-Issue -Severity $severity -Code 'pages_lookup_failed' -Message "Pages lookup failed: $errorMessage"))
        }
        elseif ($statusCode -lt 200 -or $statusCode -ge 300) {
            $severity = if ($published) { 'FAIL' } else { 'WARN' }
            $issues.Add((New-Issue -Severity $severity -Code 'pages_http_status' -Message "Pages returned HTTP $statusCode."))
        }
        elseif (-not [string]::IsNullOrWhiteSpace($contentType) -and $contentType -notin @('text/html', 'application/xhtml+xml')) {
            $issues.Add((New-Issue -Severity WARN -Code 'pages_content_type' -Message "Pages returned content type '$contentType' instead of HTML."))
        }

        $hasFail = @($issues | Where-Object { $_.severity -eq 'FAIL' }).Count -gt 0
        $hasWarn = @($issues | Where-Object { $_.severity -eq 'WARN' }).Count -gt 0
        $pagesStatus = if ($hasFail) { 'FAIL' } elseif ($hasWarn) { 'WARN' } else { 'PASS' }

        switch ($pagesStatus) {
            'PASS' { $passCount++; Write-Host ' PASS' -ForegroundColor Green }
            'WARN' { $warnCount++; Write-Host ' WARN' -ForegroundColor Yellow }
            'FAIL' { $failCount++; Write-Host ' FAIL' -ForegroundColor Red }
        }

        $results.Add([pscustomobject][ordered]@{
            appId          = $appId
            name           = [string]$app.name
            repository     = [string]$app.repository
            registryStatus = [string]$app.status
            published      = $published
            url            = $url
            lookupStatus   = $lookupStatus
            pagesStatus    = $pagesStatus
            httpStatus     = $statusCode
            finalUrl       = $finalUrl
            contentType    = $contentType
            issues         = @($issues)
            error          = $errorMessage
        })
    }
}
finally {
    $client.Dispose()
    $handler.Dispose()
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt   = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRegistry = 'apps.json'
    policy = [ordered]@{
        publishedRequires2xx = $true
        acceptedContentTypes = @('text/html', 'application/xhtml+xml')
        maxRedirects = 5
        requestMethod = 'HEAD (GET fallback for 405/501)'
    }
    summary = [ordered]@{
        registeredApps = $apps.Count
        checkedApps    = $results.Count
        pass           = $passCount
        warn           = $warnCount
        fail           = $failCount
        lookupErrors   = $errorCount
    }
    applications = @($results)
}

$reportJson = $report | ConvertTo-Json -Depth 20
if (-not (Test-Json -Json $reportJson -SchemaFile $schemaPath)) {
    throw 'Generated Pages report does not match schema/repository-pages.schema.json.'
}

if (-not $NoWrite) {
    $absoluteOutputPath = Get-AbsoluteOutputPath -Path $OutputPath
    $outputDirectory = Split-Path -Parent $absoluteOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $reportJson | Set-Content -LiteralPath $absoluteOutputPath -Encoding utf8NoBOM
    Write-Host ''
    Write-Host "Pages report written: $absoluteOutputPath"
}

Write-Host ''
Write-Host "PASS: $passCount"
Write-Host "WARN: $warnCount"
Write-Host "FAIL: $failCount"
Write-Host "Lookup errors: $errorCount"

if ($failCount -gt 0) {
    exit 1
}
