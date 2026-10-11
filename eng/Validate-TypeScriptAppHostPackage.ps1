#requires -Version 7.4
param(
    [string] $Configuration = "Release",
    [string] $PackageVersion = "9999.0.0",
    [string] $DependencyFeed,
    [switch] $RequirePublishedDependency
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
if ($PackageVersion -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?(?:\+[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?$') {
    throw "PackageVersion must be a NuGet semantic version."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$solutionPath = Join-Path $repoRoot "Aspire.Hosting.Railway.Jobs.slnx"
$fixtureSource = Join-Path $repoRoot "tests/Aspire.Hosting.Railway.Jobs/Fixtures/TypeScriptAppHost"
$artifactsRoot = Join-Path $repoRoot "artifacts/typescript-apphost-package"
$packageOutput = Join-Path $artifactsRoot "packages"
$fixtureWork = Join-Path $artifactsRoot "fixture"
$nugetPackages = Join-Path $artifactsRoot (".nuget-packages-" + [guid]::NewGuid().ToString('N'))
$packageId = "PinguApps.Aspire.Hosting.Railway.Jobs"

if ($RequirePublishedDependency -and -not [string]::IsNullOrWhiteSpace($DependencyFeed)) {
    throw "Release publication must use the official NuGet dependency, not a substitute feed."
}
$dependencyFeedFullPath = if ([string]::IsNullOrWhiteSpace($DependencyFeed)) { $null } else { (Resolve-Path $DependencyFeed).Path }
$allowedArtifacts = [IO.Path]::GetFullPath((Join-Path $repoRoot "artifacts")) + [IO.Path]::DirectorySeparatorChar
if (-not ([IO.Path]::GetFullPath($artifactsRoot)).StartsWith($allowedArtifacts, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Package gate output must remain inside repository artifacts."
}

foreach ($output in @($packageOutput, $fixtureWork)) {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
}
New-Item $packageOutput -ItemType Directory -Force | Out-Null
New-Item $nugetPackages -ItemType Directory -Force | Out-Null

$restoreConfig = Join-Path $artifactsRoot "NuGet.restore.Config"
$dependencySource = if ($dependencyFeedFullPath) {
    '<add key="railway-dependency" value="' + [Security.SecurityElement]::Escape($dependencyFeedFullPath) + '" />'
} else { '' }
$dependencyMapping = if ($dependencyFeedFullPath) {
    '<packageSource key="railway-dependency"><package pattern="PinguApps.Aspire.Hosting.Railway" /></packageSource>'
} else { '' }
@"
<configuration>
  <packageSources>
    <clear />
    $dependencySource
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    $dependencyMapping
    <packageSource key="nuget.org"><package pattern="*" /></packageSource>
  </packageSourceMapping>
</configuration>
"@ | Set-Content $restoreConfig
$previousNuGetPackages = $env:NUGET_PACKAGES
$env:NUGET_PACKAGES = $nugetPackages
try {
dotnet restore $solutionPath --configfile $restoreConfig --disable-build-servers
if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed." }
dotnet build $solutionPath -c $Configuration --no-restore --no-incremental --disable-build-servers -p:ContinuousIntegrationBuild=true
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed." }
dotnet pack $solutionPath -c $Configuration --no-build --disable-build-servers -p:Version=$PackageVersion -o $packageOutput
if ($LASTEXITCODE -ne 0) { throw "dotnet pack failed." }

$packageFile = Join-Path $packageOutput "$packageId.$PackageVersion.nupkg"
$packageCacheId = $packageId.ToLowerInvariant()
$packageCachePath = Join-Path $nugetPackages "$packageCacheId/$PackageVersion"

Remove-Item $packageCachePath -Recurse -Force -ErrorAction SilentlyContinue
New-Item $packageCachePath -ItemType Directory -Force | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($packageFile, $packageCachePath)
Copy-Item $packageFile (Join-Path $packageCachePath "$packageCacheId.$PackageVersion.nupkg")

$packageBytes = [IO.File]::ReadAllBytes($packageFile)
$packageHash = [Convert]::ToBase64String([System.Security.Cryptography.SHA512]::HashData($packageBytes))

Set-Content (Join-Path $packageCachePath "$packageCacheId.$PackageVersion.nupkg.sha512") $packageHash -Encoding ASCII

[ordered]@{
    version = 2
    contentHash = $packageHash
    source = (Resolve-Path $packageOutput).Path
} | ConvertTo-Json | Set-Content (Join-Path $packageCachePath ".nupkg.metadata") -Encoding UTF8

# Inspect the dependency restored into this same fresh cache before exercising the packed consumer.
[xml]$centralVersions = Get-Content (Join-Path $repoRoot "Directory.Packages.props") -Raw
$coreVersion = ($centralVersions.Project.ItemGroup.PackageVersion | Where-Object Include -eq "PinguApps.Aspire.Hosting.Railway").Version
if ($coreVersion -notmatch '^\d+\.\d+\.\d+$') { throw "The core dependency must have an exact stable version." }
$coreId = "pinguapps.aspire.hosting.railway"
$coreCache = Join-Path $nugetPackages "$coreId/$coreVersion"
$coreFile = Join-Path $coreCache "$coreId.$coreVersion.nupkg"
$coreHash = [Convert]::ToBase64String([Security.Cryptography.SHA512]::HashData([IO.File]::ReadAllBytes($coreFile)))
$coreMetadata = Get-Content (Join-Path $coreCache '.nupkg.metadata') -Raw | ConvertFrom-Json
if (-not $dependencyFeedFullPath -and $coreMetadata.source -cne 'https://api.nuget.org/v3/index.json') {
    throw 'The default package gate must restore core from official NuGet.org.'
}
$coreAssembly = Join-Path $coreCache "lib/net10.0/PinguApps.Aspire.Hosting.Railway.dll"
$jobsAssembly = Join-Path $packageCachePath "lib/net10.0/PinguApps.Aspire.Hosting.Railway.Jobs.dll"
$binding = & (Join-Path $PSScriptRoot 'Assert-RailwayAssemblyBinding.ps1') -JobsAssembly $jobsAssembly -CoreAssembly $coreAssembly
[ordered]@{ dependencySource = $(if ($dependencyFeedFullPath) { $dependencyFeedFullPath } else { 'https://api.nuget.org/v3/index.json' });
    dependencyVersion = $coreVersion; dependencySha512 = $coreHash; coreAssembly = $binding;
    coreAssemblySha256 = (Get-FileHash -LiteralPath $coreAssembly -Algorithm SHA256).Hash;
    jobsPackageSha256 = (Get-FileHash -LiteralPath $packageFile -Algorithm SHA256).Hash;
    packageVersion = $PackageVersion } |
    ConvertTo-Json | Set-Content (Join-Path $artifactsRoot 'dependency-binding.json') -Encoding UTF8

Copy-Item $fixtureSource $fixtureWork -Recurse
Remove-Item (Join-Path $fixtureWork ".aspire") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $fixtureWork ".modules") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $fixtureWork "node_modules") -Recurse -Force -ErrorAction SilentlyContinue

$aspireConfigPath = Join-Path $fixtureWork "aspire.config.json"
$aspireConfig = Get-Content $aspireConfigPath -Raw | ConvertFrom-Json
$aspireConfig.packages.$packageId = $PackageVersion
$aspireConfig | ConvertTo-Json -Depth 10 | Set-Content $aspireConfigPath -Encoding UTF8

$packageOutputFullPath = (Resolve-Path $packageOutput).Path
$packageOutputXml = [Security.SecurityElement]::Escape($packageOutputFullPath)
@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local-package-gate" value="$packageOutputXml" />
    $dependencySource
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="local-package-gate">
      <package pattern="PinguApps.Aspire.Hosting.Railway.Jobs" />
    </packageSource>
    $dependencyMapping
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
"@ | Set-Content (Join-Path $fixtureWork "NuGet.Config") -Encoding UTF8

Push-Location $fixtureWork
try {
    aspire restore --non-interactive
    if ($LASTEXITCODE -ne 0) { throw "aspire restore failed." }
    npm ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed." }
    npm run typecheck
    if ($LASTEXITCODE -ne 0) { throw "npm typecheck failed." }
    aspire publish --non-interactive --list-steps
    if ($LASTEXITCODE -ne 0) { throw "aspire publish failed." }
    aspire deploy --non-interactive --list-steps
    if ($LASTEXITCODE -ne 0) { throw "aspire deploy failed." }
}
finally {
    Pop-Location
}
}
finally {
    if ($null -eq $previousNuGetPackages) {
        Remove-Item Env:NUGET_PACKAGES -ErrorAction SilentlyContinue
    }
    else {
        $env:NUGET_PACKAGES = $previousNuGetPackages
    }
    $cachePath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $nugetPackages).Path)
    if ([IO.Path]::GetDirectoryName($cachePath) -ne [IO.Path]::GetFullPath($artifactsRoot) -or
        [IO.Path]::GetFileName($cachePath) -notmatch '^\.nuget-packages-[a-f0-9]{32}$') {
        throw "Package gate cache cleanup escaped its invocation directory."
    }
    Remove-Item -LiteralPath $cachePath -Recurse -Force
    if (Test-Path -LiteralPath $cachePath) { throw "Package gate invocation cache was not removed." }
}
