#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$fixtures = [ordered]@{
    'unversioned' = @{ config = @{ versionPolicy = 'unversioned' }; codes = @(); comparison = 'not-applicable'; match = $null }
    'aliases-without-primary' = @{ config = @{ version = '1.0.0' }; noPrimary = $true; aliases = @('catalog.html'); codes = @('app_config_invalid'); comparison = 'applicable'; match = $null }
    'output-aliases' = @{ config = @{ version = '1.0.0' }; aliases = @('catalog.html', 'app.html', 'catalog.html'); outputs = @('app.html', 'catalog.html'); codes = @(); comparison = 'applicable'; match = $true }
    'versioned' = @{ config = @{ version = '1.0.0' }; codes = @(); comparison = 'applicable'; match = $true }
    'version-mismatch' = @{ config = @{ version = '1.0.1' }; codes = @('app_config_version_mismatch'); comparison = 'applicable'; match = $false }
    'missing-version' = @{ config = @{}; codes = @('app_config_version_missing'); comparison = 'applicable'; match = $null }
    'empty-version' = @{ config = @{ version = '' }; codes = @('app_config_version_missing'); comparison = 'applicable'; match = $null }
    'null-version' = @{ config = @{ version = $null }; codes = @('app_config_version_missing'); comparison = 'applicable'; match = $null }
    'unversioned-with-version' = @{ config = @{ versionPolicy = 'unversioned'; version = '1.0.0' }; codes = @('app_config_invalid'); comparison = 'applicable'; match = $null }
    'unversioned-with-null' = @{ config = @{ versionPolicy = 'unversioned'; version = $null }; codes = @('app_config_invalid'); comparison = 'applicable'; match = $null }
    'unversioned-with-empty' = @{ config = @{ versionPolicy = 'unversioned'; version = '' }; codes = @('app_config_invalid'); comparison = 'applicable'; match = $null }
}
foreach ($invalid in @('UNVERSIONED', 'ignore', '', $null, $false, @('unversioned'))) {
    $fixtures["invalid-policy-$($fixtures.Count)"] = @{ config = @{ versionPolicy = $invalid }; codes = @('app_config_invalid'); comparison = 'applicable'; match = $null }
}
foreach ($invalid in @('catalog.html', @(''), @('valid.html', $null), @('valid.html', 3), $null)) {
    $fixtures["invalid-alias-$($fixtures.Count)"] = @{ config = @{ version = '1.0.0' }; aliases = $invalid; codes = @('app_config_invalid'); comparison = 'applicable'; match = $null }
}
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('browser-kitty-release-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'schema') -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../schema/repository-releases.schema.json') -Destination (Join-Path $tempRoot 'schema/repository-releases.schema.json')
    $apps = @(); $inventory = @(); $responses = @{}
    foreach ($id in $fixtures.Keys) {
        $fixture = $fixtures[$id]
        $apps += @{ id = $id; name = $id; repository = "fixture/$id"; status = 'maintenance'; release = @{ version = '1.0.0' } }
        $inventory += @{ appId = $id; exists = $true; lookupStatus = 'ok'; defaultBranch = 'main' }
        $config = $fixture.config.Clone()
        $config.build = @{ output = 'app.html'; blockRuntimeNetwork = $true }
        if ($fixture.ContainsKey('noPrimary')) { $config.build.Remove('output') }
        if ($fixture.ContainsKey('aliases')) { $config.build.aliases = $fixture.aliases }
        $responses["https://raw.githubusercontent.com/fixture/$id/refs/heads/main/app.config.json"] = [pscustomobject]@{ StatusCode = 200; Content = ($config | ConvertTo-Json -Depth 20) }
        $responses["https://github.com/fixture/$id/releases/latest"] = [pscustomobject]@{ StatusCode = 200; BaseResponse = @{ RequestMessage = @{ RequestUri = @{ AbsoluteUri = "https://github.com/fixture/$id/releases/tag/v1.0.0" } } } }
    }
    @{ apps = $apps } | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $tempRoot 'apps.json') -Encoding utf8NoBOM
    @{ repositories = $inventory } | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $tempRoot 'inventory.json') -Encoding utf8NoBOM
    function Invoke-WebRequest {
        param($Uri, $Method, [switch]$SkipHttpErrorCheck, $MaximumRedirection, $TimeoutSec)
        if (-not $responses.ContainsKey([string]$Uri)) { throw "Unexpected network request: $Uri" }
        return $responses[[string]$Uri]
    }
    function git {
        if ($args.Count -ne 4 -or $args[0] -ne 'ls-remote' -or $args[1] -ne '--tags' -or $args[2] -ne '--refs' -or $args[3] -notmatch '^https://github.com/fixture/[a-z0-9-]+\.git$') { throw "Unexpected git invocation: $args" }
        $global:LASTEXITCODE = 0
        # A tag cannot turn an explicit unversioned policy into a match against the legacy registry placeholder.
        return "0123456789012345678901234567890123456789`trefs/tags/v1.0.0"
    }
    & (Join-Path $PSScriptRoot 'check-releases.ps1') -RepositoryRoot $tempRoot -InventoryPath inventory.json -OutputPath releases.json -GitHubToken ''
    $report = Get-Content (Join-Path $tempRoot 'releases.json') -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
    if ($report.applications.Count -ne $fixtures.Count) { throw 'Release checker skipped fixture(s).' }
    foreach ($result in $report.applications) {
        $fixture = $fixtures[$result.appId]
        $codes = @($result.issues | ForEach-Object { $_.code } | Sort-Object)
        if (($codes -join ',') -cne (($fixture.codes | Sort-Object) -join ',')) { throw "$($result.appId): expected [$($fixture.codes -join ',')], got [$($codes -join ',')]." }
        if ($result.versionComparison -cne $fixture.comparison) { throw "$($result.appId): incorrect version-comparison applicability." }
        if ($result.registryMatchesAppConfig -ne $fixture.match) { throw "$($result.appId): incorrect app-config match state." }
        if ($fixture.ContainsKey('outputs') -and ($result.appConfigBuildOutputs -join ',') -cne ($fixture.outputs -join ',')) { throw 'Output aliases were lost or duplicated.' }
        if ($result.appId -eq 'unversioned') {
            if ($result.appConfigVersionPolicy -cne 'unversioned' -or $null -ne $result.appConfigVersion -or $null -ne $result.registryMatchesRelease -or $null -ne $result.matchingVersionTag) { throw 'Unversioned policy fabricated version/match evidence.' }
            if (($result.appConfigBuildOutputs -join ',') -cne 'app.html' -or -not $result.appConfigBlockRuntimeNetwork) { throw 'Unversioned policy skipped build/runtime metadata.' }
            if ($result.latestReleaseTag -cne 'v1.0.0' -or $result.tagCount -ne 1) { throw 'Unversioned policy hid release/tag evidence.' }
        }
        if ($codes -contains 'app_config_invalid' -and $result.appConfigLookupStatus -ne 'error') { throw 'Invalid app config must not be reported as usable.' }
    }
    Write-Host "[OK] Release version-policy regression passed for $($fixtures.Count) fixtures." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
