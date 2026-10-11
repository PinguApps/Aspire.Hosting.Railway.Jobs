# Tests

Active xUnit v3 tests cover finite configuration, local-resource preservation, deployment prerequisites, TypeScript DTO settings, timeout boundaries, supported UTC cron expressions, and invalid/minimum-frequency cron expressions.

Active Reqnroll source-build scenarios cover C# finite/cron forwarding, every TypeScript container/project finite/cron export, local image preservation, no-retry lifecycle settings, and deployment prerequisites. The packed TypeScript fixture checks nested build DTO bindings alongside the existing image-based consumers.

The assembly-binding Reqnroll scenario compares the Jobs publisher's core reference with the installed core's full assembly identity. The packed gate checks the extracted Jobs assembly against the exact dependency restored for compilation; its default uses official NuGet.org and a new cache for every invocation. Explicit unpublished-core feeds remain available for integration PRs, but release publication rejects them.

The NuGet-backed TypeScript fixture is tested separately by `eng/Validate-TypeScriptAppHostPackage.ps1`. Live tests use a temporary external consumer project and a dedicated Railway environment; see `docs/live-integration.md`. No historical disabled scenarios are copied into this new package.
