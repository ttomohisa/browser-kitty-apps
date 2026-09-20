#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InventoryPath = 'reports/repository-inventory.json',
    [string]$ReleasePath = 'reports/repository-releases.json',
    [string]$OutputPath = 'reports/repository-runtime.json',
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$appsPath = Join-Path $RepositoryRoot 'apps.json'
$schemaPath = Join-Path $RepositoryRoot 'schema/repository-runtime.schema.json'
$absoluteInventoryPath = if ([System.IO.Path]::IsPathRooted($InventoryPath)) { $InventoryPath } else { Join-Path $RepositoryRoot $InventoryPath }
$absoluteReleasePath = if ([System.IO.Path]::IsPathRooted($ReleasePath)) { $ReleasePath } else { Join-Path $RepositoryRoot $ReleasePath }

foreach ($requiredPath in @($appsPath, $schemaPath, $absoluteInventoryPath, $absoluteReleasePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$appsFile = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$apps = @($appsFile.apps)
$inventory = Get-Content -LiteralPath $absoluteInventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$releaseReport = Get-Content -LiteralPath $absoluteReleasePath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100

$inventoryByAppId = @{}
foreach ($entry in @($inventory.repositories)) {
    $inventoryByAppId[[string]$entry.appId] = $entry
}
$releaseByAppId = @{}
foreach ($entry in @($releaseReport.applications)) {
    $releaseByAppId[[string]$entry.appId] = $entry
}

function Invoke-TextGet {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int[]]$AllowedStatusCodes = @(200)
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Uri `
            -Method Get `
            -SkipHttpErrorCheck `
            -MaximumRedirection 5 `
            -TimeoutSec 30
    }
    catch {
        return [pscustomobject]@{ StatusCode = 0; Content = $null; Error = $_.Exception.Message }
    }

    $statusCode = [int]$response.StatusCode
    $errorMessage = $null
    if (-not ($AllowedStatusCodes -contains $statusCode)) {
        $errorMessage = "HTTP $statusCode"
    }
    return [pscustomobject]@{ StatusCode = $statusCode; Content = [string]$response.Content; Error = $errorMessage }
}

function Get-AbsoluteOutputPath {
    param([Parameter(Mandatory)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $RepositoryRoot $Path
}

function New-Issue {
    param(
        [Parameter(Mandatory)][ValidateSet('WARN', 'FAIL')][string]$Severity,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message
    )
    return [pscustomobject]@{ severity = $Severity; code = $Code; message = $Message }
}

$requiredIsolationHeaders = @(
    'Cross-Origin-Opener-Policy',
    'Cross-Origin-Embedder-Policy',
    'Cross-Origin-Resource-Policy'
)

Write-Host 'Browser Kitty standalone/runtime check'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Registered apps: $($apps.Count)"
Write-Host 'app.config source: reports/repository-releases.json'
Write-Host 'dependency manifest source: raw.githubusercontent.com'
Write-Host ''

$results = [System.Collections.Generic.List[object]]::new()
$passCount = 0
$warnCount = 0
$failCount = 0
$lookupErrorCount = 0

foreach ($app in $apps) {
    $appId = [string]$app.id
    $repository = [string]$app.repository
    Write-Host "Checking $repository ..." -NoNewline

    $issues = [System.Collections.Generic.List[object]]::new()
    $defaultBranch = $null
    $appConfigData = $null
    $dependenciesLookupStatus = 'none'
    $wasmAssets = [System.Collections.Generic.List[string]]::new()
    $workerAssets = [System.Collections.Generic.List[string]]::new()
    $errorMessage = $null

    $runtime = [ordered]@{
        standalone          = [bool]$app.runtime.standalone
        standalonePath      = if ($null -eq $app.runtime.standalonePath) { $null } else { [string]$app.runtime.standalonePath }
        localProcessing     = [bool]$app.runtime.localProcessing
        networkAccess       = [bool]$app.runtime.networkAccess
        crossOriginIsolated = [bool]$app.runtime.crossOriginIsolated
        requiresWasm        = [bool]$app.runtime.requiresWasm
        requiresWorker      = [bool]$app.runtime.requiresWorker
        requiresWebGPU      = [bool]$app.runtime.requiresWebGPU
        requiresWebCodecs   = [bool]$app.runtime.requiresWebCodecs
    }

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

            if (-not $releaseByAppId.ContainsKey($appId)) {
                $issues.Add((New-Issue -Severity FAIL -Code 'release_report_missing' -Message 'Application is missing from repository-releases.json.'))
                $errorMessage = 'Release report entry is missing.'
                $lookupErrorCount++
            }
            else {
                $releaseEntry = $releaseByAppId[$appId]
                if ([string]$releaseEntry.appConfigLookupStatus -eq 'legacy-none') {
                    $issues.Add((New-Issue -Severity WARN -Code 'legacy_app_config_unavailable' -Message 'Legacy repository has no app.config.json; build-output and runtime-network policy comparisons are skipped.'))
                    $appConfigData = $null
                }
                elseif ([string]$releaseEntry.appConfigLookupStatus -ne 'ok') {
                    $issues.Add((New-Issue -Severity FAIL -Code 'app_config_unavailable' -Message 'app.config.json was not available to the release/version check.'))
                    $errorMessage = 'app.config.json metadata is unavailable.'
                    $lookupErrorCount++
                }
                else {
                    $buildOutputs = @($releaseEntry.appConfigBuildOutputs | ForEach-Object { [string]$_ })
                    $blockRuntimeNetwork = if ($null -eq $releaseEntry.appConfigBlockRuntimeNetwork) { $null } else { [bool]$releaseEntry.appConfigBlockRuntimeNetwork }
                    $appConfigData = [ordered]@{
                        version             = if ($null -eq $releaseEntry.appConfigVersion) { $null } else { [string]$releaseEntry.appConfigVersion }
                        buildOutputs        = $buildOutputs
                        blockRuntimeNetwork = $blockRuntimeNetwork
                    }

                    if ($runtime.standalone) {
                        if ([string]::IsNullOrWhiteSpace([string]$runtime.standalonePath)) {
                            $issues.Add((New-Issue -Severity FAIL -Code 'standalone_path_missing' -Message 'runtime.standalone is true but standalonePath is empty.'))
                        }
                        elseif ($buildOutputs.Count -eq 0) {
                            $issues.Add((New-Issue -Severity WARN -Code 'build_output_unknown' -Message 'app.config.json does not expose a build output that can be compared with runtime.standalonePath.'))
                        }
                        elseif (-not ($buildOutputs -contains [string]$runtime.standalonePath)) {
                            $issues.Add((New-Issue -Severity FAIL -Code 'standalone_output_mismatch' -Message "runtime.standalonePath '$($runtime.standalonePath)' does not match any app.config.json build output: $($buildOutputs -join ', ')."))
                        }
                    }

                    if (-not $runtime.networkAccess) {
                        if ($null -eq $blockRuntimeNetwork) {
                            $issues.Add((New-Issue -Severity WARN -Code 'runtime_network_policy_unknown' -Message 'Registry says networkAccess=false, but app.config.json has no build.blockRuntimeNetwork value.'))
                        }
                        elseif (-not $blockRuntimeNetwork) {
                            $issues.Add((New-Issue -Severity FAIL -Code 'runtime_network_not_blocked' -Message 'Registry says networkAccess=false, but app.config.json build.blockRuntimeNetwork is false.'))
                        }
                    }
                    elseif ($null -ne $blockRuntimeNetwork -and $blockRuntimeNetwork) {
                        $issues.Add((New-Issue -Severity WARN -Code 'runtime_network_declaration_mismatch' -Message 'Registry says networkAccess=true, but app.config.json blocks runtime network access.'))
                    }
                }
            }

            $repositoryParts = $repository -split '/', 2
            $ownerSegment = [Uri]::EscapeDataString([string]$repositoryParts[0])
            $repoSegment = [Uri]::EscapeDataString([string]$repositoryParts[1])
            $encodedBranch = [Uri]::EscapeDataString($defaultBranch)
            $dependenciesUri = "https://raw.githubusercontent.com/$ownerSegment/$repoSegment/refs/heads/$encodedBranch/dependencies.json"
            $dependenciesResponse = Invoke-TextGet -Uri $dependenciesUri -AllowedStatusCodes @(200, 404)

            if ($dependenciesResponse.StatusCode -eq 404) {
                $dependenciesLookupStatus = 'none'
            }
            elseif ($dependenciesResponse.StatusCode -eq 200) {
                try {
                    $dependencies = $dependenciesResponse.Content | ConvertFrom-Json -Depth 100
                    $dependenciesLookupStatus = 'ok'
                    foreach ($dependency in @($dependencies.dependencies)) {
                        foreach ($asset in @($dependency.assets)) {
                            $path = if ($null -eq $asset.PSObject.Properties['path']) { '' } else { [string]$asset.path }
                            $key = if ($null -eq $asset.PSObject.Properties['key']) { '' } else { [string]$asset.key }
                            $mime = if ($null -eq $asset.PSObject.Properties['mime']) { '' } else { [string]$asset.mime }
                            if ($mime -eq 'application/wasm' -or $path -match '(?i)\.wasm$') {
                                if (-not [string]::IsNullOrWhiteSpace($path) -and -not $wasmAssets.Contains($path)) { $wasmAssets.Add($path) }
                            }
                            if ($key -match '(?i)worker' -or $path -match '(?i)worker') {
                                $workerEvidence = if ([string]::IsNullOrWhiteSpace($path)) { $key } else { $path }
                                if (-not [string]::IsNullOrWhiteSpace($workerEvidence) -and -not $workerAssets.Contains($workerEvidence)) { $workerAssets.Add($workerEvidence) }
                            }
                        }
                    }

                    if ($wasmAssets.Count -gt 0 -and -not $runtime.requiresWasm) {
                        $issues.Add((New-Issue -Severity WARN -Code 'wasm_dependency_not_declared' -Message "dependencies.json contains WebAssembly asset(s), but requiresWasm=false: $($wasmAssets -join ', ')."))
                    }
                    if ($workerAssets.Count -gt 0 -and -not $runtime.requiresWorker) {
                        $issues.Add((New-Issue -Severity WARN -Code 'worker_dependency_not_declared' -Message "dependencies.json contains worker asset(s), but requiresWorker=false: $($workerAssets -join ', ')."))
                    }
                }
                catch {
                    $dependenciesLookupStatus = 'error'
                    $issues.Add((New-Issue -Severity FAIL -Code 'dependencies_invalid' -Message "dependencies.json could not be parsed: $($_.Exception.Message)"))
                    $lookupErrorCount++
                }
            }
            else {
                $dependenciesLookupStatus = 'error'
                $message = if ([string]::IsNullOrWhiteSpace([string]$dependenciesResponse.Error)) { 'dependencies.json lookup failed.' } else { [string]$dependenciesResponse.Error }
                $issues.Add((New-Issue -Severity FAIL -Code 'dependencies_lookup_failed' -Message $message))
                $lookupErrorCount++
            }
        }
    }

    if ($runtime.crossOriginIsolated) {
        if ($null -eq $app.PSObject.Properties['hosting'] -or -not [bool]$app.hosting.crossOriginIsolated) {
            $issues.Add((New-Issue -Severity FAIL -Code 'isolation_hosting_missing' -Message 'crossOriginIsolated=true requires hosting.crossOriginIsolated=true.'))
        }
        else {
            $declaredHeaders = @($app.hosting.headers | ForEach-Object { [string]$_ })
            foreach ($requiredHeader in $requiredIsolationHeaders) {
                if (-not ($declaredHeaders -contains $requiredHeader)) {
                    $issues.Add((New-Issue -Severity FAIL -Code 'isolation_header_missing' -Message "cross-origin isolation requires hosting header declaration '$requiredHeader'."))
                }
            }
        }
    }
    elseif ($null -ne $app.PSObject.Properties['hosting'] -and [bool]$app.hosting.crossOriginIsolated) {
        $issues.Add((New-Issue -Severity FAIL -Code 'isolation_registry_mismatch' -Message 'hosting.crossOriginIsolated=true but runtime.crossOriginIsolated=false.'))
    }

    $runtimeStatus = 'PASS'
    if (@($issues | Where-Object { $_.severity -eq 'FAIL' }).Count -gt 0) { $runtimeStatus = 'FAIL' }
    elseif (@($issues | Where-Object { $_.severity -eq 'WARN' }).Count -gt 0) { $runtimeStatus = 'WARN' }

    switch ($runtimeStatus) {
        'PASS' { $passCount++; Write-Host ' PASS' -ForegroundColor Green }
        'WARN' { $warnCount++; Write-Host " WARN ($($issues.Count) issue(s))" -ForegroundColor Yellow }
        'FAIL' { $failCount++; Write-Host " FAIL ($($issues.Count) issue(s))" -ForegroundColor Red }
    }

    $results.Add([pscustomobject][ordered]@{
        appId         = $appId
        name          = [string]$app.name
        repository    = $repository
        runtimeStatus = $runtimeStatus
        defaultBranch = $defaultBranch
        runtime       = [pscustomobject]$runtime
        appConfig     = if ($null -eq $appConfigData) { $null } else { [pscustomobject]$appConfigData }
        evidence      = [pscustomobject][ordered]@{
            dependenciesLookupStatus = $dependenciesLookupStatus
            wasmAssets               = @($wasmAssets)
            workerAssets             = @($workerAssets)
        }
        issues        = @($issues)
        error         = $errorMessage
    })
}

$report = [ordered]@{
    schemaVersion   = 1
    generatedAt     = [DateTimeOffset]::UtcNow.ToString('o')
    sourceRegistry  = 'apps.json'
    sourceInventory = ($InventoryPath -replace '\\', '/')
    sourceReleases  = ($ReleasePath -replace '\\', '/')
    githubApi       = [string]$releaseReport.githubApi
    authenticated   = [bool]$releaseReport.authenticated
    policy          = [ordered]@{
        explicitCapabilityFlags = $true
        requiredIsolationHeaders = $requiredIsolationHeaders
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

$reportJson = $report | ConvertTo-Json -Depth 30
if (-not (Test-Json -Json $reportJson -SchemaFile $schemaPath)) {
    throw 'Generated runtime report does not match schema/repository-runtime.schema.json.'
}

if (-not $NoWrite) {
    $absoluteOutputPath = Get-AbsoluteOutputPath -Path $OutputPath
    $outputDirectory = Split-Path -Parent $absoluteOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $reportJson | Set-Content -LiteralPath $absoluteOutputPath -Encoding utf8NoBOM
    Write-Host ''
    Write-Host "Runtime report written: $absoluteOutputPath"
}

Write-Host ''
Write-Host "PASS: $passCount"
Write-Host "WARN: $warnCount"
Write-Host "FAIL: $failCount"
Write-Host "Lookup errors: $lookupErrorCount"

if ($failCount -gt 0) { exit 1 }
