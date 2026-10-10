# TypeScript example

Run `aspire restore --non-interactive`, `npm ci`, `npm run typecheck`, and `aspire publish --non-interactive --list-steps`. The sample shows transport-safe finite and cron job options. Replace fixture parameters and retained images before live deployment.

The sample includes both retained-image jobs and opt-in source-built jobs with a local Dockerfile. Railway builds the uploaded context for those jobs; the deployment machine needs the Railway CLI. Replace fixture parameters and build inputs before live deployment.

The package dependency is bootstrapped during development until core 1.1.0 is published; see the repository installation guide.
