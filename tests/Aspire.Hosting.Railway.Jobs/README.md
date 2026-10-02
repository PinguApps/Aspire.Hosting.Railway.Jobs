# Tests

Active xUnit v3 tests cover finite configuration, local-resource preservation, deployment prerequisites, TypeScript DTO settings, timeout boundaries, supported UTC cron expressions, and invalid/minimum-frequency cron expressions.

The NuGet-backed TypeScript fixture is tested separately by `eng/Validate-TypeScriptAppHostPackage.ps1`. Live tests use a temporary external consumer project and a dedicated Railway environment; see `docs/live-integration.md`. No historical disabled scenarios are copied into this new package.
