$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
[xml]$props = Get-Content (Join-Path $repoRoot "Directory.Packages.props") -Raw
$baseline = ($props.Project.ItemGroup.PackageVersion | Where-Object Include -eq "Aspire.Hosting").Version
if ([string]::IsNullOrWhiteSpace($baseline)) { throw "Missing Aspire.Hosting baseline." }

foreach ($path in @("samples/TypeScriptAppHost/aspire.config.json", "tests/Aspire.Hosting.Railway.Jobs/Fixtures/TypeScriptAppHost/aspire.config.json")) {
    $config = Get-Content (Join-Path $repoRoot $path) -Raw | ConvertFrom-Json
    if ($config.sdk.version -ne $baseline) { throw "Aspire pin drift in $path." }
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
Write-Host "All Aspire version pins match $baseline."
