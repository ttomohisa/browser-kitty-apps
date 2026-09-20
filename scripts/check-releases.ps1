#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$InventoryPath='reports/repository-inventory.json',
    [string]$OutputPath='reports/repository-releases.json',
    [string]$GitHubToken=$env:BROWSER_KITTY_GITHUB_TOKEN,
    [string]$ApiBaseUrl='https://api.github.com',
    [switch]$NoWrite
)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){$p}else{Join-Path $RepositoryRoot $p}}
function New-Issue {param([ValidateSet('WARN','FAIL')][string]$Severity,[string]$Code,[string]$Message);[pscustomobject]@{severity=$Severity;code=$Code;message=$Message}}
function Normalize-VersionTag([AllowNull()][string]$Value){
    if([string]::IsNullOrWhiteSpace($Value)){return $null};$v=$Value.Trim();if($v.StartsWith('v',[StringComparison]::OrdinalIgnoreCase)){$v=$v.Substring(1)}
    if($v -match '^([0-9]+)\.([0-9]+)$'){return "$($Matches[1]).$($Matches[2]).0"};return $v
}
function Get-Text([string]$Uri,[int[]]$Allowed=@(200)){
    try{$r=Invoke-WebRequest -Uri $Uri -Method Get -SkipHttpErrorCheck -MaximumRedirection 5 -TimeoutSec 30}catch{return [pscustomobject]@{StatusCode=0;Content=$null;Error=$_.Exception.Message}}
    $s=[int]$r.StatusCode;$e=$null;if($Allowed -notcontains $s){$e="HTTP $s"};[pscustomobject]@{StatusCode=$s;Content=[string]$r.Content;Error=$e}
}
function Get-LatestReleaseTag([string]$Repository){
    $uri="https://github.com/$Repository/releases/latest"
    try{$r=Invoke-WebRequest -Uri $uri -Method Head -SkipHttpErrorCheck -MaximumRedirection 5 -TimeoutSec 20}catch{return [pscustomobject]@{Status='error';Tag=$null;Error=$_.Exception.Message}}
    $s=[int]$r.StatusCode
    if($s -eq 404){return [pscustomobject]@{Status='none';Tag=$null;Error=$null}}
    if($s -ne 200){return [pscustomobject]@{Status='error';Tag=$null;Error="HTTP $s"}}
    $final=[string]$r.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
    if($final -match '/releases/tag/([^/?#]+)'){return [pscustomobject]@{Status='ok';Tag=[Uri]::UnescapeDataString($Matches[1]);Error=$null}}
    return [pscustomobject]@{Status='none';Tag=$null;Error=$null}
}

$appsPath=Join-Path $RepositoryRoot 'apps.json';$schemaPath=Join-Path $RepositoryRoot 'schema/repository-releases.schema.json';$invPath=Abs $InventoryPath
foreach($p in @($appsPath,$schemaPath,$invPath)){if(-not(Test-Path $p -PathType Leaf)){throw "Required file not found: $p"}}
$apps=@((Get-Content $appsPath -Raw -Encoding UTF8|ConvertFrom-Json -Depth 100).apps);$inventory=Get-Content $invPath -Raw -Encoding UTF8|ConvertFrom-Json -Depth 100
$inventoryById=@{};foreach($e in @($inventory.repositories)){$inventoryById[[string]$e.appId]=$e}
Write-Host 'Browser Kitty release/version check';Write-Host "Registered apps: $($apps.Count)";Write-Host 'Release lookup: github.com redirect; tag lookup: git ls-remote';Write-Host ''
$results=[Collections.Generic.List[object]]::new();$pass=0;$warn=0;$fail=0;$lookupErrors=0
foreach($app in $apps){
 $id=[string]$app.id;$repo=[string]$app.repository;$registered=[string]$app.release.version;$issues=[Collections.Generic.List[object]]::new();Write-Host "Checking $repo ..." -NoNewline
 $defaultBranch=$null;$configStatus='error';$configVersion=$null;$outputs=@();$blockNet=$null;$matchConfig=$null;$releaseStatusLookup='error';$releaseTag=$null;$matchRelease=$null;$tagStatus='error';$tags=@();$matchingTag=$null;$err=$null
 if(-not $inventoryById.ContainsKey($id) -or [string]$inventoryById[$id].lookupStatus -ne 'ok' -or -not [bool]$inventoryById[$id].exists){$issues.Add((New-Issue FAIL 'repository_unavailable' 'Repository is unavailable according to inventory.'));$lookupErrors++;$err='Repository unavailable.'}
 else{
  $defaultBranch=[string]$inventoryById[$id].defaultBranch;$profile=if($null -ne $app.PSObject.Properties['repositoryProfile']){[string]$app.repositoryProfile}else{'standard'};$parts=$repo-split'/',2
  $configUri="https://raw.githubusercontent.com/$([Uri]::EscapeDataString($parts[0]))/$([Uri]::EscapeDataString($parts[1]))/refs/heads/$([Uri]::EscapeDataString($defaultBranch))/app.config.json"
  $cr=Get-Text $configUri @(200,404)
  if($cr.StatusCode -eq 200){
    try{$c=$cr.Content|ConvertFrom-Json -Depth 100;$configStatus='ok';$configVersion=[string]$c.version;$list=[Collections.Generic.List[string]]::new();if($null -ne $c.PSObject.Properties['build']){$b=$c.build;foreach($pn in @('output','multiThreadOutput')){if($null -ne $b.PSObject.Properties[$pn]){$v=[string]$b.$pn;if($v -and -not $list.Contains($v)){$list.Add($v)}}};if($null -ne $b.PSObject.Properties['selfExtract']-and$null -ne $b.selfExtract){foreach($pn in @('output','multiThreadOutput')){if($null -ne $b.selfExtract.PSObject.Properties[$pn]){$v=[string]$b.selfExtract.$pn;if($v -and -not $list.Contains($v)){$list.Add($v)}}}};if($null -ne $b.PSObject.Properties['blockRuntimeNetwork']){$blockNet=[bool]$b.blockRuntimeNetwork}};$outputs=@($list);$matchConfig=(Normalize-VersionTag $configVersion) -eq (Normalize-VersionTag $registered);if (-not $matchConfig){$issues.Add((New-Issue WARN 'app_config_version_mismatch' "Registry version '$registered' differs from app.config.json version '$configVersion'."))}}
    catch{$issues.Add((New-Issue FAIL 'app_config_invalid' "app.config.json could not be parsed: $($_.Exception.Message)"));$lookupErrors++}
  }elseif($cr.StatusCode -eq 404 -and $profile -eq 'legacy'){$configStatus='legacy-none';$issues.Add((New-Issue WARN 'legacy_app_config_missing' 'Legacy repository has no app.config.json; version comparison is skipped.'))}
  else{$issues.Add((New-Issue FAIL 'app_config_lookup_failed' "app.config.json lookup failed: $($cr.Error)"));$lookupErrors++}

  $lr=Get-LatestReleaseTag $repo;$releaseStatusLookup=$lr.Status;$releaseTag=$lr.Tag
  if($lr.Status -eq 'ok'){$matchRelease=(Normalize-VersionTag $releaseTag) -eq (Normalize-VersionTag $registered);if (-not $matchRelease){$issues.Add((New-Issue WARN 'release_version_mismatch' "Registry version '$registered' differs from latest GitHub Release tag '$releaseTag'."))}}
  elseif($lr.Status -eq 'error'){$issues.Add((New-Issue FAIL 'release_lookup_failed' "Latest Release lookup failed: $($lr.Error)"));$lookupErrors++}

  try{$gitOut=@(& git ls-remote --tags --refs "https://github.com/$repo.git" 2>$null);$gitCode=$LASTEXITCODE;if($gitCode -ne 0){throw "git ls-remote exited with code $gitCode"};$tags=@($gitOut|ForEach-Object{if($_ -match 'refs/tags/(.+)$'){$Matches[1]}}|Where-Object{$_});$tagStatus=if($tags.Count){'ok'}else{'none'};$matching=@($tags|Where-Object{(Normalize-VersionTag $_) -eq (Normalize-VersionTag $registered)}|Select-Object -First 1);if($matching.Count){$matchingTag=[string]$matching[0]}elseif($tags.Count){$issues.Add((New-Issue WARN 'registered_version_tag_missing' "Repository has tags, but none matches registry version '$registered'."))}}
  catch{$tagStatus='error';$issues.Add((New-Issue FAIL 'tag_lookup_failed' "Tag lookup failed: $($_.Exception.Message)"));$lookupErrors++}
 }
 $status=if(@($issues|Where-Object severity -eq 'FAIL').Count){'FAIL'}elseif(@($issues|Where-Object severity -eq 'WARN').Count){'WARN'}else{'PASS'};switch($status){'PASS'{$pass++;Write-Host ' PASS' -ForegroundColor Green};'WARN'{$warn++;Write-Host ' WARN' -ForegroundColor Yellow};'FAIL'{$fail++;Write-Host ' FAIL' -ForegroundColor Red}}
 $results.Add([pscustomobject][ordered]@{appId=$id;name=[string]$app.name;repository=$repo;registryStatus=[string]$app.status;registeredVersion=$registered;defaultBranch=$defaultBranch;releaseStatus=$status;appConfigLookupStatus=$configStatus;appConfigVersion=$configVersion;appConfigBuildOutputs=@($outputs);appConfigBlockRuntimeNetwork=$blockNet;registryMatchesAppConfig=$matchConfig;releaseLookupStatus=$releaseStatusLookup;latestReleaseTag=$releaseTag;registryMatchesRelease=$matchRelease;tagLookupStatus=$tagStatus;tagCount=$tags.Count;matchingVersionTag=$matchingTag;tags=@($tags);issues=@($issues);error=$err})
}
$report=[ordered]@{schemaVersion=1;generatedAt=[DateTimeOffset]::UtcNow.ToString('o');sourceRegistry='apps.json';sourceInventory=$InventoryPath;githubApi=$ApiBaseUrl;authenticated=-not [string]::IsNullOrWhiteSpace($GitHubToken);policy=[ordered]@{missingReleaseIsFailure=$false;missingTagsIsFailure=$false;versionMismatchSeverity='WARN';acceptedTagForms=@('<version>','v<version>')};summary=[ordered]@{registeredApps=$apps.Count;checkedApps=$results.Count;pass=$pass;warn=$warn;fail=$fail;lookupErrors=$lookupErrors};applications=@($results)}
$json=$report|ConvertTo-Json -Depth 30;if(-not(Test-Json -Json $json -SchemaFile $schemaPath)){throw 'Generated Release report does not match schema/repository-releases.schema.json.'}
if (-not $NoWrite){$out=Abs $OutputPath;New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out)|Out-Null;$json|Set-Content $out -Encoding utf8NoBOM;Write-Host "Release report written: $out"}
Write-Host "PASS: $pass`nWARN: $warn`nFAIL: $fail`nLookup errors: $lookupErrors";if ($fail -gt 0){exit 1}
