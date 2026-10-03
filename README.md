# PinguApps.Aspire.Hosting.Railway.Jobs

[![PinguApps.Aspire.Hosting.Railway.Jobs version](https://img.shields.io/nuget/v/PinguApps.Aspire.Hosting.Railway.Jobs?style=for-the-badge&label=PinguApps.Aspire.Hosting.Railway.Jobs)](https://www.nuget.org/packages/PinguApps.Aspire.Hosting.Railway.Jobs/) [![PinguApps.Aspire.Hosting.Railway.Jobs downloads](https://img.shields.io/nuget/dt/PinguApps.Aspire.Hosting.Railway.Jobs?style=for-the-badge&label=downloads)](https://www.nuget.org/packages/PinguApps.Aspire.Hosting.Railway.Jobs/)

Publish existing Aspire projects and containers as finite release jobs or scheduled Railway jobs. Normal local Aspire behavior stays unchanged. Create target/deployment parameters and attach publishers only inside `IsPublishMode`, so local runs require no control-plane credentials. This package uses the shared `PinguApps.Aspire.Hosting.Railway` target for authentication, ownership, immutable image deployment, variables, networking, and provider interaction.

## Install

```shell
dotnet add package PinguApps.Aspire.Hosting.Railway.Jobs --version 1.0.0
```

Requires .NET 10 and Aspire 13.6.0. Publish `PinguApps.Aspire.Hosting.Railway` 1.0.0 before this dependent package. See [installation and repository setup](docs/install.md).

## Finite release jobs

```csharp
using Aspire.Hosting.Railway;
using Aspire.Hosting.Railway.Jobs;

var migration = builder.AddProject<Projects.Migration>("migration").WithReference(database);
var web = builder.AddProject<Projects.Web>("web");

if (builder.ExecutionContext.IsPublishMode)
{
    var target = builder.AddRailwayTarget(
        "railway",
        builder.AddParameter("railway-project-id"),
        builder.AddParameter("railway-environment-id"),
        builder.AddParameter("railway-api-token", secret: true),
        builder.AddParameter("site-key"));

    migration.PublishToRailwayJob(target, options =>
    {
        options.Image = release.MigrationImage; // image@sha256:...
        options.Timeout = TimeSpan.FromMinutes(5);
    });

    web.PublishToRailway(target, options =>
    {
        options.Image = release.WebImage;
        options.DeploymentDependsOn.Add(migration.Resource);
        options.Port = 8080;
        options.PublicDomain = true;
    });
}
```

Run `aspire deploy`. Railway starts the retained image without rebuilding it. A finite job always uses restart policy `NEVER` and no automatic retries. Its deployment step waits for the exact deployment's instances to exit successfully, rather than treating Railway's `SUCCESS` (running) status as completed work. Failure or timeout fails the step, so the dependent web deployment cannot start.

Migrations, seeding, and managed-media publishing use this finite-job form. Explicitly configure deployment dependencies for required release order. `.WaitFor(...)` continues to describe local runtime behavior; it is not a release completion gate. Application code must make repeated executions safe: the publisher reuses the same owned service, but does not provide exactly-once business execution.

## Scheduled jobs

```csharp
// Within the same publish-only branch, publish a locally declared backup resource:
backup.PublishToRailwayCronJob(target, "0 2 * * *", options =>
{
    options.Image = release.BackupImage;
    options.StartCommand = "dotnet Backup.dll";
    options.MemoryGB = 0.5;
    options.VCpus = 0.5;
});
```

Railway evaluates schedules in UTC and skips a scheduled run while its preceding run remains active. The executable must exit after its work and implement its own runtime deadline. The options timeout bounds deployment publication, not later cron executions. Do not publish a permanent worker as a cron job.

PostgreSQL backups and enquiry retention/dead-letter cleanup use this scheduled form. Production-only selection, credentials, retention policy, and processing logic belong to the consumer AppHost and executable.

## TypeScript AppHost

```json
{
  "sdk": { "version": "13.6.0" },
  "packages": {
    "PinguApps.Aspire.Hosting.Railway": "1.0.0",
    "PinguApps.Aspire.Hosting.Railway.Jobs": "1.0.0"
  }
}
```

```typescript
let migration = await builder.addContainer("migration", "ghcr.io/example/migration");
let backup = await builder.addContainer("backup", "ghcr.io/example/backup");
if (await builder.executionContext().isPublishMode()) {
  const projectId = await builder.addParameter("railway-project-id");
  const environmentId = await builder.addParameter("railway-environment-id");
  const apiToken = await builder.addParameter("railway-api-token", { secret: true });
  const siteKey = await builder.addParameter("site-key");
  const target = await builder.addRailwayTarget("railway", projectId, environmentId, apiToken, siteKey);
  migration = await migration.publishToRailwayJob(target, {
    image: migrationImageDigest,
    timeoutSeconds: 300,
  });
  backup = await backup.publishToRailwayCronJob(target, "0 2 * * *", {
    image: backupImageDigest,
    memoryGB: 0.5,
    vCpus: 0.5,
  });
}
```

Use `await web.withRailwayDeploymentDependency(migration)` for the TypeScript release gate. See the [TypeScript guide](docs/getting-started-typescript.md), [configuration](docs/configuration.md), and [deployment behavior](docs/deployment-behaviour.md).

## Validation

```shell
pwsh ./eng/Test-AspireVersionPins.ps1
pwsh ./eng/Prepare-RailwayDependency.ps1
dotnet test Aspire.Hosting.Railway.Jobs.slnx -c Release
pwsh ./eng/Validate-TypeScriptAppHostPackage.ps1
```

The package gate packs the real NuGet, restores a TypeScript fixture through that package, generates bindings, checks TypeScript, and lists the publish pipeline without provider credentials. See [live integration evidence](docs/live-integration.md) for real `aspire deploy` validation and retained Railway resources.
