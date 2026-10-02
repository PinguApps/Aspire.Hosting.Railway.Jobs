import { createBuilder } from "./.aspire/modules/aspire.mjs";

const builder = await createBuilder();
let migration = await builder.addContainer("migration", "busybox");
let web = await builder.addContainer("web", "busybox");
let backup = await builder.addContainer("backup", "busybox");

if (await builder.executionContext().isPublishMode()) {
  const projectId = await builder.addParameter("railway-project-id");
  const environmentId = await builder.addParameter("railway-environment-id");
  const apiToken = await builder.addParameter("railway-api-token", { secret: true });
  const siteKey = await builder.addParameter("site-key");
  const target = await builder.addRailwayTarget("railway", projectId, environmentId, apiToken, siteKey);

  const image = "busybox@sha256:66a6306db78bf2dbf3487f293aa8d6990d8e506fdffab9cc43fe422becf886e4";
  migration = await migration.publishToRailwayJob(target, {
    serviceName: "migration",
    image,
    startCommand: "sh -c 'echo migration-complete; exit 0'",
    timeoutSeconds: 300,
    region: "europe-west4-drams3a",
    memoryGB: 0.5,
    vCpus: 0.5,
});
web = await web.publishToRailway(target, { image, startCommand: "httpd -f -p 8080", port: 8080 });
web = await web.withRailwayDeploymentDependency(migration);
backup = await backup.publishToRailwayCronJob(target, "*/5 * * * *", {
  serviceName: "backup",
  image,
  startCommand: "sh -c 'echo scheduled-backup-complete; exit 0'",
  timeoutSeconds: 300,
  memoryGB: 0.5,
  vCpus: 0.5,
});

}

const app = await builder.build();
await app.run();
