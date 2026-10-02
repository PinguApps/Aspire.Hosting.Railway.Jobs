# Configuration

Both publish methods accept `RailwayJobOptions`; exported TypeScript methods accept `RailwayJobOptionsDto`.

| Option | Default | Meaning |
|---|---|---|
| `ServiceName` | Aspire resource name | Remote service identity |
| `OwnershipMode` | CreateOrAdopt | Create/adopt only after shared ownership checks |
| `ExistingServiceId` | None | Recorded service identity for explicit adoption |
| `Image` | Existing immutable image binding | Complete `registry/image@sha256:<64 lowercase hex>` reference |
| `StartCommand` | Image command | Railway command override |
| `Timeout` / `timeoutSeconds` | 10 minutes / 600 | Positive publication/completion bound, at most 24 hours |
| `Region` | Railway default | Region ID |
| `MemoryGB` / `memoryGB` | Railway default | Positive memory limit |
| `VCpus` / `vCpus` | Railway default | Positive CPU limit |
| `DeploymentDependsOn` | Empty | C# resource deployment prerequisites |

Restart policy is always `NEVER`, with no automatic retries. Finite jobs require confirmed completion; scheduled jobs are published without waiting for their next scheduled execution. Workload environment is taken from normal `.WithEnvironment(...)` and `.WithReference(...)` configuration.

The shared core validates image digests, limits, ownership, credentials, and resource type. Job timeouts and cron syntax are validated before provider mutation.

## UTC cron syntax

Five numeric fields: minute, hour, day of month, month, day of week (0 is Sunday). Supports `*`, comma lists, inclusive ranges, and positive steps on wildcard/range fields. Names, timezone prefixes, seconds, Sunday `7`, and single-value steps are not supported.

Every selected minute must be at least five minutes from the next, including the hour boundary. This conservative rule guarantees Railway's minimum interval independently of other fields: `*/5 * * * *`, `0 2 * * *`, and `0,15,30,45 * * * *` work; `0,59 2 * * *` is rejected even though that particular daily schedule is infrequent.

Railway skips overlap; it does not queue or replay the missed run. The application owns deadline, retry, alerting, and idempotence policies. Give scheduled backup and cleanup executables narrow runtime credentials, not the Railway management token.
