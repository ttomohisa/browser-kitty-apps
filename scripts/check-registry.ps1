#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$categoriesPath = Join-Path $RepositoryRoot 'categories.json'
$schemaPath = Join-Path $RepositoryRoot 'schema/apps.schema.json'

$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([Parameter(Mandatory)][string]$Message)
    $script:errors.Add($Message)
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file not found: $Path"
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

Write-Host 'Browser Kitty Apps Registry validation'
Write-Host "Repository: $RepositoryRoot"

$appsFile = Read-JsonFile -Path $appsPath
$categoriesFile = Read-JsonFile -Path $categoriesPath

if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
    try {
        if (-not (Test-Json -Json $appsFile.Raw -SchemaFile $schemaPath)) {
            Add-ValidationError 'apps.json does not match schema/apps.schema.json.'
        }
    }
    catch {
        Add-ValidationError "JSON Schema validation failed: $($_.Exception.Message)"
    }
}
else {
    Add-ValidationError 'schema/apps.schema.json is missing.'
}

$categoryIds = @{}
foreach ($category in @($categoriesFile.Value.categories)) {
    if ([string]::IsNullOrWhiteSpace([string]$category.id)) {
        Add-ValidationError 'categories.json contains a category without id.'
        continue
    }
    $id = [string]$category.id
    if ($categoryIds.ContainsKey($id)) {
        Add-ValidationError "Duplicate category id: $id"
    }
    else {
        $categoryIds[$id] = $true
    }
}

$appIds = @{}
$repositories = @{}
$semverPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'
$repoPattern = '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'

foreach ($app in @($appsFile.Value.apps)) {
    $id = [string]$app.id

    if ($appIds.ContainsKey($id)) {
        Add-ValidationError "Duplicate app id: $id"
    }
    else {
        $appIds[$id] = $true
    }

    $repository = [string]$app.repository
    if ($repository -notmatch $repoPattern) {
        Add-ValidationError "Invalid repository format for '$id': $repository"
    }
    elseif ($repositories.ContainsKey($repository)) {
        Add-ValidationError "Repository is registered more than once: $repository"
    }
    else {
        $repositories[$repository] = $id
    }

    $version = [string]$app.release.version
    if ($version -notmatch $semverPattern) {
        Add-ValidationError "Invalid Semantic Version for '$id': $version"
    }

    $category = [string]$app.category
    if (-not $categoryIds.ContainsKey($category)) {
        Add-ValidationError "Unknown category for '$id': $category"
    }

    $pagesUrl = [string]$app.pages.url
    $uri = $null
    if (-not [Uri]::TryCreate($pagesUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        Add-ValidationError "Invalid HTTPS Pages URL for '$id': $pagesUrl"
    }

    if ([bool]$app.browserKitty.published -and [string]::IsNullOrWhiteSpace([string]$app.browserKitty.slug)) {
        Add-ValidationError "Published app '$id' must have browserKitty.slug."
    }

    if ([bool]$app.runtime.standalone -and [string]::IsNullOrWhiteSpace([string]$app.runtime.standalonePath)) {
        Add-ValidationError "Standalone app '$id' must have runtime.standalonePath."
    }
    elseif (-not [bool]$app.runtime.standalone -and $null -ne $app.runtime.standalonePath) {
        Add-ValidationError "Non-standalone app '$id' must set runtime.standalonePath to null."
    }

    foreach ($capability in @('crossOriginIsolated', 'requiresWasm', 'requiresWorker', 'requiresWebGPU', 'requiresWebCodecs')) {
        if ($null -eq $app.runtime.PSObject.Properties[$capability]) {
            Add-ValidationError "Runtime capability '$capability' must be explicitly declared for '$id'."
        }
    }

    if ([bool]$app.runtime.crossOriginIsolated) {
        if ($null -eq $app.PSObject.Properties['hosting'] -or -not [bool]$app.hosting.crossOriginIsolated) {
            Add-ValidationError "crossOriginIsolated app '$id' must declare hosting.crossOriginIsolated=true."
        }
        else {
            $hostingHeaders = @($app.hosting.headers | ForEach-Object { [string]$_ })
            foreach ($requiredHeader in @('Cross-Origin-Opener-Policy', 'Cross-Origin-Embedder-Policy', 'Cross-Origin-Resource-Policy')) {
                if (-not ($hostingHeaders -contains $requiredHeader)) {
                    Add-ValidationError "crossOriginIsolated app '$id' is missing hosting header declaration: $requiredHeader"
                }
            }
        }
    }
    elseif ($null -ne $app.PSObject.Properties['hosting'] -and [bool]$app.hosting.crossOriginIsolated) {
        Add-ValidationError "hosting.crossOriginIsolated is true while runtime.crossOriginIsolated is false for '$id'."
    }
}

if ($errors.Count -gt 0) {
    Write-Host ''
    Write-Host "Validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($message in $errors) {
        Write-Host "  - $message" -ForegroundColor Red
    }
    exit 1
}

Write-Host ''
Write-Host '[OK] JSON syntax and schema' -ForegroundColor Green
Write-Host '[OK] App IDs and repository mappings are unique' -ForegroundColor Green
Write-Host '[OK] Categories, versions, Pages URLs, and runtime metadata' -ForegroundColor Green
Write-Host "[OK] Registered apps: $(@($appsFile.Value.apps).Count)" -ForegroundColor Green
Write-Host "[OK] Categories: $(@($categoriesFile.Value.categories).Count)" -ForegroundColor Green
