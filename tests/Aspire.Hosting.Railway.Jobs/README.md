# Tests

Active xUnit v3 tests cover finite configuration, local-resource preservation, deployment prerequisites, TypeScript DTO settings, timeout boundaries, supported UTC cron expressions, and invalid/minimum-frequency cron expressions.

Active Reqnroll source-build scenarios cover C# finite/cron forwarding, every TypeScript container/project finite/cron export, local image preservation, no-retry lifecycle settings, and deployment prerequisites. The packed TypeScript fixture checks nested build DTO bindings alongside the existing image-based consumers.

The NuGet-backed TypeScript fixture is tested separately by `eng/Validate-TypeScriptAppHostPackage.ps1`. Live tests use a temporary external consumer project and a dedicated Railway environment; see `docs/live-integration.md`. No historical disabled scenarios are copied into this new package.
