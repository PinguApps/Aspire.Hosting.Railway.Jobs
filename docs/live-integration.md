# Live integration evidence

Validated on 2 October 2026 with .NET SDK 10.0.401, Aspire CLI/Hosting 13.6.0 and packed Jobs/core NuGet 1.0.0. The consumer is generated in the machine's temporary folder outside this repository, with a fresh isolated NuGet cache. No source project reference replaces the package under test.

Dedicated [PIN-646 Jobs Integration](https://railway.com/project/b1d533e4-2edb-438d-ac46-788955a2353e) project; production environment `b5b7aa70-b1b5-4b6e-8828-cc296a16213b`. Only this dedicated environment was changed. Its shared ownership marker is `pin646-jobs-integration`.

## Retained resources

| Resource | Service ID | Purpose |
|---|---|---|
| job-success | `04bc8723-3271-4a91-8f93-605eb705e157` | Finite migration-like success |
| web-success | `90da4d5c-5ad6-4db1-acf3-7e3d035deb55` | Web deployment gated on finite completion |
| scheduled-backup | `5ff865fd-8632-4ccd-bcb2-543d1fdfb6ff` | Real five-minute UTC scheduler execution |
| job-failure | `14bc5875-3ecc-4ffd-b5b6-af67a4b9fb6c` | Exit 7, downstream web blocked |
| job-timeout | `73c2d142-1e63-43f8-8434-1014eafe8a52` | Deadline exceeded, downstream web blocked |

[Public dependent web](https://web-success-production.up.railway.app) returns `PIN646_JOBS_READY`.

## Verification

The successful workload uses an ordinary `AddProject`, then `PublishToRailwayJob`, then the late `PublishAsDockerFile` annotation. The supplied retained `docker.io/library/busybox@sha256:66a6306db78bf2dbf3487f293aa8d6990d8e506fdffab9cc43fe422becf886e4` image is reused; the actual pipeline contains no image build or push steps. The executable prints a success marker and exits zero. The release gate waits for `SUCCESS`, `deploymentStopped=true`, and every instance `EXITED` before deploying the dependent web service.

An unchanged repeat reused all three successful service identities. The finite executable ran again; its migration-like effects must therefore be safe to repeat. The unchanged long-running web deployment was reused.

The failure executable prints its failure marker and exits 7. The pipeline fails and creates no downstream `web-failure` deployment. Railway can report outer deployment status `SUCCESS` while an instance is `CRASHED`: deployment `00f5a49f-1d90-48f8-b90b-8e26b4581fdd` demonstrated this, and the core correctly rejected it. A later failed execution `70f52e8e-5751-4838-b593-8ff087ff3066` reports `CRASHED` directly. This test verifies process outcome rather than service readiness.

Finite settings round-tripped: `NEVER`, immutable image, configured command, 250,000,000 memory bytes, 0.5 CPU and one AMS replica (`multiRegionConfig.ams`). Runtime environment is limited to workload configuration and ownership metadata; the management token is not an application environment value.

The script retains the generated consumer and its deployment logs for inspection. No credentials or secret values are committed.

## Reproduce

Pack both packages into an external feed, then run:

```powershell
./eng/Test-LiveRailwayDeployment.ps1 `
  -PackageFeed '<external package feed>' `
  -ProjectId '<dedicated project ID>' `
  -EnvironmentId '<dedicated environment ID>' `
  -SiteKey '<matching shared marker>' `
  -TokenPath '<local scoped-token file>'
```

Set `RAILWAY_API_TOKEN` instead of `TokenPath` for the optional workflow. The full verification deploys success twice, expected failure, expected timeout, and observes a later actual scheduler execution. It intentionally leaves artifacts deployed; finite jobs correctly stop after exit. A timeout fails publication without claiming to terminate the remote workload.

## Final packed verification

With the core cron activation fix, a changed cron publication completed from 02:29:53 to 02:30:04 local time (11 seconds), and replay completed in 3 seconds. The publisher accepted scheduled activation rather than waiting for the executable's next scheduled run. The first success deployment was `34e34cad-1eec-40a4-9a7b-d1687207ff3f`; repeated finite execution was `afb9685f-e531-492a-b01b-ae7035f32857`.

The 120-second timeout failed with the explicit completion-deadline error for deployment `1914d148-4b77-4dd4-ad75-1121f751a005`. Its process remained running, and there was no downstream web deployment. Its periodic execution markers distinguish actual long-running work from an image pull or startup delay.

Cron observation requires a new timestamped success marker after observation starts plus successful stopped/EXITED state. Railway can reuse the same deployment and instance IDs across scheduled runs; a new deployment ID is not assumed.

The real scheduler observation passed at `2026-10-02T01:35:58.270269249Z` for deployment `c7372103-90d6-4533-a741-119ddf366508`, followed by successful stopped/EXITED verification. The complete external-consumer script exited zero after all expected success and failure assertions. These runtime results use core source `ba6ddcab7a0667a5d20aebbbaa71c6f7edbc4ef8`; subsequent reviewed source pins are recorded by the bootstrap helper.
