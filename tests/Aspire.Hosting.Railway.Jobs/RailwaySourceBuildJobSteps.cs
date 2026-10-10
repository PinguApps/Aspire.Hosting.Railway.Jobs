using Aspire.Hosting.ApplicationModel;
using Reqnroll;
using Xunit;

namespace Aspire.Hosting.Railway.Jobs.Tests;

[Binding]
public sealed class RailwaySourceBuildJobSteps
{
    private readonly IDistributedApplicationBuilder _app = DistributedApplication.CreateBuilder();
    private readonly RailwayBuildOptions _build = new()
    {
        ContextPath = ".",
        DockerfilePath = "jobs/Dockerfile",
        BuildArguments = [new() { Name = "JOB_KIND", Value = "migration" }],
    };
    private IResourceBuilder<ContainerResource>? _container;
    private IResourceBuilder<ProjectResource>? _project;
    private IResource? _dependency;

    private IResource Resource => _container?.Resource ?? (IResource)_project!.Resource;

    [Given("a local container and Dockerfile source build settings")]
    public void GivenLocalContainer() => _container = _app.AddContainer("job", "busybox", "1.37");

    [Given("a local project and Dockerfile source build settings")]
    public void GivenLocalProject() => _project = _app.AddProject<Projects.Migration>("job");

    [When("the container is published as a C# (.*) job")]
    public void WhenCSharpJobIsPublished(string kind)
    {
        void Configure(RailwayJobOptions options) => options.Build = _build;
        if (kind == "finite")
        {
            Assert.Same(_container, _container!.PublishToRailwayJob(AddTarget(), Configure));
        }
        else
        {
            Assert.Same(_container, _container!.PublishToRailwayCronJob(AddTarget(), "0 2 * * *", Configure));
        }
    }

    [When("the resource is published as a TypeScript (.*) job")]
    public void WhenTypeScriptJobIsPublished(string kind)
    {
        RailwayJobOptionsDto options = new() { Build = _build };
        IResourceBuilder<RailwayTargetResource> target = AddTarget();
        if (_container is not null)
        {
            if (kind == "finite")
            {
                _container.PublishToRailwayJobForTypeScript(target, options);
            }
            else
            {
                _container.PublishToRailwayCronJobForTypeScript(target, "0 2 * * *", options);
            }
        }
        else if (kind == "finite")
        {
            _project!.PublishProjectToRailwayJobForTypeScript(target, options);
        }
        else
        {
            _project!.PublishProjectToRailwayCronJobForTypeScript(target, "0 2 * * *", options);
        }
    }

    [When("the source-built job requires an earlier deployment")]
    public void WhenDeploymentIsRequired()
    {
        _dependency = _app.AddContainer("prerequisite", "busybox").Resource;
        _container!.PublishToRailwayJob(AddTarget(), options =>
        {
            options.Build = _build;
            options.DeploymentDependsOn.Add(_dependency);
        });
    }

    [Then("the shared publisher receives the source build settings")]
    public void ThenBuildIsPreserved()
    {
        Assert.Same(_build, GetServiceOptions().Build);
        Assert.Null(GetServiceOptions().Image);
    }

    [Then("the local container image is preserved")]
    public void ThenLocalImageIsPreserved() => Assert.Equal("busybox", Resource.Annotations.OfType<ContainerImageAnnotation>().Single().Image);

    [Then("the (.*) job lifecycle is preserved")]
    public void ThenJobLifecycleIsPreserved(string kind)
    {
        RailwayServiceOptions options = GetServiceOptions();
        Assert.Equal(RailwayRestartPolicy.Never, options.RestartPolicy);
        Assert.Equal(0, options.RestartPolicyMaxRetries);
        Assert.Equal(TimeSpan.FromMinutes(10), options.DeploymentTimeout);
        Assert.Equal(kind == "finite", options.WaitForCompletion);
        Assert.Equal(kind == "cron" ? "0 2 * * *" : null, options.CronSchedule);
    }

    [Then("the shared publisher retains that deployment prerequisite")]
    public void ThenDependencyIsPreserved() => Assert.Same(_dependency, Assert.Single(GetServiceOptions().DeploymentDependsOn));

    private RailwayServiceOptions GetServiceOptions()
    {
        IResourceAnnotation annotation = Resource.Annotations.Single(item => item.GetType().Name == "RailwayServiceAnnotation");
        return (RailwayServiceOptions)annotation.GetType().GetProperty("Options", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic)!.GetValue(annotation)!;
    }

    private IResourceBuilder<RailwayTargetResource> AddTarget() => _app.AddRailwayTarget("railway", _app.AddParameter("project"), _app.AddParameter("environment"), _app.AddParameter("token", secret: true), _app.AddParameter("site"));
}
