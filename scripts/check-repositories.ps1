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
foreach ($requiredPath in @($appsPath, $inventorySchemaPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Required file not found: $requiredPath" }
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)
$headers = @{
    Accept='application/vnd.github+json'; 'User-Agent'='browser-kitty-apps'; 'X-GitHub-Api-Version'='2022-11-28'
}
if (-not [string]::IsNullOrWhiteSpace($GitHubToken)) { $headers.Authorization = "Bearer $GitHubToken" }

function Invoke-GitHubGet {
    param([Parameter(Mandatory)][string]$Uri, [int[]]$AllowedStatusCodes=@(200))
    try {
        $response = Invoke-WebRequest -Uri $Uri -Headers $headers -Method Get -SkipHttpErrorCheck -MaximumRedirection 5 -TimeoutSec 30
    } catch {
        return [pscustomobject]@{ StatusCode=0; Data=$null; Error=$_.Exception.Message }
    }
    $statusCode=[int]$response.StatusCode; $data=$null; $errorMessage=$null
    if (-not [string]::IsNullOrWhiteSpace([string]$response.Content)) {
        try { $data=$response.Content | ConvertFrom-Json -Depth 100 }
        catch { if ($AllowedStatusCodes -contains $statusCode) { $errorMessage="GitHub returned invalid JSON (HTTP $statusCode)." } }
    }
    if (-not ($AllowedStatusCodes -contains $statusCode)) {
        if ($null -ne $data -and $null -ne $data.PSObject.Properties['message']) { $errorMessage="HTTP ${statusCode}: $($data.message)" }
        else { $errorMessage="HTTP $statusCode" }
    }
    [pscustomobject]@{ StatusCode=$statusCode; Data=$data; Error=$errorMessage }
}
function Get-AbsoluteOutputPath { param([Parameter(Mandatory)][string]$Path); if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $RepositoryRoot $Path } }

Write-Host 'Browser Kitty repository inventory'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host 'Lookup mode: owner-batched public repository inventory'
Write-Host ''

# Full Registry can exceed GitHub's unauthenticated 60 requests/hour limit if each repo is queried separately.
# Fetch each owner's public repositories in pages of 100, then match locally.
$repoIndex=@{}; $ownerErrors=@{}
$owners=@($apps | ForEach-Object { ([string]$_.repository -split '/',2)[0] } | Sort-Object -Unique)
foreach ($owner in $owners) {
    $page=1
    while ($true) {
        $encodedOwner=[Uri]::EscapeDataString($owner)
        $uri="$($ApiBaseUrl.TrimEnd('/'))/users/$encodedOwner/repos?type=owner&sort=full_name&per_page=100&page=$page"
        $response=Invoke-GitHubGet -Uri $uri
        if ($response.StatusCode -ne 200 -or $null -eq $response.Data) {
            $ownerErrors[$owner]=if ([string]::IsNullOrWhiteSpace([string]$response.Error)) { 'Owner repository listing failed.' } else { [string]$response.Error }
            break
        }
        $pageItems=@($response.Data)
        foreach ($repo in $pageItems) {
            $fullName=[string]$repo.full_name
            if (-not [string]::IsNullOrWhiteSpace($fullName)) { $repoIndex[$fullName.ToLowerInvariant()]=$repo }
        }
        if ($pageItems.Count -lt 100) { break }
        $page++
    }
}

$results=[Collections.Generic.List[object]]::new(); $missingCount=0; $errorCount=0; $warningCount=0; $privateCount=0; $archivedCount=0
foreach ($app in $apps) {
    $repository=[string]$app.repository; $owner=($repository -split '/',2)[0]
    Write-Host "Checking $repository ..." -NoNewline
    $entry=[ordered]@{
        appId=[string]$app.id; name=[string]$app.name; repository=$repository; registryStatus=[string]$app.status; registeredVersion=[string]$app.release.version
        lookupStatus='ok'; exists=$true; visibility=$null; private=$null; archived=$null; defaultBranch=$null; htmlUrl=$null; pushedAt=$null; updatedAt=$null
        releaseLookupStatus='not-checked'; hasLatestRelease=$false; latestRelease=$null; warnings=@(); error=$null
    }
    if ($ownerErrors.ContainsKey($owner)) {
        $entry.lookupStatus='error'; $entry.exists=$false; $entry.error=[string]$ownerErrors[$owner]; $errorCount++; $results.Add([pscustomobject]$entry)
        Write-Host ' ERROR' -ForegroundColor Red; continue
    }
    $key=$repository.ToLowerInvariant()
    if (-not $repoIndex.ContainsKey($key)) {
        $entry.lookupStatus='missing'; $entry.exists=$false; $entry.error='Repository was not found in the owner public-repository listing.'; $missingCount++; $errorCount++
        $results.Add([pscustomobject]$entry); Write-Host ' MISSING' -ForegroundColor Red; continue
    }
    $repo=$repoIndex[$key]; $warnings=[Collections.Generic.List[string]]::new()
    $entry.visibility=if ($null -ne $repo.PSObject.Properties['visibility']) {[string]$repo.visibility} else {'public'}
    $entry.private=if ($null -ne $repo.PSObject.Properties['private']) {[bool]$repo.private} else {$false}
    $entry.archived=if ($null -ne $repo.PSObject.Properties['archived']) {[bool]$repo.archived} else {$false}
    $entry.defaultBranch=[string]$repo.default_branch; $entry.htmlUrl=[string]$repo.html_url; $entry.pushedAt=[string]$repo.pushed_at; $entry.updatedAt=[string]$repo.updated_at
    if ($entry.private) { $privateCount++; $warnings.Add('Repository is private; Browser Kitty application repositories are normally public.') }
    if ($entry.archived -and [string]$app.status -ne 'archived') { $archivedCount++; $warnings.Add("Repository is archived but registry status is '$($app.status)'.") }
    elseif (-not $entry.archived -and [string]$app.status -eq 'archived') { $warnings.Add('Registry status is archived but the GitHub repository is not archived.') }
    $entry.warnings=@($warnings); $warningCount += $warnings.Count
    $results.Add([pscustomobject]$entry)
    if ($warnings.Count) { Write-Host " OK ($($warnings.Count) warning(s))" -ForegroundColor Yellow } else { Write-Host ' OK' -ForegroundColor Green }
}

$inventory=[ordered]@{
    schemaVersion=1; generatedAt=[DateTimeOffset]::UtcNow.ToString('o'); sourceRegistry='apps.json'; githubApi=$ApiBaseUrl; authenticated=-not [string]::IsNullOrWhiteSpace($GitHubToken)
    summary=[ordered]@{
        registeredApps=$apps.Count; checkedRepositories=$results.Count; existingRepositories=@($results|Where-Object{$_.exists}).Count; missingRepositories=$missingCount
        privateRepositories=$privateCount; archivedRepositories=$archivedCount; withLatestRelease=0; withoutLatestRelease=0
        warnings=$warningCount; errors=$errorCount
    }
    repositories=@($results)
}
$json=$inventory|ConvertTo-Json -Depth 20
if (-not (Test-Json -Json $json -SchemaFile $inventorySchemaPath)) { throw 'Generated repository inventory does not match schema/repository-inventory.schema.json.' }
if (-not $NoWrite) { $out=Get-AbsoluteOutputPath -Path $OutputPath; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out)|Out-Null; $json|Set-Content -LiteralPath $out -Encoding utf8NoBOM; Write-Host "Inventory written: $out" }
Write-Host "Existing: $(@($results|Where-Object{$_.exists}).Count) / $($apps.Count)"
Write-Host "Warnings: $warningCount"
Write-Host "Errors: $errorCount"
if ($errorCount -gt 0) { exit 1 }
