param(
    [string] $CoreCommit = "ba6ddcab7a0667a5d20aebbbaa71c6f7edbc4ef8",
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if ($CoreCommit -notmatch '^[a-f0-9]{40}$') {
    throw "CoreCommit must be the reviewed immutable Railway source commit."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "artifacts"))
$dependencyRoot = [IO.Path]::GetFullPath((Join-Path $artifactsRoot "railway-dependency-source"))
$packageFeed = [IO.Path]::GetFullPath((Join-Path $artifactsRoot "railway-dependencies"))
foreach ($target in @($dependencyRoot, $packageFeed)) {
    if (-not $target.StartsWith($artifactsRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Railway dependency preparation target is outside repository artifacts."
    }
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
}

git -C $dependencyRoot init --quiet | Write-Host
if ($LASTEXITCODE -ne 0) { throw "Railway source checkout initialization failed." }
git -C $dependencyRoot remote add origin https://github.com/PinguApps/Aspire.Hosting.Railway.git | Write-Host
if ($LASTEXITCODE -ne 0) { throw "Railway source remote initialization failed." }
git -C $dependencyRoot fetch --depth 1 origin $CoreCommit | Write-Host
if ($LASTEXITCODE -ne 0) { throw "Pinned Railway source fetch failed." }
git -C $dependencyRoot checkout --detach FETCH_HEAD | Write-Host
if ($LASTEXITCODE -ne 0) { throw "Pinned Railway checkout failed." }
$checkedOut = (git -C $dependencyRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $checkedOut -ne $CoreCommit) { throw "Railway source identity mismatch." }

dotnet pack (Join-Path $dependencyRoot "src/Aspire.Hosting.Railway/Aspire.Hosting.Railway.csproj") -c $Configuration -p:Version=1.0.0 -o $packageFeed | Write-Host
if ($LASTEXITCODE -ne 0) { throw "Pinned Railway source packaging failed." }
if (-not (Test-Path -LiteralPath (Join-Path $packageFeed "PinguApps.Aspire.Hosting.Railway.1.0.0.nupkg"))) {
    throw "Railway dependency package was not produced."
}

Write-Output $packageFeed
