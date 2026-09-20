#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = '',
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepositoryRoot 'generated/apps.public.json'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RepositoryRoot $OutputPath
}

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$categoriesPath = Join-Path $RepositoryRoot 'categories.json'
$schemaPath = Join-Path $RepositoryRoot 'schema/public-apps.schema.json'

foreach ($requiredPath in @($appsPath, $categoriesPath, $schemaPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$appsSource = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$categoriesSource = Get-Content -LiteralPath $categoriesPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$publishedApps = @($appsSource.apps | Where-Object { [bool]$_.browserKitty.published })

$usedCategoryIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($app in $publishedApps) {
    [void]$usedCategoryIds.Add([string]$app.category)
}

$publicCategories = @(
    foreach ($category in @($categoriesSource.categories)) {
        if (-not $usedCategoryIds.Contains([string]$category.id)) {
            continue
        }

        [ordered]@{
            id = [string]$category.id
            name = [string]$category.name
            nameJa = [string]$category.nameJa
        }
    }
)

$publicCategoryIds = @{}
foreach ($category in $publicCategories) {
    $publicCategoryIds[[string]$category.id] = $true
}

$publicApps = @(
    foreach ($app in $publishedApps) {
        $categoryId = [string]$app.category
        if (-not $publicCategoryIds.ContainsKey($categoryId)) {
            throw "Published app '$($app.id)' references a category that is not available in the public export: $categoryId"
        }

        $repository = [string]$app.repository
        $slug = [string]$app.browserKitty.slug
        if ([string]::IsNullOrWhiteSpace($slug)) {
            throw "Published app '$($app.id)' must have browserKitty.slug before it can be exported."
        }

        [ordered]@{
            id = [string]$app.id
            name = [string]$app.name
            nameJa = [string]$app.nameJa
            slug = $slug
            category = $categoryId
            status = [string]$app.status
            version = [string]$app.release.version
            appUrl = [string]$app.pages.url
            repository = $repository
            repositoryUrl = "https://github.com/$repository"
            runtime = [ordered]@{
                localProcessing = [bool]$app.runtime.localProcessing
                networkAccess = [bool]$app.runtime.networkAccess
                standalone = [bool]$app.runtime.standalone
                crossOriginIsolated = [bool]$app.runtime.crossOriginIsolated
                requiresWasm = [bool]$app.runtime.requiresWasm
                requiresWorker = [bool]$app.runtime.requiresWorker
                requiresWebGPU = [bool]$app.runtime.requiresWebGPU
                requiresWebCodecs = [bool]$app.runtime.requiresWebCodecs
            }
        }
    }
)

$export = [ordered]@{
    '$schema' = '../schema/public-apps.schema.json'
    schemaVersion = 1
    categories = $publicCategories
    apps = $publicApps
}

$json = $export | ConvertTo-Json -Depth 20
$json = ($json -replace "`r`n", "`n").TrimEnd() + "`n"

if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
    throw 'Generated public export does not match schema/public-apps.schema.json.'
}

if ($Check) {
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        Write-Error "Public export is missing: $OutputPath. Run ./scripts/generate-public-export.ps1 and commit the generated file."
        exit 1
    }

    $existingRaw = [System.IO.File]::ReadAllText($OutputPath, [System.Text.Encoding]::UTF8)
    if (-not (Test-Json -Json $existingRaw -SchemaFile $schemaPath)) {
        Write-Error "Committed public export does not match schema/public-apps.schema.json: $OutputPath"
        exit 1
    }

    $existingObject = $existingRaw | ConvertFrom-Json -Depth 100
    $expectedCompact = $export | ConvertTo-Json -Depth 20 -Compress
    $existingCompact = $existingObject | ConvertTo-Json -Depth 20 -Compress
    if ($existingCompact -cne $expectedCompact) {
        Write-Error "Public export is stale: $OutputPath. Run ./scripts/generate-public-export.ps1 and commit the result."
        exit 1
    }

    Write-Host "[OK] Public export is current: $OutputPath" -ForegroundColor Green
    Write-Host "[OK] Published apps: $($publicApps.Count)" -ForegroundColor Green
    Write-Host "[OK] Exported categories: $($publicCategories.Count)" -ForegroundColor Green
    exit 0
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

Write-Host "Public export written: $OutputPath" -ForegroundColor Green
Write-Host "Published apps: $($publicApps.Count)"
Write-Host "Exported categories: $($publicCategories.Count)"
