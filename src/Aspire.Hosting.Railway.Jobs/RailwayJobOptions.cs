using Aspire.Hosting.ApplicationModel;

namespace Aspire.Hosting.Railway.Jobs;

/// <summary>
/// Deploy-only configuration for a finite Railway container workload.
/// </summary>
public sealed class RailwayJobOptions
{
    /// <summary>Gets or sets the explicit remote service name. Defaults to the Aspire resource name.</summary>
    public string? ServiceName { get; set; }

    /// <summary>Gets or sets the policy for creating or adopting the remote service.</summary>
    public RailwayOwnershipMode OwnershipMode { get; set; } = RailwayOwnershipMode.CreateOrAdopt;

    /// <summary>Gets or sets the recorded service ID required for explicitly adopting an unmarked service.</summary>
    public string? ExistingServiceId { get; set; }

    /// <summary>Gets or sets the retained container image including its immutable SHA-256 digest.</summary>
    public string? Image { get; set; }

    /// <summary>Gets or sets the container start command.</summary>
    public string? StartCommand { get; set; }

    /// <summary>Gets or sets the bounded time allowed for deployment and process completion.</summary>
    public TimeSpan Timeout { get; set; } = TimeSpan.FromMinutes(10);

    /// <summary>Gets or sets the deployment region.</summary>
    public string? Region { get; set; }

    /// <summary>Gets or sets the container memory limit in GB.</summary>
    public double? MemoryGB { get; set; }

    /// <summary>Gets or sets the container CPU limit.</summary>
    public double? VCpus { get; set; }

    /// <summary>Gets deployment prerequisites which must complete before this job starts.</summary>
    public List<IResource> DeploymentDependsOn { get; } = [];

    internal void Validate()
    {
        if (Timeout <= TimeSpan.Zero || Timeout > TimeSpan.FromDays(1))
        {
            throw new ArgumentOutOfRangeException(nameof(Timeout), "Job timeout must be positive and at most 24 hours.");
        }
    }

    internal void CopyTo(RailwayServiceOptions target)
    {
        target.ServiceName = ServiceName;
        target.OwnershipMode = OwnershipMode;
        target.ExistingServiceId = ExistingServiceId;
        target.Image = Image;
        target.StartCommand = StartCommand;
        target.RestartPolicy = RailwayRestartPolicy.Never;
        target.RestartPolicyMaxRetries = 0;
        target.DeploymentTimeout = Timeout;
        target.Region = Region;
        target.MemoryGB = MemoryGB;
        target.VCpus = VCpus;
        foreach (IResource dependency in DeploymentDependsOn)
        {
            target.DeploymentDependsOn.Add(dependency);
        }
    }
}
