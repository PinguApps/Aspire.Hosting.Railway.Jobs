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

## Reproduce Railway-owned source builds

Pack core 1.1.0 and Jobs 1.1.0 into the same external feed, then run the same harness with `-SourceBuild`:

```powershell
./eng/Test-LiveRailwayDeployment.ps1 `
  -SourceBuild `
  -PackageFeed '<external package feed>' `
  -ProjectId '<dedicated project ID>' `
  -EnvironmentId '<dedicated environment ID>' `
  -SiteKey '<matching shared marker>' `
  -TokenPath '<local scoped-token file>' `
  -RailwayCommand '<Railway CLI executable>'
```

The checked-in `eng/SourceBuildJobsFixture` contains a .NET job and simple web Dockerfile. The harness copies only these build inputs into an external consumer, uses an isolated package cache, and runs real `aspire deploy`. It repeats successful finite execution without duplicating services, expects nonzero-exit failure and bounded timeout to block downstream deployment, and observes a new successful UTC cron execution after its observation starts. Build arguments bake an execution marker into the image, proving the uploaded Dockerfile built and ran. Public base images require no GHCR token. Omit `-SourceBuild` to retain the existing immutable-image regression path.

Use a dedicated disposable environment: this test creates/services deployments and leaves them available for inspection. Remove only its recorded owned test services when finished. Timeout publication does not terminate a still-running remote process; inspect it before cleanup or retry.

Pass the previously reported external consumer path as `-WorkDirectory` to resume a recorded upload after an interrupted deployment. Each invocation uses a fresh NuGet cache while retaining that AppHost's deployment state. Source deployments are identified by their exact Railway deployment ID, upload request, and build fingerprint; a provider image digest is optional because Railway can omit it for a successful cached finite build.

## Railway-owned source-build verification — 10 October 2026

The complete `-SourceBuild` harness exited zero against packed unpublished core/Jobs 1.1.0, Aspire 13.6.0, .NET 10, and Railway CLI 5.63.1. It used a dedicated disposable project `ad6fbd0c-634e-49dc-b1b0-e346beaaba6e`, environment `836fd848-5ae9-4f90-bb46-527a5622d6b9`, and an environment-scoped project token. No GHCR token, Docker registry login, or source project reference replaced the packages under test.

| Case | Recorded result |
|---|---|
| Source finite success | Deployment `cbe00c3c-3729-429e-89fe-496f573427d7`: `SUCCESS`, stopped, every instance `EXITED`; build-argument proof and success log markers present |
| Fresh finite replay | Deployment `63b34741-538a-4cfc-af1a-5c6ff73474f7`: successful exit again; job, web, and cron service IDs unchanged |
| Exit 7 | Deployment `a2f16bbd-6d48-468a-8657-123285f9dff0`: `CRASHED`, actual failure marker, no downstream web deployment |
| 120-second deadline | Deployment `f5de3d0a-b9d8-4e37-a476-a8f954c7f0d4`: explicit completion-deadline failure, actual long-running process marker, no downstream web deployment |
| Independent UTC scheduler | Deployment `edd1908f-ac1a-4409-9cc5-9b977497498d`: successful stopped/`EXITED` execution with new marker `2026-10-10T21:55:49.877477990Z`, after observation started |

The source-built dependent web returned HTTP 200 with `PIN646_JOBS_READY`. Finite restart policy, source binding, 250MB/0.5 CPU and AMS placement round-tripped. The recorded job service was `b28195ae-10fc-48bd-8d0e-c4b2da446bcb`, web `c46adeb2-cb72-4fae-be96-c98f0b213354`, and cron `2b82332b-caff-4677-9ad0-6f450f90d279`.

Real execution exposed two provider behaviors now covered by the core: source Dockerfile metadata can materialize after the upload is accepted, and a successful cached finite build can omit image-digest metadata. The publisher still requires exact deployment scope, request marker, upload message, requested build settings and successful process exit. Resuming recorded requests after the fixes retained service identity and completed without a duplicate upload for the pending operation.

The complete default image harness then exited zero from a fresh consumer against the same packed packages. Switching the owned services back to the immutable public BusyBox image preserved every service ID. Finite success `8fe4c1e8-ffaa-4d74-a377-6e68fabfbb21` and replay `90b572bf-26b5-45aa-b10a-c72f5e5c6b20` both confirmed successful process exit. Failure `6cc20aa3-6def-424d-bde3-94a9fa0b65e2` correctly rejected a `CRASHED` instance despite an outer `SUCCESS` status; timeout `cd46225a-2301-431c-8e01-3cc5b29cfc46` produced the explicit 120-second completion-deadline error. Both blocked downstream deployment. Independent image cron execution `07bdd0ee-87fb-446c-b181-0bb21579dd0c` completed successfully with a new marker `2026-10-10T22:00:57.196944008Z` after observation started. Image digest, NEVER restart, CPU/memory and AMS placement checks passed throughout.

After the core's final config-as-code validation and upload-cleanup changes, another fresh-cache packed replay switched the same services from images back to source builds and passed all 12 pipeline steps. Source finite deployment `da50d575-b304-4149-bf29-6862082aab07` exited successfully with its baked build-argument marker, and the dependent web returned HTTP 200 with `PIN646_JOBS_READY`. All owned service identities remained unchanged. This replay used the exact final implementation pack.

The shared core transport was also verified separately with long-running source-built project/container services after revoking the original upload token. The original credential was rejected; in-place restarts and fresh retained-build redeployments `da46a9f2-ee7d-49db-bd6c-03e064d38a71` and `793a7266-bcef-4dc7-a161-7eb082aabda6` succeeded using independent account management authentication. The new deployments retained their preceding image digests, and both returned HTTP 200 with their expected build/runtime markers at `2026-10-10T22:07:57Z`. No new upload, original deployment token or GitHub PAT was used. This proves shared source-image retention and recovery, rather than claiming a separate Jobs restart test.

After these checks the disposable 10 October project was deleted, its test token revoked and known cached secret parameters removed. The historical deployment IDs above are evidence, not retained live endpoints. External consumer sources and scrubbed logs remain available locally; no credentials are committed.

The bootstrap pins reviewed core source `1292a667c557d344f6eaea57eb0fbaa428653f2d`, including source-build review corrections verified by the core's live harness. Its fresh 1.1.0 pack passed all 37 Jobs contract tests with no skips and the isolated NuGet-backed TypeScript gate, including generated source-build DTOs, type checking, and publish/deploy dependency checks. These checks used new package caches to avoid reusing earlier unpublished 1.1.0 builds; the complete Jobs source/image deployment evidence above remains recorded against the preceding implementation.

## Final packed verification

With the core cron activation fix, a changed cron publication completed from 02:29:53 to 02:30:04 local time (11 seconds), and replay completed in 3 seconds. The publisher accepted scheduled activation rather than waiting for the executable's next scheduled run. The first success deployment was `34e34cad-1eec-40a4-9a7b-d1687207ff3f`; repeated finite execution was `afb9685f-e531-492a-b01b-ae7035f32857`.

The 120-second timeout failed with the explicit completion-deadline error for deployment `1914d148-4b77-4dd4-ad75-1121f751a005`. Its process remained running, and there was no downstream web deployment. Its periodic execution markers distinguish actual long-running work from an image pull or startup delay.

Cron observation requires a new timestamped success marker after observation starts plus successful stopped/EXITED state. Railway can reuse the same deployment and instance IDs across scheduled runs; a new deployment ID is not assumed.

The real scheduler observation passed at `2026-10-02T01:35:58.270269249Z` for deployment `c7372103-90d6-4533-a741-119ddf366508`, followed by successful stopped/EXITED verification. The complete external-consumer script exited zero after all expected success and failure assertions. These runtime results use core source `ba6ddcab7a0667a5d20aebbbaa71c6f7edbc4ef8`; subsequent reviewed source pins are recorded by the bootstrap helper.

## Reviewed provider source revalidation

The 2 October verification pinned reviewed core source `5547a196c626ad018db8d651ac2bbca34314b8d5`. A fresh pinned-source pack, NuGet-backed TypeScript gate and all 30 Jobs contract tests passed again. A separate fresh external consumer using that exact packed core/Jobs combination redeployed finite success with its dependent web, then replayed it with unchanged service IDs. It verified actual successful process exit, immutable image, NEVER restart, 250MB/0.5 CPU and AMS settings; the dependent public web returned HTTP 200 with its expected marker.

Changing the cron runtime binding forced new publication. Both changed activation and replay completed in seconds, independently of the next scheduled executable run. The latest cron deployment is `a1fc8448-f8bb-4931-bcc6-c7c5496daf5d`; repeated finite success is `cda10f3f-6999-4123-9ef7-09aaa9ba14e4`. The earlier full failure/timeout and independent real-scheduler proofs remain applicable; the reviewed provider changes did not alter those job completion contracts.
