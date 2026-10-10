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

Normal builds and CI restore core from NuGet.org. The packed gate uses a fresh isolated cache for both compilation and the consumer, verifies the packed Jobs reference against that exact core assembly, and records the dependency package SHA-512 in `artifacts/typescript-apphost-package/dependency-binding.json`. Release publication passes `-RequirePublishedDependency`, which rejects any substitute dependency feed; only the validated Jobs package and symbols are published.

For an unpublished core PR only, `eng/Prepare-RailwayDependency.ps1` packs the pinned public core source into a separate feed. Pass that feed explicitly with `eng/Validate-TypeScriptAppHostPackage.ps1 -DependencyFeed <feed>`. This checks integration work without allowing it into NuGet release publication.

Release publication is user-controlled. This change does not publish or merge a package.

## Consumer Railway setup

Create and record the project and environment beforehand. Set its shared `PINGUAPPS_SITE_KEY` to the recorded site key. Supply matching project/environment/site-key parameters and an environment-scoped project token as a secret Aspire parameter. The token stays in the deployment control plane; supply only the specific database/storage credentials needed by each job.

See the core target documentation for ownership/adoption, private registry authentication, and allocation checks. The default image path requires public or appropriately accessible retained `image@sha256` references; runtime GHCR access is independent of the machine's Docker login. Alternatively configure `Build` and install the Railway CLI to upload a Dockerfile context through `aspire deploy`. Railway owns that build's retained image and later restarts need no GitHub pull token.
