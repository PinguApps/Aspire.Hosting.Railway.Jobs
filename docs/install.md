# Installation and repository setup

Install `PinguApps.Aspire.Hosting.Railway.Jobs` in the AppHost. Its minimum core dependency is `PinguApps.Aspire.Hosting.Railway` 1.1.0, so publish the core package first.

The repository copies the existing PinguApps Aspire integration's Central Package Management, custom analyzers, build policies, pinned workflows, release drafting, label automation, NuGet OIDC login, and packed TypeScript package gate.

## GitHub setup

- Enable Blacksmith runners for this repository, matching the other Aspire integrations.
- Set repository secret `NUGET_USER` to the NuGet.org owner login.
- Create a NuGet.org trusted-publishing policy for `PinguApps/Aspire.Hosting.Railway.Jobs`, workflow `publish.yml`, and the expected publishing account. No permanent NuGet API key is used.
- Give repository Actions the permissions used by label automation, release drafting, and test-result publishing. Workflows declare their least required permissions.
- Install/enable the same optional automated review apps used by the reference repositories.

The optional manual live workflow uses `RAILWAY_API_TOKEN`, `RAILWAY_PROJECT_ID`, `RAILWAY_ENVIRONMENT_ID`, and `RAILWAY_SITE_KEY` for a dedicated test project. Its shared site marker must match, and artifacts remain deployed for inspection. Ordinary PR tests need no Railway credentials.

Before core 1.1.0 is published, `eng/Prepare-RailwayDependency.ps1` restores the exact pinned, public core source commit and packs the centrally declared core version into a separate local dependency feed. CI and the TypeScript package gate use that feed. Publishing pushes only this repository's package and symbols. Repin the bootstrap when accepting a newer core revision; after core 1.1.0 is published, replace the bootstrap with the published dependency. For local core changes, pass an already packed feed through `eng/Validate-TypeScriptAppHostPackage.ps1 -DependencyFeed <feed>`.

Release publication is user-controlled. This change does not publish or merge a package.

## Consumer Railway setup

Create and record the project and environment beforehand. Set its shared `PINGUAPPS_SITE_KEY` to the recorded site key. Supply matching project/environment/site-key parameters and an environment-scoped project token as a secret Aspire parameter. The token stays in the deployment control plane; supply only the specific database/storage credentials needed by each job.

See the core target documentation for ownership/adoption, private registry authentication, and allocation checks. The default image path requires public or appropriately accessible retained `image@sha256` references; runtime GHCR access is independent of the machine's Docker login. Alternatively configure `Build` and install the Railway CLI to upload a Dockerfile context through `aspire deploy`. Railway owns that build's retained image and later restarts need no GitHub pull token.
