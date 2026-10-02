using Aspire.Hosting.ApplicationModel;
using Xunit;

namespace Aspire.Hosting.Railway.Jobs.Tests;

public sealed class RailwayJobsContractTests
{
    [Theory]
    [InlineData("*/5 * * * *")]
    [InlineData("0 2 * * *")]
    [InlineData("0,15,30,45 1-23/2 * * 1-5")]
    [InlineData("5-55/10 * 1,15 1-12/2 0")]
    public void AcceptsSupportedUtcCronSchedules(string schedule)
    {
        RailwayCronSchedule.Validate(schedule);
    }

    [Theory]
    [InlineData("* * * * *")]
    [InlineData("*/4 * * * *")]
    [InlineData("0,59 * * * *")]
    [InlineData("0 24 * * *")]
    [InlineData("0 * 0 * *")]
    [InlineData("0 * * 13 *")]
    [InlineData("0 * * * 7")]
    [InlineData("0 * * * MON")]
    [InlineData("TZ=Europe/London 0 2 * * *")]
    [InlineData("0 0 0 * * *")]
    [InlineData("5/10 * * * *")]
    [InlineData("*/0 * * * *")]
    [InlineData("-1 * * * *")]
    [InlineData("0, * * * *")]
    public void RejectsUnsupportedOrTooFrequentSchedules(string schedule)
    {
        Assert.Throws<ArgumentException>(() => RailwayCronSchedule.Validate(schedule));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(86401)]
    public void RejectsInvalidFiniteTimeout(int seconds)
    {
        RailwayJobOptions options = new() { Timeout = TimeSpan.FromSeconds(seconds) };
        Assert.Throws<ArgumentOutOfRangeException>(options.Validate);
    }

    [Fact]
    public void TypeScriptOptionsPreserveAllSettings()
    {
        RailwayJobOptionsDto dto = new()
        {
            ServiceName = "migration",
            OwnershipMode = RailwayOwnershipMode.ExistingOnly,
            ExistingServiceId = "recorded-service",
            Image = "ghcr.io/example/migration@sha256:" + new string('a', 64),
            StartCommand = "dotnet Migration.dll",
            TimeoutSeconds = 123,
            Region = "europe-west4-drams3a",
            MemoryGB = 0.5,
            VCpus = 1,
        };
        RailwayJobOptions options = dto.ToOptions();
        Assert.Equal(dto.ServiceName, options.ServiceName);
        Assert.Equal(dto.OwnershipMode, options.OwnershipMode);
        Assert.Equal(dto.ExistingServiceId, options.ExistingServiceId);
        Assert.Equal(dto.Image, options.Image);
        Assert.Equal(dto.StartCommand, options.StartCommand);
        Assert.Equal(TimeSpan.FromSeconds(123), options.Timeout);
        Assert.Equal(dto.Region, options.Region);
        Assert.Equal(dto.MemoryGB, options.MemoryGB);
        Assert.Equal(dto.VCpus, options.VCpus);
    }

    [Fact]
    public void FiniteJobsPreserveLocalResourceAndConfigureSharedPublisher()
    {
        IDistributedApplicationBuilder app = DistributedApplication.CreateBuilder();
        IResourceBuilder<RailwayTargetResource> target = AddTarget(app);
        IResourceBuilder<ContainerResource> local = app.AddContainer("migration", "busybox", "1.37");
        IResourceBuilder<ContainerResource> published = local.PublishToRailwayJob(target, options => options.Timeout = TimeSpan.FromMinutes(3));
        Assert.Same(local, published);
        Assert.Equal("busybox", local.Resource.Annotations.OfType<ContainerImageAnnotation>().Single().Image);
        RailwayServiceOptions settings = GetServiceOptions(local.Resource);
        Assert.Equal(RailwayRestartPolicy.Never, settings.RestartPolicy);
        Assert.Equal(0, settings.RestartPolicyMaxRetries);
        Assert.True(settings.WaitForCompletion);
        Assert.Null(settings.CronSchedule);
        Assert.Equal(TimeSpan.FromMinutes(3), settings.DeploymentTimeout);
    }

    [Fact]
    public void CronJobsAreScheduledFiniteExecutablesWithoutReleaseCompletionGate()
    {
        IDistributedApplicationBuilder app = DistributedApplication.CreateBuilder();
        IResourceBuilder<ContainerResource> cron = app.AddContainer("backup", "busybox", "1.37")
            .PublishToRailwayCronJob(AddTarget(app), "0 2 * * *");
        RailwayServiceOptions settings = GetServiceOptions(cron.Resource);
        Assert.Equal(RailwayRestartPolicy.Never, settings.RestartPolicy);
        Assert.Equal("0 2 * * *", settings.CronSchedule);
        Assert.False(settings.WaitForCompletion);
    }

    [Fact]
    public void FinitePrerequisitesArePassedToSharedPublisher()
    {
        IDistributedApplicationBuilder app = DistributedApplication.CreateBuilder();
        IResourceBuilder<ContainerResource> migration = app.AddContainer("migration", "busybox", "1.37");
        IResourceBuilder<ContainerResource> media = app.AddContainer("media", "busybox", "1.37")
            .PublishToRailwayJob(AddTarget(app), options => options.DeploymentDependsOn.Add(migration.Resource));
        RailwayServiceOptions settings = GetServiceOptions(media.Resource);
        Assert.Same(migration.Resource, Assert.Single(settings.DeploymentDependsOn));
    }

    [Fact]
    public void OrdinaryDotnetProjectSupportsFinitePublishingWithoutReplacement()
    {
        IDistributedApplicationBuilder app = DistributedApplication.CreateBuilder();
        IResourceBuilder<ProjectResource> project = app.AddProject<Projects.Migration>("migration");
        IResourceBuilder<ProjectResource> published = project.PublishToRailwayJob(AddTarget(app), options => options.Timeout = TimeSpan.FromMinutes(2));
        Assert.Same(project, published);
        Assert.IsType<ProjectResource>(published.Resource);
        Assert.True(GetServiceOptions(project.Resource).WaitForCompletion);
        Assert.Equal(TimeSpan.FromMinutes(2), GetServiceOptions(project.Resource).DeploymentTimeout);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(86401)]
    public void TypeScriptFiniteExportRejectsInvalidTimeout(int seconds)
    {
        IDistributedApplicationBuilder app = DistributedApplication.CreateBuilder();
        IResourceBuilder<ContainerResource> job = app.AddContainer("job", "busybox");
        IResourceBuilder<RailwayTargetResource> target = AddTarget(app);
        Assert.Throws<ArgumentOutOfRangeException>(() => job.PublishToRailwayJobForTypeScript(target, new() { TimeoutSeconds = seconds }));
    }

    [Fact]
    public void TypeScriptCronExportUsesTheSameValidationAndDefaults()
    {
        IDistributedApplicationBuilder app = DistributedApplication.CreateBuilder();
        IResourceBuilder<ContainerResource> cron = app.AddContainer("cron", "busybox");
        IResourceBuilder<RailwayTargetResource> target = AddTarget(app);
        Assert.Throws<ArgumentException>(() => cron.PublishToRailwayCronJobForTypeScript(target, "*/4 * * * *"));
        cron.PublishToRailwayCronJobForTypeScript(target, "*/5 * * * *");
        RailwayServiceOptions settings = GetServiceOptions(cron.Resource);
        Assert.Equal(TimeSpan.FromMinutes(10), settings.DeploymentTimeout);
        Assert.Equal(RailwayOwnershipMode.CreateOrAdopt, settings.OwnershipMode);
        Assert.Equal(RailwayRestartPolicy.Never, settings.RestartPolicy);
    }

    private static RailwayServiceOptions GetServiceOptions(IResource resource)
    {
        IResourceAnnotation annotation = resource.Annotations.Single(item => item.GetType().Name == "RailwayServiceAnnotation");
        return (RailwayServiceOptions)annotation.GetType().GetProperty("Options", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic)!.GetValue(annotation)!;
    }

    private static IResourceBuilder<RailwayTargetResource> AddTarget(IDistributedApplicationBuilder app)
    {
        return app.AddRailwayTarget("railway", app.AddParameter("project"), app.AddParameter("environment"), app.AddParameter("token", secret: true), app.AddParameter("site"));
    }
}
