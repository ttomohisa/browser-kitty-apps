#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InventoryPath = 'reports/repository-inventory.json',
    [string]$OutputPath = 'reports/repository-quality.json',
    [string]$GitHubToken = $env:BROWSER_KITTY_GITHUB_TOKEN,
    [string]$ApiBaseUrl = 'https://api.github.com',
    [int]$ThrottleLimit = 16,
    [switch]$NoWrite
)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
function Get-AbsolutePath { param([Parameter(Mandatory)][string]$Path); if ([IO.Path]::IsPathRooted($Path)) {$Path} else {Join-Path $RepositoryRoot $Path} }
function New-Issue { param([Parameter(Mandatory)][ValidateSet('WARN','FAIL')][string]$Severity,[Parameter(Mandatory)][string]$Code,[Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Message); [pscustomobject]@{severity=$Severity;code=$Code;path=$Path;message=$Message} }

$appsPath=Join-Path $RepositoryRoot 'apps.json'; $schemaPath=Join-Path $RepositoryRoot 'schema/repository-quality.schema.json'; $inventoryAbs=Get-AbsolutePath $InventoryPath
foreach($p in @($appsPath,$schemaPath,$inventoryAbs)){ if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Required file not found: $p"} }
$apps=@((Get-Content $appsPath -Raw -Encoding UTF8|ConvertFrom-Json -Depth 100).apps)
$inventory=Get-Content $inventoryAbs -Raw -Encoding UTF8|ConvertFrom-Json -Depth 100
$inventoryById=@{}; foreach($e in @($inventory.repositories)){$inventoryById[[string]$e.appId]=$e}

$paths=@('README.md','LICENSE','app.config.json','package.json','assets/favicon.svg','assets/screenshot.png','assets/screenshot-en.png')
$targets=[Collections.Generic.List[object]]::new()
foreach($app in $apps){
    $id=[string]$app.id
    if($inventoryById.ContainsKey($id) -and [string]$inventoryById[$id].lookupStatus -eq 'ok' -and [bool]$inventoryById[$id].exists){
        $branch=[string]$inventoryById[$id].defaultBranch; $repo=[string]$app.repository; $parts=$repo -split '/',2
        foreach($path in $paths){
            $segments=$path -split '/' | ForEach-Object {[Uri]::EscapeDataString($_)}
            $url="https://raw.githubusercontent.com/$([Uri]::EscapeDataString($parts[0]))/$([Uri]::EscapeDataString($parts[1]))/refs/heads/$([Uri]::EscapeDataString($branch))/$($segments -join '/')"
            $targets.Add([pscustomobject]@{appId=$id;path=$path;url=$url})
        }
    }
}
Write-Host 'Browser Kitty repository quality check'
Write-Host "Registered apps: $($apps.Count)"
Write-Host "File probes: $($targets.Count) (raw.githubusercontent.com, throttle=$ThrottleLimit)"

$probes=@($targets | ForEach-Object -Parallel {
    $t=$_
    try {
        $r=Invoke-WebRequest -Uri $t.url -Method Head -SkipHttpErrorCheck -MaximumRedirection 3 -TimeoutSec 20
        [pscustomobject]@{appId=$t.appId;path=$t.path;status=[int]$r.StatusCode;error=$null}
    } catch {
        [pscustomobject]@{appId=$t.appId;path=$t.path;status=0;error=$_.Exception.Message}
    }
} -ThrottleLimit $ThrottleLimit)
$probeMap=@{}; foreach($p in $probes){$probeMap["$($p.appId)|$($p.path)"]=$p}

$results=[Collections.Generic.List[object]]::new(); $pass=0;$warn=0;$fail=0;$lookupErrors=0
foreach($app in $apps){
    $id=[string]$app.id; $repo=[string]$app.repository; Write-Host "Checking $repo ..." -NoNewline
    if(-not $inventoryById.ContainsKey($id) -or [string]$inventoryById[$id].lookupStatus -ne 'ok' -or -not [bool]$inventoryById[$id].exists){
        $results.Add([pscustomobject][ordered]@{appId=$id;name=[string]$app.name;repository=$repo;registryStatus=[string]$app.status;published=[bool]$app.browserKitty.published;lookupStatus='error';qualityStatus='FAIL';defaultBranch=$null;treeTruncated=$false;files=$null;issues=@(New-Issue FAIL 'repository_unavailable' $repo 'Repository is unavailable according to the inventory.');error='Repository unavailable.'})
        $fail++;$lookupErrors++;Write-Host ' FAIL' -ForegroundColor Red;continue
    }
    $files=[ordered]@{readme=$false;license=$false;appConfig=$false;packageJson=$false;favicon=$false;screenshot=$false;screenshotEn=$false}
    $mapping=@{'README.md'='readme';'LICENSE'='license';'app.config.json'='appConfig';'package.json'='packageJson';'assets/favicon.svg'='favicon';'assets/screenshot.png'='screenshot';'assets/screenshot-en.png'='screenshotEn'}
    $issues=[Collections.Generic.List[object]]::new()
    foreach($path in $paths){
        $probe=$probeMap["$id|$path"]
        if($null -eq $probe -or $probe.status -eq 0){
            $probeError = if ($null -eq $probe) { 'Probe result missing.' } else { [string]$probe.error }
            $issues.Add((New-Issue FAIL 'asset_probe_failed' $path "Could not check file presence: $probeError")); continue
        }
        $files[$mapping[$path]]=($probe.status -eq 200)
        if($probe.status -notin @(200,404)){ $issues.Add((New-Issue FAIL 'asset_probe_http_error' $path "Unexpected HTTP status $($probe.status) while checking file presence.")) }
    }
    foreach($required in @(
      @{Key='readme';Path='README.md';Code='readme_missing';Message='README.md is required.'},
      @{Key='license';Path='LICENSE';Code='license_missing';Message='LICENSE is required.'},
      @{Key='favicon';Path='assets/favicon.svg';Code='favicon_missing';Message='assets/favicon.svg is required.'}
    )){ if(-not [bool]$files[$required.Key]){$issues.Add((New-Issue FAIL $required.Code $required.Path $required.Message))} }
    $profile=if($null -ne $app.PSObject.Properties['repositoryProfile']){[string]$app.repositoryProfile}else{'standard'}
    if(-not [bool]$files.appConfig){
        if($profile -eq 'legacy'){$issues.Add((New-Issue WARN 'legacy_app_config_missing' 'app.config.json' 'Legacy repository has no app.config.json; this is recorded as an expected migration gap.'))}
        else{$issues.Add((New-Issue FAIL 'app_config_missing' 'app.config.json' 'app.config.json is required for standard Browser Kitty apps.'))}
    }
    $isPublishedRelease=[bool]$app.browserKitty.published -and ([string]$app.status -in @('stable','maintenance'))
    foreach($s in @(
      @{Key='screenshot';Path='assets/screenshot.png';Code='screenshot_missing';Message='Japanese/default screenshot is missing.'},
      @{Key='screenshotEn';Path='assets/screenshot-en.png';Code='screenshot_en_missing';Message='English screenshot is missing.'}
    )){ if(-not [bool]$files[$s.Key]){ $sev=if($isPublishedRelease){'FAIL'}else{'WARN'}; $issues.Add((New-Issue $sev $s.Code $s.Path $s.Message)) } }
    $status=if(@($issues|Where-Object severity -eq 'FAIL').Count){'FAIL'}elseif(@($issues|Where-Object severity -eq 'WARN').Count){'WARN'}else{'PASS'}
    switch($status){'PASS'{$pass++;Write-Host ' PASS' -ForegroundColor Green};'WARN'{$warn++;Write-Host ' WARN' -ForegroundColor Yellow};'FAIL'{$fail++;Write-Host ' FAIL' -ForegroundColor Red}}
    $results.Add([pscustomobject][ordered]@{appId=$id;name=[string]$app.name;repository=$repo;registryStatus=[string]$app.status;published=[bool]$app.browserKitty.published;lookupStatus='ok';qualityStatus=$status;defaultBranch=[string]$inventoryById[$id].defaultBranch;treeTruncated=$false;files=$files;issues=@($issues);error=$null})
}
$report=[ordered]@{schemaVersion=1;generatedAt=[DateTimeOffset]::UtcNow.ToString('o');sourceRegistry='apps.json';sourceInventory=($InventoryPath-replace '\\','/');githubApi=$ApiBaseUrl;authenticated=-not [string]::IsNullOrWhiteSpace($GitHubToken);policy=[ordered]@{requiredCoreFiles=@('README.md','LICENSE','app.config.json','assets/favicon.svg');releaseScreenshotFiles=@('assets/screenshot.png','assets/screenshot-en.png');packageJsonRequired=$false;legacyAppConfigOptional=$true};summary=[ordered]@{registeredApps=$apps.Count;checkedApps=$results.Count;pass=$pass;warn=$warn;fail=$fail;lookupErrors=$lookupErrors};repositories=@($results)}
$json=$report|ConvertTo-Json -Depth 30
if(-not(Test-Json -Json $json -SchemaFile $schemaPath)){throw 'Generated repository quality report does not match schema/repository-quality.schema.json.'}
if(-not $NoWrite){$out=Get-AbsolutePath $OutputPath;New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out)|Out-Null;$json|Set-Content $out -Encoding utf8NoBOM;Write-Host "Quality report written: $out"}
Write-Host "PASS: $pass`nWARN: $warn`nFAIL: $fail`nLookup errors: $lookupErrors"
if($fail -gt 0){exit 1}
