using Aspire.Hosting;

namespace Projects;

internal sealed class Migration : IProjectMetadata
{
    public string ProjectPath => "../Migration/Migration.csproj";

    public LaunchSettings LaunchSettings { get; } = new();

    public bool SuppressBuild => true;

    public bool IsFileBasedApp => false;
}
