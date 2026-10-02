using Aspire.Hosting.ApplicationModel;

namespace Aspire.Hosting.Railway.Jobs;

/// <summary>Publishes existing Aspire projects and containers as Railway finite or scheduled jobs.</summary>
public static class RailwayJobsBuilderExtensions
{
    /// <summary>Provides deploy-only Railway jobs for an existing resource builder.</summary>
    /// <typeparam name="T">The existing project or container resource type.</typeparam>
    /// <param name="builder">The resource builder.</param>
    extension<T>(IResourceBuilder<T> builder) where T : IResourceWithEnvironment
    {
        /// <summary>Publishes a finite workload and waits for successful process completion before deployment continues.</summary>
        /// <param name="target">The shared Railway deployment target.</param>
        /// <param name="configure">Optional finite job settings.</param>
        /// <returns>The same resource builder.</returns>
        [AspireExportIgnore(Reason = "C# callbacks are not a stable guest-language transport contract.")]
        public IResourceBuilder<T> PublishToRailwayJob(IResourceBuilder<RailwayTargetResource> target, Action<RailwayJobOptions>? configure = null)
        {
            ArgumentNullException.ThrowIfNull(builder);
            ArgumentNullException.ThrowIfNull(target);
            RailwayJobOptions options = new();
            configure?.Invoke(options);
            options.Validate();
            return builder.PublishToRailway(target, service =>
            {
                options.CopyTo(service);
                service.WaitForCompletion = true;
            });
        }

        /// <summary>Publishes a scheduled finite workload with a UTC schedule and Railway's skip-overlap behavior.</summary>
        /// <param name="target">The shared Railway deployment target.</param>
        /// <param name="schedule">A five-field numeric UTC cron schedule, at least five minutes apart.</param>
        /// <param name="configure">Optional job settings. Timeout bounds publication; scheduled runtime timeouts belong in the executable.</param>
        /// <returns>The same resource builder.</returns>
        [AspireExportIgnore(Reason = "C# callbacks are not a stable guest-language transport contract.")]
        public IResourceBuilder<T> PublishToRailwayCronJob(IResourceBuilder<RailwayTargetResource> target, string schedule, Action<RailwayJobOptions>? configure = null)
        {
            ArgumentNullException.ThrowIfNull(builder);
            ArgumentNullException.ThrowIfNull(target);
            RailwayCronSchedule.Validate(schedule);
            RailwayJobOptions options = new();
            configure?.Invoke(options);
            options.Validate();
            return builder.PublishToRailway(target, service =>
            {
                options.CopyTo(service);
                service.CronSchedule = schedule;
                service.WaitForCompletion = false;
            });
        }
    }

    /// <summary>Publishes a finite container from a TypeScript AppHost.</summary>
    /// <param name="builder">The existing container.</param>
    /// <param name="target">The shared Railway target.</param>
    /// <param name="options">Optional transport-safe job settings.</param>
    /// <returns>The same resource builder.</returns>
    [AspireExport("pinguapps.railway.jobs.publishToRailwayJob", MethodName = "publishToRailwayJob")]
    public static IResourceBuilder<ContainerResource> PublishToRailwayJobForTypeScript(this IResourceBuilder<ContainerResource> builder, IResourceBuilder<RailwayTargetResource> target, RailwayJobOptionsDto? options = null)
    {
        RailwayJobOptions settings = (options ?? new()).ToOptions();
        return builder.PublishToRailwayJob(target, destination => CopyOptions(settings, destination));
    }

    /// <summary>Publishes a scheduled container from a TypeScript AppHost.</summary>
    /// <param name="builder">The existing container.</param>
    /// <param name="target">The shared Railway target.</param>
    /// <param name="schedule">A five-field UTC cron schedule.</param>
    /// <param name="options">Optional transport-safe job settings.</param>
    /// <returns>The same resource builder.</returns>
    [AspireExport("pinguapps.railway.jobs.publishToRailwayCronJob", MethodName = "publishToRailwayCronJob")]
    public static IResourceBuilder<ContainerResource> PublishToRailwayCronJobForTypeScript(this IResourceBuilder<ContainerResource> builder, IResourceBuilder<RailwayTargetResource> target, string schedule, RailwayJobOptionsDto? options = null)
    {
        RailwayJobOptions settings = (options ?? new()).ToOptions();
        return builder.PublishToRailwayCronJob(target, schedule, destination => CopyOptions(settings, destination));
    }

    /// <summary>Publishes a finite .NET project from a TypeScript AppHost.</summary>
    /// <param name="builder">The existing project.</param>
    /// <param name="target">The shared Railway target.</param>
    /// <param name="options">Optional transport-safe job settings.</param>
    /// <returns>The same resource builder.</returns>
    [AspireExport("pinguapps.railway.jobs.project.publishToRailwayJob", MethodName = "publishToRailwayJob")]
    public static IResourceBuilder<ProjectResource> PublishProjectToRailwayJobForTypeScript(this IResourceBuilder<ProjectResource> builder, IResourceBuilder<RailwayTargetResource> target, RailwayJobOptionsDto? options = null)
    {
        RailwayJobOptions settings = (options ?? new()).ToOptions();
        return builder.PublishToRailwayJob(target, destination => CopyOptions(settings, destination));
    }

    /// <summary>Publishes a scheduled .NET project from a TypeScript AppHost.</summary>
    /// <param name="builder">The existing project.</param>
    /// <param name="target">The shared Railway target.</param>
    /// <param name="schedule">A five-field UTC cron schedule.</param>
    /// <param name="options">Optional transport-safe job settings.</param>
    /// <returns>The same resource builder.</returns>
    [AspireExport("pinguapps.railway.jobs.project.publishToRailwayCronJob", MethodName = "publishToRailwayCronJob")]
    public static IResourceBuilder<ProjectResource> PublishProjectToRailwayCronJobForTypeScript(this IResourceBuilder<ProjectResource> builder, IResourceBuilder<RailwayTargetResource> target, string schedule, RailwayJobOptionsDto? options = null)
    {
        RailwayJobOptions settings = (options ?? new()).ToOptions();
        return builder.PublishToRailwayCronJob(target, schedule, destination => CopyOptions(settings, destination));
    }

    private static void CopyOptions(RailwayJobOptions source, RailwayJobOptions target)
    {
        target.ServiceName = source.ServiceName;
        target.OwnershipMode = source.OwnershipMode;
        target.ExistingServiceId = source.ExistingServiceId;
        target.Image = source.Image;
        target.StartCommand = source.StartCommand;
        target.Timeout = source.Timeout;
        target.Region = source.Region;
        target.MemoryGB = source.MemoryGB;
        target.VCpus = source.VCpus;
    }
}
