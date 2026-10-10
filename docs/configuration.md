# Configuration

Both publish methods accept `RailwayJobOptions`; exported TypeScript methods accept `RailwayJobOptionsDto`.

| Option | Default | Meaning |
|---|---|---|
| `ServiceName` | Aspire resource name | Remote service identity |
| `OwnershipMode` | CreateOrAdopt | Create/adopt only after shared ownership checks |
| `ExistingServiceId` | None | Recorded service identity for explicit adoption |
| `Image` | Existing immutable image binding | Complete `registry/image@sha256:<64 lowercase hex>` reference |
| `Build` / `build` | None | Opt-in Dockerfile source upload and Railway-owned build; mutually exclusive with `Image` |
| `StartCommand` | Image command | Railway command override |
| `Timeout` / `timeoutSeconds` | 10 minutes / 600 | Positive publication/completion bound, at most 24 hours |
| `Region` | Railway default | Region ID |
| `MemoryGB` / `memoryGB` | Railway default | Positive memory limit |
| `VCpus` / `vCpus` | Railway default | Positive CPU limit |
| `DeploymentDependsOn` | Empty | C# resource deployment prerequisites |

Restart policy is always `NEVER`, with no automatic retries. Finite jobs require confirmed completion; scheduled jobs are published without waiting for their next scheduled execution. Workload environment is taken from normal `.WithEnvironment(...)` and `.WithReference(...)` configuration.

The shared core validates build inputs or image digests, limits, ownership, credentials, and resource type. Job timeouts and cron syntax are validated before provider mutation.

## Railway-owned builds

Set `Build = new RailwayBuildOptions { ContextPath = "..", DockerfilePath = "src/Migration/Dockerfile" }` instead of `Image` to upload source through `aspire deploy`. `ContextPath` is relative to the AppHost directory or absolute; `DockerfilePath` is relative to that context and defaults to `Dockerfile`. Optional `BuildArguments` contains name/value entries and must not contain secrets. Supply runtime secrets with normal Aspire environment/reference configuration.

Install the Railway CLI on the deployment machine; the core target's `CliPath` defaults to `railway`. The shared publisher uploads the build context, waits for the resulting Railway deployment, and applies the same finite/cron contract. Railway retains its own image for later restart or redeployment; no GHCR pull token is needed for this source-built job. The build and finite process both count towards `Timeout`, so allow enough time for compilation.

Omitting `Build` retains the existing immutable-image path. Public generic images can keep that path; a private registry still requires persistent registry credentials. Source-built cron jobs use the retained deployment for later scheduled executions. A new `aspire deploy` uploads and builds again; rollback to retained deployments belongs to the shared core/provider lifecycle.

## UTC cron syntax

Five numeric fields: minute, hour, day of month, month, day of week (0 is Sunday). Supports `*`, comma lists, inclusive ranges, and positive steps on wildcard/range fields. Names, timezone prefixes, seconds, Sunday `7`, and single-value steps are not supported.

Every selected minute must be at least five minutes from the next, including the hour boundary. This conservative rule guarantees Railway's minimum interval independently of other fields: `*/5 * * * *`, `0 2 * * *`, and `0,15,30,45 * * * *` work; `0,59 2 * * *` is rejected even though that particular daily schedule is infrequent.

Railway skips overlap; it does not queue or replay the missed run. The application owns deadline, retry, alerting, and idempotence policies. Give scheduled backup and cleanup executables narrow runtime credentials, not the Railway management token.
