# Deployment behavior

The jobs package configures the shared Railway publisher rather than maintaining its own GraphQL client or deployment engine. Target validation runs before remote mutations. The core records ownership, reuses the same service, reconciles settings, deploys the exact retained image or uploads an explicitly configured Dockerfile build context, and tracks the exact deployment.

Source builds are opt-in through `RailwayJobOptions.Build` (TypeScript `build`). The shared core owns the upload, build, and deployment completion. The finite-job step additionally requires successful process exit; the cron publisher preserves its schedule and no-retry policy. Railway owns the resulting image, so subsequent restarts and cron executions do not depend on deployment-time GitHub credentials.

For finite jobs, the pipeline remains pending while instances are running. Confirmed successful process termination completes the step. Crashed, failed, stopped, or removed execution is not accepted as completed application work. A timeout fails the deployment step. Cancellation and timeout do not guarantee the remote process has stopped; inspect its deployment before retrying.

Dependent web or worker steps must list the job resource as a deployment prerequisite. The failed completion step blocks those steps. Ordinary local `.WaitFor(...)` does not provide this publish-time completion contract.

Repeated deployments reuse infrastructure but may run the finite executable again. Make migrations, seeding, media publishing, and external effects safe to repeat. The package does not undo database changes when an older release image is selected.

Cron settings are reconciled through the same target. A cron executable exits; [Railway's scheduler](https://docs.railway.com/cron-jobs) starts later runs and skips overlap. Runtime deadlines belong inside the executable because Railway's cron settings do not expose a process timeout.
