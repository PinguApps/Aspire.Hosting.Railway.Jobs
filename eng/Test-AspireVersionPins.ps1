$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$props = Get-Content (Join-Path $repoRoot "Directory.Packages.props") -Raw
$baseline = ($props.Project.ItemGroup.PackageVersion | Where-Object Include -eq "Aspire.Hosting").Version
if ([string]::IsNullOrWhiteSpace($baseline)) { throw "Missing Aspire.Hosting baseline." }
$dotnet = ($props.Project.ItemGroup.PackageVersion | Where-Object Include -eq "Aspire.Hosting.Dotnet").Version
if ($dotnet -ne $baseline) { throw "Aspire.Hosting.Dotnet pin drift." }
$core = ($props.Project.ItemGroup.PackageVersion | Where-Object Include -eq "PinguApps.Aspire.Hosting.Railway").Version

foreach ($path in @("samples/TypeScriptAppHost/aspire.config.json", "tests/Aspire.Hosting.Railway.Jobs/Fixtures/TypeScriptAppHost/aspire.config.json")) {
    $config = Get-Content (Join-Path $repoRoot $path) -Raw | ConvertFrom-Json
    if ($config.sdk.version -ne $baseline) { throw "Aspire pin drift in $path." }
    if ($config.packages.'PinguApps.Aspire.Hosting.Railway' -ne $core) { throw "Railway core pin drift in $path." }
    if ($path.StartsWith("tests/") -and $config.packages.'Aspire.Hosting.Dotnet' -ne $baseline) {
        throw "Aspire.Hosting.Dotnet pin drift in $path."
    }
}

foreach ($path in @(".github/workflows/_run-tests.yml", ".github/workflows/pr-validation.yml", ".github/workflows/publish.yml")) {
    $matches = [regex]::Matches((Get-Content (Join-Path $repoRoot $path) -Raw), 'dotnet tool install -g Aspire\.Cli --version (?<version>\S+)')
    if ($matches.Count -eq 0) { throw "Missing Aspire CLI pin in $path." }
    foreach ($match in $matches) {
        if ($match.Groups["version"].Value -ne $baseline) { throw "Aspire CLI pin drift in $path." }
    }
}

$guide = Get-Content (Join-Path $repoRoot "AGENTS.md") -Raw
$match = [regex]::Match($guide, 'Target Aspire version:\s*`(?<version>[^`]+)`')
if (-not $match.Success -or $match.Groups["version"].Value -ne $baseline) { throw "Aspire guidance pin drift." }

$readme = Get-Content (Join-Path $repoRoot "README.md") -Raw
$live = Get-Content (Join-Path $repoRoot "eng/Test-LiveRailwayDeployment.ps1") -Raw
$pins = @(
    [regex]::Match($readme, 'Requires \.NET 10 or later, Aspire (?<version>\d+\.\d+\.\d+) or later'),
    [regex]::Match($readme, '"sdk"\s*:\s*\{\s*"version"\s*:\s*"(?<version>[^"]+)"'),
    [regex]::Match($live, '"sdk"\s*:\s*\{\s*"version"\s*:\s*"(?<version>[^"]+)"'),
    [regex]::Match($live, '<PackageReference Include="Aspire\.Hosting\.AppHost" Version="(?<version>[^"]+)"'),
    [regex]::Match($live, '<PackageReference Include="Aspire\.Hosting\.Dotnet" Version="(?<version>[^"]+)"')
)
foreach ($pin in $pins) {
    if (-not $pin.Success -or $pin.Groups["version"].Value -ne $baseline) {
        throw "Aspire version pin drift in the README or live deployment fixture."
    }
}

Write-Host "All Aspire version pins match $baseline."
