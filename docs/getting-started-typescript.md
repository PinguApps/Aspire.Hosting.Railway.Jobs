# TypeScript AppHost

The public callback-free exports cover both `ContainerResource` and `ProjectResource`. They generate `publishToRailwayJob(target, options)` and `publishToRailwayCronJob(target, schedule, options)`. DTO settings match the C# options except `timeoutSeconds` transports an integer instead of `TimeSpan`.

See `samples/TypeScriptAppHost/apphost.mts`. List both the core and jobs packages in `aspire.config.json` so the core target/dependency exports are generated. Declare local resources outside the publish-mode branch; keep the target and deployment parameters inside it.

Run `aspire restore`, `npm ci`, and `npm run typecheck`. Run `aspire deploy --non-interactive --list-steps` to inspect the pipeline without connecting to Railway. Before the first NuGet releases, use the packed-package gate to prepare the unpublished core dependency and isolated package cache.

`eng/Validate-TypeScriptAppHostPackage.ps1` restores the fixture from a packed NuGet, not a source-only stand-in. Generated Aspire modules are local outputs and are not committed.
