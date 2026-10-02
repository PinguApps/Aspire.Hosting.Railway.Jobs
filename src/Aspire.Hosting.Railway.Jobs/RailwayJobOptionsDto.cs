namespace Aspire.Hosting.Railway.Jobs;

/// <summary>TypeScript-friendly finite Railway job configuration.</summary>
[AspireDto]
public sealed class RailwayJobOptionsDto
{
    /// <summary>Gets or sets the remote service name.</summary>
    public string? ServiceName { get; set; }

    /// <summary>Gets or sets the creation/adoption policy. Defaults to CreateOrAdopt.</summary>
    public RailwayOwnershipMode? OwnershipMode { get; set; }

    /// <summary>Gets or sets the recorded service identity for explicit adoption.</summary>
    public string? ExistingServiceId { get; set; }

    /// <summary>Gets or sets the retained container image digest reference.</summary>
    public string? Image { get; set; }

    /// <summary>Gets or sets the container start command.</summary>
    public string? StartCommand { get; set; }

    /// <summary>Gets or sets the deployment and completion timeout in seconds. Defaults to 600.</summary>
    public int? TimeoutSeconds { get; set; }

    /// <summary>Gets or sets the deployment region.</summary>
    public string? Region { get; set; }

    /// <summary>Gets or sets the memory limit in GB.</summary>
    public double? MemoryGB { get; set; }

    /// <summary>Gets or sets the CPU limit.</summary>
    public double? VCpus { get; set; }

    internal RailwayJobOptions ToOptions()
    {
        return new RailwayJobOptions
        {
            ServiceName = ServiceName,
            OwnershipMode = OwnershipMode ?? RailwayOwnershipMode.CreateOrAdopt,
            ExistingServiceId = ExistingServiceId,
            Image = Image,
            StartCommand = StartCommand,
            Timeout = TimeSpan.FromSeconds(TimeoutSeconds ?? 600),
            Region = Region,
            MemoryGB = MemoryGB,
            VCpus = VCpus,
        };
    }
}
