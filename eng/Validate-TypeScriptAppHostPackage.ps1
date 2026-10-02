param(
    [string] $Configuration = "Release",
    [string] $PackageVersion = "9999.0.0",
    [string] $DependencyFeed
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
$nugetPackages = Join-Path $artifactsRoot ".nuget-packages"
$packageId = "PinguApps.Aspire.Hosting.Railway.Jobs"

if ([string]::IsNullOrWhiteSpace($DependencyFeed)) {
    $DependencyFeed = & (Join-Path $PSScriptRoot "Prepare-RailwayDependency.ps1") -Configuration $Configuration
}
$dependencyFeedFullPath = (Resolve-Path $DependencyFeed).Path
$allowedArtifacts = [IO.Path]::GetFullPath((Join-Path $repoRoot "artifacts")) + [IO.Path]::DirectorySeparatorChar
if (-not ([IO.Path]::GetFullPath($artifactsRoot)).StartsWith($allowedArtifacts, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Package gate output must remain inside repository artifacts."
}

Remove-Item $artifactsRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item $packageOutput -ItemType Directory -Force | Out-Null
New-Item $nugetPackages -ItemType Directory -Force | Out-Null

$restoreConfig = Join-Path $artifactsRoot "NuGet.restore.Config"
$restoreFeedXml = [Security.SecurityElement]::Escape($dependencyFeedFullPath)
@"
<configuration>
  <packageSources>
    <clear />
    <add key="railway-dependency" value="$restoreFeedXml" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
"@ | Set-Content $restoreConfig
dotnet restore $solutionPath --configfile $restoreConfig
dotnet build $solutionPath -c $Configuration --no-restore -p:ContinuousIntegrationBuild=true
dotnet pack $solutionPath -c $Configuration --no-build -p:Version=$PackageVersion -o $packageOutput

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

# Aspire restores guest-language integrations using its configured channel sources.
# Seed the unpublished, packed core dependency in this isolated cache, just like the package under test.
[xml]$centralVersions = Get-Content (Join-Path $repoRoot "Directory.Packages.props") -Raw
$coreVersion = ($centralVersions.Project.ItemGroup.PackageVersion | Where-Object Include -eq "PinguApps.Aspire.Hosting.Railway").Version
if ($coreVersion -notmatch '^\d+\.\d+\.\d+$') { throw "The core dependency must have an exact stable version." }
$coreId = "pinguapps.aspire.hosting.railway"
$coreFile = Join-Path $dependencyFeedFullPath "PinguApps.Aspire.Hosting.Railway.$coreVersion.nupkg"
$coreCache = Join-Path $nugetPackages "$coreId/$coreVersion"
New-Item $coreCache -ItemType Directory -Force | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($coreFile, $coreCache)
Copy-Item $coreFile (Join-Path $coreCache "$coreId.$coreVersion.nupkg")
$coreHash = [Convert]::ToBase64String([Security.Cryptography.SHA512]::HashData([IO.File]::ReadAllBytes($coreFile)))
Set-Content (Join-Path $coreCache "$coreId.$coreVersion.nupkg.sha512") $coreHash -Encoding ASCII
[ordered]@{ version = 2; contentHash = $coreHash; source = $dependencyFeedFullPath } |
    ConvertTo-Json | Set-Content (Join-Path $coreCache ".nupkg.metadata") -Encoding UTF8

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
$dependencyFeedXml = [Security.SecurityElement]::Escape($dependencyFeedFullPath)
@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local-package-gate" value="$packageOutputXml" />
    <add key="railway-dependency" value="$dependencyFeedXml" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="local-package-gate">
      <package pattern="PinguApps.Aspire.Hosting.Railway.Jobs" />
    </packageSource>
    <packageSource key="railway-dependency">
      <package pattern="PinguApps.Aspire.Hosting.Railway" />
    </packageSource>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
"@ | Set-Content (Join-Path $fixtureWork "NuGet.Config") -Encoding UTF8

Push-Location $fixtureWork
try {
    $previousNuGetPackages = $env:NUGET_PACKAGES
    $env:NUGET_PACKAGES = $nugetPackages

    aspire restore --non-interactive
    npm ci --no-audit --no-fund
    npm run typecheck
    aspire publish --non-interactive --list-steps
    aspire deploy --non-interactive --list-steps
}
finally {
    if ($null -eq $previousNuGetPackages) {
        Remove-Item Env:NUGET_PACKAGES -ErrorAction SilentlyContinue
    }
    else {
        $env:NUGET_PACKAGES = $previousNuGetPackages
    }

    Pop-Location
}
