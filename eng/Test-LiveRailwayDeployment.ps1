param(
    [Parameter(Mandatory)] [string] $PackageFeed,
    [Parameter(Mandatory)] [string] $ProjectId,
    [Parameter(Mandatory)] [string] $EnvironmentId,
    [Parameter(Mandatory)] [string] $SiteKey,
    [string] $TokenPath,
    [string] $AspireCommand = "aspire",
    [string] $PackageVersion = "1.0.0",
    [int] $CronObservationSeconds = 420
)

$ErrorActionPreference = "Stop"
$work = Join-Path ([IO.Path]::GetTempPath()) ("railway-jobs-consumer-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory $work | Out-Null
New-Item -ItemType Directory (Join-Path $work "Job") | Out-Null
@'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>
'@ | Set-Content (Join-Path $work "Job/Job.csproj")
'System.Console.WriteLine("Local development job");' | Set-Content (Join-Path $work "Job/Program.cs")
$feed = (Resolve-Path $PackageFeed).Path
$feedXml = [Security.SecurityElement]::Escape($feed)

@"
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$feedXml" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
"@ | Set-Content (Join-Path $work "NuGet.Config")

@"
<Project Sdk="Microsoft.NET.Sdk">
  <Sdk Name="Aspire.AppHost.Sdk" Version="13.6.0" />
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><IsAspireHost>true</IsAspireHost></PropertyGroup>
  <ItemGroup><Compile Remove="Job/**/*.cs" /></ItemGroup>
  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" Version="13.6.0" />
    <PackageReference Include="PinguApps.Aspire.Hosting.Railway.Jobs" Version="$PackageVersion" />
  </ItemGroup>
</Project>
"@ | Set-Content (Join-Path $work "Integration.AppHost.csproj")

@'
using Aspire.Hosting.Railway;
using Aspire.Hosting.Railway.Jobs;

var builder = DistributedApplication.CreateBuilder(args);
var target = builder.AddRailwayTarget("railway",
    builder.AddParameter("railway-project-id", Environment.GetEnvironmentVariable("PIN646_PROJECT")!),
    builder.AddParameter("railway-environment-id", Environment.GetEnvironmentVariable("PIN646_ENVIRONMENT")!),
    builder.AddParameter("railway-api-token", Environment.GetEnvironmentVariable("PIN646_TOKEN")!, secret: true),
    builder.AddParameter("site-key", Environment.GetEnvironmentVariable("PIN646_SITE_KEY")!));
const string image = "docker.io/library/busybox@sha256:66a6306db78bf2dbf3487f293aa8d6990d8e506fdffab9cc43fe422becf886e4";
string scenario = Environment.GetEnvironmentVariable("PIN646_SCENARIO") ?? "success";
var job = builder.AddProject("job-" + scenario, Path.Combine(builder.AppHostDirectory, "Job", "Job.csproj"))
    .WithEnvironment("PIN646_CAPABILITY", "migration")
    .PublishToRailwayJob(target, options =>
    {
        options.Image = image;
        options.ServiceName = "job-" + scenario;
        options.StartCommand = scenario switch
        {
            "failure" => "sh -c 'echo PIN646_JOB_FAILURE; exit 7'",
            "timeout" => "sh -c 'for i in 1 2 3 4 5; do echo PIN646_JOB_LONG_RUNNING; sleep 60; done; exit 0'",
            _ => "sh -c 'echo PIN646_JOB_SUCCESS; sleep 3; exit 0'",
        };
        options.Timeout = TimeSpan.FromSeconds(scenario == "timeout" ? 120 : 300);
        options.MemoryGB = 0.25;
        options.VCpus = 0.5;
        options.Region = "europe-west4-drams3a";
    })
    .PublishAsDockerFile();

builder.AddContainer("web-" + scenario, "busybox", "1.37.0")
    .WithEnvironment("PIN646_ROLE", "dependent-web")
    .PublishToRailway(target, options =>
    {
        options.Image = image;
        options.StartCommand = "sh -c 'mkdir -p /www; echo PIN646_JOBS_READY > /www/index.html; httpd -f -p 8080 -h /www'";
        options.DeploymentDependsOn.Add(job.Resource);
        options.Port = 8080;
        options.PublicDomain = true;
        options.HealthCheckPath = "/";
        options.DeploymentTimeout = TimeSpan.FromMinutes(5);
        options.MemoryGB = 0.25;
        options.VCpus = 0.5;
    });

if (scenario == "success")
{
    builder.AddContainer("scheduled-backup", "busybox", "1.37.0")
        .WithEnvironment("PIN646_CAPABILITY", "backup")
        .WithEnvironment("PIN646_CRON_PUBLICATION", Environment.GetEnvironmentVariable("PIN646_CRON_PUBLICATION")!)
        .PublishToRailwayCronJob(target, "*/5 * * * *", options =>
        {
            options.Image = image;
            options.StartCommand = "sh -c 'sleep 2; echo PIN646_SCHEDULED_SUCCESS; exit 0'";
            options.Timeout = TimeSpan.FromSeconds(300);
            options.MemoryGB = 0.25;
            options.VCpus = 0.5;
        });
}

builder.Build().Run();
'@ | Set-Content (Join-Path $work "Program.cs")

@'
{
  "appHost": { "path": "Integration.AppHost.csproj" },
  "sdk": { "version": "13.6.0" }
}
'@ | Set-Content (Join-Path $work "aspire.config.json")

$names = @("PIN646_PROJECT", "PIN646_ENVIRONMENT", "PIN646_TOKEN", "PIN646_SITE_KEY", "PIN646_SCENARIO", "PIN646_CRON_PUBLICATION", "NUGET_PACKAGES")
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }

function Invoke-ScopedQuery {
    param([string]$Query, [hashtable]$Variables)
    $payload = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10 -Compress
    $response = Invoke-RestMethod "https://backboard.railway.com/graphql/v2" -Method Post -ContentType "application/json" -Headers @{ "Project-Access-Token" = $token } -Body $payload
    if ($response.errors) { throw "Railway rejected integration verification query; details suppressed." }
    return $response.data
}

function Get-TestServices {
    $data = Invoke-ScopedQuery 'query($id:String!){environment(id:$id){serviceInstances{edges{node{serviceId serviceName cronSchedule restartPolicyType source{image} startCommand latestDeployment{id status}}}}}}' @{ id = $EnvironmentId }
    return @($data.environment.serviceInstances.edges.node)
}

function Get-TestDeployment {
    param([string]$Id)
    $data = Invoke-ScopedQuery 'query($id:String!){deployment(id:$id){id projectId environmentId serviceId status deploymentStopped instances{id status} meta}}' @{ id = $Id }
    if ($data.deployment.projectId -ne $ProjectId -or $data.deployment.environmentId -ne $EnvironmentId) { throw "Deployment scope mismatch." }
    return $data.deployment
}

function Assert-DeploymentLog {
    param([string]$DeploymentId, [string]$Marker)
    $data = Invoke-ScopedQuery 'query($id:String!){deploymentLogs(deploymentId:$id,limit:100){message}}' @{ id = $DeploymentId }
    if (-not ($data.deploymentLogs.message | Where-Object { $_.Contains($Marker) })) { throw "Expected workload execution marker missing: $Marker." }
}

try {
    $token = if ($TokenPath) { [IO.File]::ReadAllText((Resolve-Path $TokenPath).Path).Trim() } else { $env:RAILWAY_API_TOKEN }
    if ([string]::IsNullOrWhiteSpace($token)) { throw "A scoped Railway project token is required." }
    [Environment]::SetEnvironmentVariable("PIN646_PROJECT", $ProjectId)
    [Environment]::SetEnvironmentVariable("PIN646_ENVIRONMENT", $EnvironmentId)
    [Environment]::SetEnvironmentVariable("PIN646_TOKEN", $token)
    [Environment]::SetEnvironmentVariable("PIN646_SITE_KEY", $SiteKey)
    [Environment]::SetEnvironmentVariable("PIN646_CRON_PUBLICATION", [guid]::NewGuid().ToString("N"))
    [Environment]::SetEnvironmentVariable("NUGET_PACKAGES", (Join-Path $work ".nuget-packages"))

    Push-Location $work
    try {
        dotnet restore Integration.AppHost.csproj
        if ($LASTEXITCODE -ne 0) { throw "Consumer NuGet restore failed." }
        dotnet build Integration.AppHost.csproj -c Release --no-restore
        if ($LASTEXITCODE -ne 0) { throw "Consumer build failed." }
        $recordedSuccessIds = @{}
        foreach ($scenario in @("success", "success", "failure", "timeout")) {
            $env:PIN646_SCENARIO = $scenario
            $logPath = Join-Path $work ("deploy-" + $scenario + "-" + [guid]::NewGuid().ToString("N") + ".log")
            & $AspireCommand deploy --non-interactive 2>&1 | Tee-Object -FilePath $logPath
            $result = $LASTEXITCODE
            if (($scenario -eq "success" -and $result -ne 0) -or ($scenario -ne "success" -and $result -eq 0)) {
                throw "Unexpected deployment outcome for $scenario. Consumer/logs: $work"
            }
            $services = Get-TestServices
            $jobService = @($services | Where-Object serviceName -eq "job-$scenario")
            if ($jobService.Count -ne 1 -or -not $jobService[0].latestDeployment.id) { throw "Expected exactly one deployed $scenario job." }
            $jobDeployment = Get-TestDeployment $jobService[0].latestDeployment.id
            if ($jobService[0].restartPolicyType -ne "NEVER" -or $jobService[0].source.image -ne "docker.io/library/busybox@sha256:66a6306db78bf2dbf3487f293aa8d6990d8e506fdffab9cc43fe422becf886e4") {
                throw "Finite restart/image settings did not round-trip."
            }
            $limits = Invoke-ScopedQuery 'query($s:String!,$e:String!){serviceInstanceLimits(serviceId:$s,environmentId:$e)}' @{ s = $jobService[0].serviceId; e = $EnvironmentId }
            if ($limits.serviceInstanceLimits.containers.cpu -ne 0.5 -or $limits.serviceInstanceLimits.containers.memoryBytes -ne 250000000) {
                throw "Finite resource limits did not round-trip."
            }
            if ($jobDeployment.meta.serviceManifest.deploy.multiRegionConfig.ams.numReplicas -ne 1) {
                throw "Finite deployment region did not round-trip."
            }
            if ($scenario -eq "success") {
                if ($jobDeployment.status -ne "SUCCESS" -or -not $jobDeployment.deploymentStopped -or -not $jobDeployment.instances -or @($jobDeployment.instances | Where-Object status -ne "EXITED").Count -ne 0) { throw "Finite success did not prove successful process termination." }
                Assert-DeploymentLog $jobDeployment.id "PIN646_JOB_SUCCESS"
                foreach ($name in @("job-success", "web-success", "scheduled-backup")) {
                    $service = @($services | Where-Object serviceName -eq $name)
                    if ($service.Count -ne 1) { throw "Missing or duplicate successful resource: $name." }
                    if ($recordedSuccessIds.ContainsKey($name) -and $recordedSuccessIds[$name] -ne $service[0].serviceId) { throw "Repeated deployment changed remote service identity." }
                    $recordedSuccessIds[$name] = $service[0].serviceId
                }
            }
            else {
                $webService = @($services | Where-Object serviceName -eq "web-$scenario")
                if ($webService.Count -ne 0 -and $webService[0].latestDeployment.id) { throw "Failed job allowed downstream web deployment." }
                if ($scenario -eq "failure") {
                    Assert-DeploymentLog $jobDeployment.id "PIN646_JOB_FAILURE"
                    if ($jobDeployment.status -notin @("CRASHED", "FAILED") -and -not @($jobDeployment.instances | Where-Object status -eq "CRASHED").Count) { throw "Nonzero exit was not recorded as a failed execution." }
                }
                else {
                    Assert-DeploymentLog $jobDeployment.id "PIN646_JOB_LONG_RUNNING"
                    if ((Get-Content $logPath -Raw) -notmatch 'exceeded\s+its\s+completion\s+deadline') { throw "Timeout scenario failed for another reason." }
                }
            }
            Write-Host "Scenario $scenario returned expected exit code $result."
            Write-Host "Verified deployment $($jobDeployment.id), service $($jobService[0].serviceId), status $($jobDeployment.status)."
        }

        $cron = @((Get-TestServices) | Where-Object serviceName -eq "scheduled-backup")[0]
        if ($cron.cronSchedule -ne "*/5 * * * *" -or $cron.restartPolicyType -ne "NEVER") { throw "Cron configuration did not round-trip." }
        $observationStarted = [DateTimeOffset]::UtcNow
        $observedScheduledRun = $false
        $observeUntil = [DateTimeOffset]::UtcNow.AddSeconds($CronObservationSeconds)
        while ([DateTimeOffset]::UtcNow -lt $observeUntil) {
            $cron = @((Get-TestServices) | Where-Object serviceName -eq "scheduled-backup")[0]
            if ($cron.latestDeployment.id) {
                $execution = Get-TestDeployment $cron.latestDeployment.id
                if ($execution.status -eq "SUCCESS" -and $execution.deploymentStopped -and $execution.instances -and @($execution.instances | Where-Object status -ne "EXITED").Count -eq 0) {
                    $logs = Invoke-ScopedQuery 'query($id:String!){deploymentLogs(deploymentId:$id,limit:100){message timestamp}}' @{ id = $execution.id }
                    $scheduledMarker = @($logs.deploymentLogs | Where-Object {
                        $_.message.Contains("PIN646_SCHEDULED_SUCCESS") -and [DateTimeOffset]::Parse($_.timestamp) -gt $observationStarted
                    })
                    if ($scheduledMarker.Count -gt 0) {
                        $observedScheduledRun = $true
                        Write-Host "Observed real UTC cron execution $($execution.id), service $($cron.serviceId), marker $($scheduledMarker[-1].timestamp)."
                        break
                    }
                }
            }
            Start-Sleep -Seconds 10
        }
        if (-not $observedScheduledRun) { throw "No completed real scheduler execution observed." }
    }
    finally { Pop-Location }
}
finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
}
Write-Host "Temporary consumer retained outside repository: $work"
Write-Host "Deployment artifacts are retained in the dedicated Railway project for manual inspection."
