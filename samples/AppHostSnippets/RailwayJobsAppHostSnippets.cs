using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Railway;
using Aspire.Hosting.Railway.Jobs;

namespace PinguApps.Aspire.Hosting.Railway.Jobs.Samples;

public static class RailwayJobsAppHostSnippets
{
    public static void Configure(IDistributedApplicationBuilder builder)
    {
        IResourceBuilder<ContainerResource> migration = builder.AddContainer("migration", "ghcr.io/pinguapps/example-migration");
        IResourceBuilder<ContainerResource> web = builder.AddContainer("web", "ghcr.io/pinguapps/example-web");
        IResourceBuilder<ContainerResource> backup = builder.AddContainer("backup", "ghcr.io/pinguapps/example-backup");
        if (!builder.ExecutionContext.IsPublishMode)
        {
            return;
        }

        IResourceBuilder<RailwayTargetResource> target = builder.AddRailwayTarget(
            "railway",
            builder.AddParameter("railway-project-id"),
            builder.AddParameter("railway-environment-id"),
            builder.AddParameter("railway-api-token", secret: true),
            builder.AddParameter("site-key"));

        migration.PublishToRailwayJob(target, options =>
            {
                options.ServiceName = "migration";
                options.Image = "ghcr.io/pinguapps/example-migration@sha256:" + new string('a', 64);
                options.Timeout = TimeSpan.FromMinutes(5);
                options.MemoryGB = 0.5;
                options.VCpus = 0.5;
            });

        web.PublishToRailway(target, options =>
            {
                options.Image = "ghcr.io/pinguapps/example-web@sha256:" + new string('b', 64);
                options.DeploymentDependsOn.Add(migration.Resource);
                options.Port = 8080;
                options.PublicDomain = true;
            });

        backup.PublishToRailwayCronJob(target, "0 2 * * *", options =>
            {
                options.Image = "ghcr.io/pinguapps/example-backup@sha256:" + new string('c', 64);
                options.StartCommand = "dotnet Backup.dll";
                options.Timeout = TimeSpan.FromMinutes(5);
            });
    }
}
