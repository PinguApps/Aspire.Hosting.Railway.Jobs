using System.Reflection;
using Reqnroll;
using Xunit;

namespace Aspire.Hosting.Railway.Jobs.Tests;

[Binding]
public sealed class RailwayPackageBindingSteps
{
    private Assembly? _jobs;
    private AssemblyName? _core;
    private AssemblyName[]? _references;

    [Given("the built Jobs publisher and installed Railway core dependency")]
    public void GivenPublisherAndCore()
    {
        _jobs = typeof(RailwayJobOptions).Assembly;
        _core = typeof(RailwayServiceOptions).Assembly.GetName();
    }

    [When("the publisher assembly dependencies are inspected")]
    public void WhenDependenciesAreInspected() => _references = _jobs!.GetReferencedAssemblies();

    [Then("the Railway reference matches the installed core assembly version")]
    public void ThenCoreReferenceMatches()
    {
        AssemblyName reference = Assert.Single(_references!, identity => identity.Name == _core!.Name);
        Assert.Equal(_core!.FullName, reference.FullName);
    }
}
