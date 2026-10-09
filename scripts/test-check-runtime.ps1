#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Only the HTTP boundary is replaced. Run the actual checker and its report schema.
$fixtures = [ordered]@{
    'main-thread-pdfjs' = @{ assets = @(@{ key = 'worker'; path = 'build/pdf.worker.min.mjs'; executionContext = 'main-thread' }); workers = @(); mainThread = @('build/pdf.worker.min.mjs'); codes = @() }
    'unannotated-worker' = @{ assets = @(@{ key = 'worker'; path = 'build/pdf.worker.min.mjs' }); workers = @('build/pdf.worker.min.mjs'); mainThread = @(); codes = @('worker_dependency_not_declared') }
    'explicit-worker' = @{ assets = @(@{ key = 'worker'; path = 'build/pdf.worker.min.mjs'; executionContext = 'worker' }); workers = @('build/pdf.worker.min.mjs'); mainThread = @(); codes = @('worker_dependency_not_declared') }
    'neutral-named-worker' = @{ assets = @(@{ key = 'engine'; path = 'engine.mjs'; executionContext = 'worker' }); workers = @('engine.mjs'); mainThread = @(); codes = @('worker_dependency_not_declared') }
    'mixed-contexts' = @{ assets = @(@{ key = 'worker'; path = 'pdf.worker.mjs'; executionContext = 'main-thread' }, @{ key = 'engine'; path = 'engine.mjs'; executionContext = 'worker' }); workers = @('engine.mjs'); mainThread = @('pdf.worker.mjs'); codes = @('worker_dependency_not_declared') }
    'main-thread-wasm' = @{ assets = @(@{ key = 'worker'; path = 'engine.worker.wasm'; executionContext = 'main-thread' }); workers = @(); mainThread = @('engine.worker.wasm'); codes = @('wasm_dependency_not_declared') }
    'declared-worker' = @{ assets = @(@{ key = 'worker'; path = 'actual.worker.js' }); requiresWorker = $true; workers = @('actual.worker.js'); mainThread = @(); codes = @() }
    'single-asset' = @{ layout = 'asset'; assets = @(@{ key = 'worker'; path = 'pdf.worker.mjs'; executionContext = 'main-thread' }); workers = @(); mainThread = @('pdf.worker.mjs'); codes = @() }
    'files-aliases' = @{ layout = 'files'; assets = @(@{ id = 'worker'; file = 'pdf.worker.mjs'; executionContext = 'main-thread' }); workers = @(); mainThread = @('pdf.worker.mjs'); codes = @() }
    'worker-without-identity' = @{ assets = @(@{ executionContext = 'worker' }); workers = @(); mainThread = @(); codes = @('dependencies_invalid') }
    'key-only' = @{ assets = @(@{ key = 'background'; executionContext = 'worker' }); workers = @('background'); mainThread = @(); codes = @('worker_dependency_not_declared') }
    'duplicate-evidence' = @{ assets = @(@{ key = 'worker'; path = 'worker.js' }, @{ key = 'worker'; path = 'worker.js' }); workers = @('worker.js'); mainThread = @(); codes = @('worker_dependency_not_declared') }
    'dependency-context-not-inherited' = @{ dependencyContext = 'main-thread'; assets = @(@{ key = 'worker'; path = 'worker.js' }); workers = @('worker.js'); mainThread = @(); codes = @('worker_dependency_not_declared') }
    'no-assets' = @{ assets = @(); workers = @(); mainThread = @(); codes = @() }
    'no-manifest' = @{ absent = $true; assets = @(); workers = @(); mainThread = @(); codes = @() }
}
foreach ($invalid in @('', 'main', 'MAIN-THREAD', 'worker,main-thread', $null, $false, @('main-thread'), @{ value = 'main-thread' })) {
    $fixtures["invalid-context-$($fixtures.Count)"] = @{ assets = @(@{ key = 'worker'; path = 'worker.js'; executionContext = $invalid }); workers = @(); mainThread = @(); codes = @('dependencies_invalid') }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('browser-kitty-runtime-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'schema') -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../schema/repository-runtime.schema.json') -Destination (Join-Path $tempRoot 'schema/repository-runtime.schema.json')
    $apps = @()
    $inventory = @()
    $releases = @()
    $responses = @{}
    foreach ($id in $fixtures.Keys) {
        $fixture = $fixtures[$id]
        $apps += @{ id = $id; name = $id; repository = "fixture/$id"; runtime = @{ standalone = $true; standalonePath = 'dist/index.html'; localProcessing = $true; networkAccess = $false; crossOriginIsolated = $false; requiresWasm = $false; requiresWorker = ($fixture.ContainsKey('requiresWorker') -and [bool]$fixture.requiresWorker); requiresWebGPU = $false; requiresWebCodecs = $false } }
        $inventory += @{ appId = $id; lookupStatus = 'ok'; exists = $true; defaultBranch = 'main' }
        $releases += @{ appId = $id; appConfigLookupStatus = 'ok'; appConfigVersion = '1.0.0'; appConfigBuildOutputs = @('dist/index.html'); appConfigBlockRuntimeNetwork = $true }
        $layout = if ($fixture.ContainsKey('layout')) { $fixture.layout } else { 'assets' }
        $dependency = @{ id = 'engine' }
        $dependency[$layout] = if ($layout -eq 'asset') { $fixture.assets[0] } else { @($fixture.assets) }
        if ($fixture.ContainsKey('dependencyContext')) { $dependency.executionContext = $fixture.dependencyContext }
        $responses["https://raw.githubusercontent.com/fixture/$id/refs/heads/main/dependencies.json"] = [pscustomobject]@{
            StatusCode = if ($fixture.ContainsKey('absent') -and $fixture.absent) { 404 } else { 200 }
            Content = (@{ dependencies = @($dependency) } | ConvertTo-Json -Depth 20)
        }
    }
    @{ apps = $apps } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $tempRoot 'apps.json') -Encoding utf8NoBOM
    @{ repositories = $inventory } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $tempRoot 'inventory.json') -Encoding utf8NoBOM
    @{ githubApi = 'https://api.github.com'; authenticated = $false; applications = $releases } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $tempRoot 'releases.json') -Encoding utf8NoBOM

    function Invoke-WebRequest {
        param($Uri, $Method, [switch]$SkipHttpErrorCheck, $MaximumRedirection, $TimeoutSec)
        if (-not $responses.ContainsKey([string]$Uri)) { throw "Unexpected network request: $Uri" }
        return $responses[[string]$Uri]
    }
    & (Join-Path $PSScriptRoot 'check-runtime.ps1') -RepositoryRoot $tempRoot -InventoryPath inventory.json -ReleasePath releases.json -OutputPath runtime.json
    # Invalid-annotation fixtures deliberately make the checker return exit 1.
    $report = Get-Content -LiteralPath (Join-Path $tempRoot 'runtime.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
    if ($report.repositories.Count -ne $fixtures.Count) { throw 'Runtime checker skipped fixture(s).' }
    foreach ($result in $report.repositories) {
        $fixture = $fixtures[$result.appId]
        $actualCodes = @($result.issues | ForEach-Object { $_.code } | Sort-Object)
        $expectedCodes = @($fixture.codes | Sort-Object)
        if (($actualCodes -join ',') -cne ($expectedCodes -join ',')) { throw "$($result.appId): expected issues [$($expectedCodes -join ',')], got [$($actualCodes -join ',')]." }
        $expectedStatus = if ($expectedCodes -contains 'dependencies_invalid') { 'FAIL' } elseif ($expectedCodes.Count) { 'WARN' } else { 'PASS' }
        if ($result.runtimeStatus -cne $expectedStatus) { throw "$($result.appId): expected $expectedStatus, got $($result.runtimeStatus)." }
        if (($result.evidence.workerAssets -join ',') -cne ($fixture.workers -join ',')) { throw "$($result.appId): incorrect Worker evidence." }
        if (($result.evidence.mainThreadAssets -join ',') -cne ($fixture.mainThread -join ',')) { throw "$($result.appId): incorrect main-thread evidence." }
    }
    Write-Host "[OK] Runtime execution-context regression passed for $($fixtures.Count) fixtures." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
