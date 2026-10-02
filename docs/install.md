# Installation and repository setup

Install `PinguApps.Aspire.Hosting.Railway.Jobs` 1.0.0 in the AppHost. Its core dependency is `PinguApps.Aspire.Hosting.Railway` 1.0.0, so publish the core package first.

The repository copies the existing PinguApps Aspire integration's Central Package Management, custom analyzers, build policies, pinned workflows, release drafting, label automation, NuGet OIDC login, and packed TypeScript package gate.

## GitHub setup

- Enable Blacksmith runners for this repository, matching the other Aspire integrations.
- Set repository secret `NUGET_USER` to the NuGet.org owner login.
- Create a NuGet.org trusted-publishing policy for `PinguApps/Aspire.Hosting.Railway.Jobs`, workflow `publish.yml`, and the expected publishing account. No permanent NuGet API key is used.
- Give repository Actions the permissions used by label automation, release drafting, and test-result publishing. Workflows declare their least required permissions.
- Install/enable the same optional automated review apps used by the reference repositories.

The optional manual live workflow uses `RAILWAY_API_TOKEN`, `RAILWAY_PROJECT_ID`, `RAILWAY_ENVIRONMENT_ID`, and `RAILWAY_SITE_KEY` for a dedicated test project. Its shared site marker must match, and artifacts remain deployed for inspection. Ordinary PR tests need no Railway credentials.

Before the first core NuGet release, `eng/Prepare-RailwayDependency.ps1` restores the exact pinned, public core source commit and packs core 1.0.0 into a separate local dependency feed. CI and the TypeScript package gate use that feed. Publishing pushes only this repository's package and symbols. Repin the bootstrap when accepting a newer core revision; after core 1.0.0 is published, replace the bootstrap with the published dependency.

Release publication is user-controlled. This change does not publish or merge a package.

## Consumer Railway setup

Create and record the project and environment beforehand. Set its shared `PINGUAPPS_SITE_KEY` to the recorded site key. Supply matching project/environment/site-key parameters and an environment-scoped project token as a secret Aspire parameter. The token stays in the deployment control plane; supply only the specific database/storage credentials needed by each job.

See the core target documentation for ownership/adoption, private registry authentication, and allocation checks. Public or appropriately accessible retained `image@sha256` references are required. Runtime GHCR access is independent of the machine's Docker login.
