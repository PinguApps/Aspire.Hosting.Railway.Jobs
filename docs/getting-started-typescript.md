# TypeScript AppHost

The public callback-free exports cover both `ContainerResource` and `ProjectResource`. They generate `publishToRailwayJob(target, options)` and `publishToRailwayCronJob(target, schedule, options)`. DTO settings match the C# options except `timeoutSeconds` transports an integer instead of `TimeSpan`.

Use `build: { contextPath: ".", dockerfilePath: "Dockerfile", buildArguments: [{ name: "JOB_MESSAGE", value: "migration" }] }` instead of `image` for an opt-in Railway-owned build. Both finite and cron exports support it. Build arguments are non-secret; runtime secrets belong in environment/reference configuration. Install the Railway CLI on the deployment machine. Nested build DTOs are exported from core 1.1.0 and exercised through the packed-package fixture.

See `samples/TypeScriptAppHost/apphost.mts`. List both the core and jobs packages in `aspire.config.json` so the core target/dependency exports are generated. Declare local resources outside the publish-mode branch; keep the target and deployment parameters inside it.

Run `aspire restore`, `npm ci`, and `npm run typecheck`. Run `aspire deploy --non-interactive --list-steps` to inspect the pipeline without connecting to Railway. The packed-package gate defaults to the official core NuGet and isolates both compilation and consumer caches. Use `-DependencyFeed` explicitly only when validating an unpublished core PR.

`eng/Validate-TypeScriptAppHostPackage.ps1` restores the fixture from a packed NuGet, not a source-only stand-in. Generated Aspire modules are local outputs and are not committed.
