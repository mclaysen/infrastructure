# Portainer migration: website pilot

## Goal and scope

Move the `mclaysen_website` stack from Portainer to native Docker Compose,
deployed by Ansible. Migrate only the website in this pilot. Keep Portainer,
the Portainer agent, and all other stacks running and managed as they are.

The website's current definition is
[`stacks/mclaysen_website.yml.j2`](stacks/mclaysen_website.yml.j2). It
declares one `server` service, the
`ghcr.io/mclaysen/mclaysen-website:latest` image, a required `NODE_ENV`
variable, port mapping `5001:3000`, and `restart: unless-stopped`.
[`stacks/mclaysen_website.env.j2`](stacks/mclaysen_website.env.j2) sets
`NODE_ENV=production`. The stack declares no volumes or external networks. The
reverse proxy is configured to forward `mclaysen.com` to `192.168.86.202:5001`.

## Current migration status

- The working tree contains a native deployment playbook,
  [`playbooks/process-containers.yml`](playbooks/process-containers.yml), and
  removes the website from the Portainer stack list. These changes have not
  been verified on the host.
- The native playbook now deploys the website, Cloudflare, Homebridge,
  Jellyfin, Jellystat, and Newt unconditionally. It is not imported by the normal
  `container-manager.yml` run, so a regular run will not deploy website
  updates. The preferred ongoing approach is one combined playbook that
  reconciles migrated stacks; document how it will be run.
- Local `docker compose config` validation succeeded with the environment
  template and failed as intended without `NODE_ENV`. The user confirmed the
  host-side Compose file matches the website template and `.env` contains
  `NODE_ENV=production`; the preparation run skipped the deployment task.
  The user later stopped the Portainer stack, observed an HTTP 500, and ran
  the playbook; the site subsequently responded locally and returned HTTP 200
  over HTTPS from an external client. Container labels confirm that the running
  project uses `/opt/compose/mclaysen_website/compose.yml`. The user reports
  that a subsequent native playbook deployment did not restart the container.
  After rerunning the full Portainer playbook, the container still reported the
  native Compose file and working directory. The remaining post-cutover checks
  have not yet been confirmed.
- The native playbook now specifies `root:root` ownership and `0600` mode for
  `.env`, even though the website file contains no secrets. The host's
  permissions have not yet been verified after this change.

The reported running container is `mclaysen_website-server-1` on
`mclaysen_website_default`. Verify these names and the Compose labels before
cutover; do not assume the names alone prove the project identity.

Portainer references for the current endpoint:

- [Website stack](https://container-manager.mclaysen.com/#!/3/docker/stacks/mclaysen_website?id=6&type=2&regular=true&orphaned=false&orphanedRunning=false):
  stack ID `6`, created 2026-05-25 15:28:03 and last updated
  2026-10-24 11:20:02 by `admin`, as reported by Portainer.
- [Containers](https://container-manager.mclaysen.com/#!/3/docker/containers):
  select `mclaysen_website-server-1`.
- [Website network](https://container-manager.mclaysen.com/#!/3/docker/networks/mclaysen_website_default):
  `mclaysen_website_default`.

The container inspection reported on 2026-10-28 confirms:

| Property | Observed value |
| --- | --- |
| Container ID | `3bc952a922d25f9e003befac60a1903043a3398fa24772f668890a801530a404` |
| Created / started | `2026-10-24 11:21:42` / `2026-10-24 11:21:44` (Portainer display) |
| Compose project | `mclaysen_website` |
| Compose service | `server` |
| Image ID | `sha256:98a64b7858ad4a7d440070f5fdca2f0d6acda360d80a73098b74de60973ee5f4` |
| Reported repository digest | `ghcr.io/mclaysen/mclaysen-website@sha256:98a64b7858ad4a7d440070f5fdca2f0d6acda360d80a73098b74de60973ee5f4` |
| Mounts | None reported |
| Environment | `NODE_ENV=production` plus `PATH`, `NODE_VERSION`, and `YARN_VERSION` |
| Restart policy | `unless-stopped` |
| Published port | Container `3000/tcp` on host port `5001`, bound to `0.0.0.0` and `[::]` |
| Network | `mclaysen_website_default`, with aliases `mclaysen_website-server-1` and `server` |

Docker reported the same hash for the local image ID and repository digest;
these are distinct identifiers even when their reported values match. Container
IP addresses and network IDs may change during cutover.

The container inspection is consistent with the website template's image,
environment setting, port mapping, restart policy, and lack of mounts. It also
reports `5001/tcp` as exposed but not published; the published port is
`3000/tcp`. The remaining environment variables and command should be checked
against the image and rendered configuration during validation. The user
reports deploying this container only through the repository's deployment
workflow.

The HTTP baseline from `container-manager` on 2026-10-28 was `200` for both
`http://127.0.0.1:5001/` and `https://mclaysen.com/`. The user also confirmed
that `https://mclaysen.com/` works as expected from an external client.

## Observed Docker volumes

The following volumes were reported on `container-manager` on 2026-10-28:

| Stack or service | Reported named volumes |
| --- | --- |
| Dawarich | `dawarich_dawarich_db_data`, `dawarich_dawarich_public`, `dawarich_dawarich_shared`, `dawarich_dawarich_storage`, `dawarich_dawarich_watched`, `dawarich_photon_data` |
| Immich | `immich_model-cache` |
| Jellyfin | `jellyfin-cache`, `jellyfin-config`, `jellyfin_jellyfin-cache`, `jellyfin_jellyfin-config` |
| Jellystat | `jellystat_jellystat-backup-data`, `jellystat_jellystat-db` |
| Monitoring | `monitoring_stack_alloy_data`, `monitoring_stack_grafana_storage`, `monitoring_stack_loki_data`, `monitoring_stack_prometheus_data` |
| Proton Mail | `protonmail` |

No website-named volume appears in this listing, and inspection confirms that the
running website container has no mounts. Volume names alone do not establish
which volumes are in use. In particular, keep both sets of Jellyfin volumes
until their use has been verified; do not prune or delete volumes as part of
this pilot.

## Observed Docker networks

The following local networks were reported on `container-manager` on
2026-10-28:

| Network | Driver |
| --- | --- |
| `bridge` | bridge |
| `cloudflared_default` | bridge |
| `dawarich_network` | bridge |
| `ghost_network` | bridge |
| `host` | host |
| `immich_immich-network` | bridge |
| `mclaysen_website_default` | bridge |
| `monitoring-network` | bridge |
| `monitoring_stack_monitoring-network` | bridge |
| `none` | null |
| `pangolin_network` | bridge |
| `portainer_network` | bridge |
| `protonmail-network` | bridge |

The website's reported network exists. Verify its Compose labels and the
website container's actual membership during inventory. The similarly named
monitoring networks are distinct; inspect their members and ownership before
any later monitoring migration. Do not remove either network based on its name
alone.

## Observed Compose projects

`docker compose ls` reported these running projects on 2026-10-28:

| Project | Running services | Reported config file |
| --- | ---: | --- |
| `cloudflared` | 1 | `/data/compose/5/docker-compose.yml` |
| `dawarich` | 5 | `/data/compose/11/docker-compose.yml` |
| `ghost` | 2 | `/data/compose/10/docker-compose.yml` |
| `immich` | 4 | `/data/compose/8/docker-compose.yml` |
| `jellyfin` | 1 | `/data/compose/2/docker-compose.yml` |
| `jellystat` | 2 | `/data/compose/3/docker-compose.yml` |
| `mclaysen_website` | 1 | `/data/compose/6/docker-compose.yml` |
| `monitoring_stack` | 7 | `/data/compose/1/docker-compose.yml` |
| `newt` | 1 | `/data/compose/4/docker-compose.yml` |
| `portainer` | 1 | `/opt/portainer/docker-compose.yml` |
| `protonmail_bridge` | 1 | `/data/compose/9/docker-compose.yml` |
| `smarthome` | 1 | `/data/compose/7/docker-compose.yml` |

This confirms the running website's Compose project is named
`mclaysen_website`. Its reported `/data/compose/6/docker-compose.yml` path is
the current Portainer-managed config path, not the proposed native deployment
path. Preserve the existing definition for rollback; do not edit or remove
Portainer's files directly.

## 1. Inventory and prepare

- [ ] Agree on a maintenance window and a rollback decision point; the cutover
  may briefly interrupt the public website.
- [ ] Save the current Portainer stack definition and record its deployment
  settings and image-pull behavior for rollback. Protect any sensitive values
  if they are present.
- [x] On `container-manager`, record the container's Compose project and
  service labels, image ID, published ports, and network:

  ```bash
  docker inspect mclaysen_website-server-1 \
    --format 'project={{ index .Config.Labels "com.docker.compose.project" }} service={{ index .Config.Labels "com.docker.compose.service" }} image_id={{ .Image }}'
  docker port mclaysen_website-server-1
  docker inspect mclaysen_website-server-1 \
    --format '{{json .NetworkSettings.Networks}}'
  ```

- [x] Record the image's repository digest if available. A local image ID is
  not the same thing as a registry digest:

  ```bash
  docker image inspect ghcr.io/mclaysen/mclaysen-website:latest \
    --format 'image_id={{.Id}} repo_digests={{json .RepoDigests}}'
  ```

- [x] Record baseline local and public-URL responses from the Docker host:

  ```bash
  curl -fsS -o /dev/null -w 'local HTTP %{http_code}\n' http://127.0.0.1:5001/
  curl -fsS -o /dev/null -w 'public HTTP %{http_code}\n' https://mclaysen.com/
  ```

- [x] Check `https://mclaysen.com/` from an external client and confirm the
  website works as expected.
- [x] Inspect the running container's mounts and configuration. It has no
  mounts, and its observed settings are consistent with the template as noted
  above. Avoid publishing full inspect output if it contains secrets.

## 2. Build and validate the native deployment

- [x] Add an Ansible playbook that prepares the website Compose file at
  `/opt/compose/mclaysen_website/compose.yml` and can deploy it using
  `community.docker.docker_compose_v2`.
- [x] Add a separate `.env` template with `NODE_ENV=production` and configure
  Compose to pass `NODE_ENV: ${NODE_ENV:?NODE_ENV must be set}` to the
  container. Compose uses `.env` for interpolation; it does not automatically
  pass every entry into the container.
- [x] Confirm both host-side files are complete: the Compose file matches the
  template, including `restart: unless-stopped`, and `.env` contains
  `NODE_ENV=production`.
- [x] Confirm the preparation run skipped the native website deployment task.
- [x] Confirm the running website container was not recreated during
  preparation: its reported ID and start time match the earlier inspection.
- [ ] Preserve a working Portainer rollback path. The current working tree
  removes the website from its Portainer stack list; re-enabling that entry
  with the changed template also requires supplying `NODE_ENV`.
- [x] Configure the website `.env` template task with `root:root` ownership,
  mode `0600`, and `no_log: true`. Use the same ownership and mode for all
  rendered stack `.env` files, whether or not they contain secrets.
- [ ] Run the updated preparation playbook and verify the host file's ownership
  and permissions without displaying its contents:

  ```bash
  sudo stat -c '%U:%G %a %n' /opt/compose/mclaysen_website/.env
  ```

  Expected: `root:root 600 /opt/compose/mclaysen_website/.env`.
- [ ] For secret-bearing stacks, render Vault-backed values with
  `no_log: true` and avoid logging resolved configuration. The rendered host
  files still contain plaintext secrets.
- [x] Explicitly set the Compose project name to the verified existing project
  name, `mclaysen_website`, regardless of the directory name.
- [ ] Preserve the current service, port, network identity, environment,
  restart policy, and image behavior. Do not introduce a pull of a newer
  `latest` image during cutover unless explicitly intended. Record the current
  image so rollback can use the same release.
- [x] Use a combined native playbook that reconciles migrated stacks. The
  website deploys on each run; Compose may recreate it if its configuration
  or image changes. Ansible check mode alone does not create rendered files or
  prove they are valid.
- [x] Validate the source Compose and environment templates locally: they
  resolve `NODE_ENV` to `production` and fail when it is missing.
- [ ] On the host, validate the staged Compose configuration with the intended
  project name:

  ```bash
  sudo docker compose -p mclaysen_website \
    -f /opt/compose/mclaysen_website/compose.yml config
  ```

- [ ] Compare the rendered configuration with the live service and saved
  Portainer definition. Confirm that the website needs no Portainer-supplied
  environment variables or other configuration missing from the template, and
  that `NODE_ENV` resolves to `production`. Check that the inherited shell
  environment does not override the intended `.env` values.
- [x] Remove the website entry from the Portainer deployment list in the
  working tree; leave the other stack entries intact.
- [x] Rerun the Portainer playbook and confirm the running website still reports
  the native Compose file and working directory.
- [ ] Confirm the existing Portainer stack record remains available for rollback.
- [ ] Choose and document how native website updates will be deployed after
  cutover. The native playbook is not currently imported by
  [`container-manager.yml`](../container-manager.yml), and its deployment task
  is disabled by default.
- [ ] Document and test the rollback sequence before cutover, including how to
  re-enable the old deployment path and which image to use.

## 3. Cut over and verify

- [ ] Confirm the native configuration is validated and the Portainer
  automation will not redeploy the website.
- [x] Stop the website stack in Portainer. The user observed an HTTP 500 after
  stopping it.
- [x] Confirm the running container uses the native Compose project. Inspection
  reports project `mclaysen_website`, config
  `/opt/compose/mclaysen_website/compose.yml`, and working directory
  `/opt/compose/mclaysen_website`.
- [ ] Verify the expected container is running, attached to the expected
  network, and using the expected image ID. Inspect its logs for errors.
- [x] Check local HTTP on port `5001` and the public
  `https://mclaysen.com/` response against the baseline. The local response
  contained website HTML, and the external HTTPS check returned HTTP 200; HTTP
  redirected to HTTPS with status 307.
- [ ] Verify representative website content and functionality through the
  public URL, not just the HTTP status.
- [x] Run the native deployment again and confirm it does not unnecessarily
  restart or recreate the website container.
- [ ] Verify that a normal full [`container-manager.yml`](../container-manager.yml)
  run does not take ownership back through Portainer; the Portainer playbook
  itself has been rerun successfully.
- [ ] Observe the website for an agreed period and, when practical, confirm
  recovery after a host or Docker restart.

## 4. Rollback if needed

- [ ] Stop the native website project without removing unrelated resources.
- [ ] Restore the saved Portainer definition and deployment settings, including
  the recorded image release, and re-enable its deployment automation.
- [ ] Redeploy the website through Portainer and check both the local and public
  HTTP endpoints. Confirm the original container/project is healthy.

## 5. Retire the website's Portainer ownership

- [ ] After the observation period, confirm the website entry remains absent
  from Portainer deployment automation and the native playbook is its sole
  deployment owner.
- [ ] Determine a safe way to retire the Portainer stack record for the
  installed Portainer version. Deleting a stack may stop or remove its live
  Compose resources, even when native Compose now manages the same project.
  Do not delete it until the behavior and recovery plan are verified; retaining
  an unused record is safer than interrupting the website.
- [ ] Confirm the rest of the Portainer-managed stacks remain unchanged.

## Next migration: Cloudflare Tunnel

Migrate only the `cloudflared` stack from Portainer to native Compose. Keep
Portainer and all other stacks, including the native website, unchanged.
The [current template](stacks/cloudflared.yml.j2) defines one
`cloudflare-tunnel` container and no declared volumes. The original
Portainer template rendered the tunnel token directly into the Compose file;
the working-tree changes move it toward a separate `.env`. The reported running image was
`cloudflare/cloudflared:2026.8.1`, and the reported Compose project and network
were `cloudflared` and `cloudflared_default`. Recheck the live state before
cutover. The user identified [router.mclaysen.com](https://router.mclaysen.com/)
as an example of a site dependent on this tunnel.

### 1. Inventory and prepare

- [ ] Identify the tunnel, its routed hostnames and services, any other
  connectors, and the expected impact of a connector restart. Record baseline
  connector status in Cloudflare and externally test representative routes,
  including `https://router.mclaysen.com/`. Choose a maintenance window and
  rollback decision point.
- [ ] Record the running container's project and service labels, image ID,
  repository digest if available, start time, network membership, mounts,
  restart policy, logging configuration, and health status. Confirm these
  match the template and current Portainer stack definition.
- [ ] Save the current Portainer stack definition and deployment settings for
  rollback. The rendered Compose file contains a tunnel token: treat any saved
  copy as a secret, restrict access, and do not paste it into logs or chat.
- [ ] Confirm the token's Vault source and current image version. Avoid
  displaying the token in command output, the process command line, or a
  public repository.
- [ ] Document how the combined native playbook will deploy website and
  Cloudflare updates routinely after cutover, without relying on Portainer.
  A run reconciles migrated stacks and can apply pending changes to them.

### 2. Prepare native Compose

- [x] Add a Cloudflare project to the native deployment playbook at
  `/opt/compose/cloudflared`, explicitly setting the project name to
  `cloudflared`. Host-side deployment remains unverified.
- [x] Configure the environment-file template task for `root:root`, `0600`,
  and `no_log: true`. The user confirmed the host file is `root:root 600`.
- [x] Correct Cloudflare Compose interpolation to use `:?` and validate locally
  with a dummy token; the configuration fails when the token is missing.
- [x] Confirm the host-side Compose file matches the intended template. The
  user showed `/opt/compose/cloudflared/compose.yml` with image
  `cloudflare/cloudflared:2026.8.1`, the corrected `:?` interpolation, and the
  health-check `start_period: 10s`.
- [ ] Confirm the actual token passes to the container without exposing it.
- [ ] Confirm the environment template uses the Vault variable containing the
  existing tunnel token. It currently references `cloudflared_tunnel_token`;
  the original Portainer template referenced `cloudflare_tunnel_token`.
  Account for Compose `.env` escaping and shell-variable precedence without
  exposing the token. The user confirmed that a token value is present in the
  host `.env`; its identity and effective value have not yet been verified.
- [ ] Preserve the verified service and container names, hostname, pinned image
  version, command, restart policy, network, logging options, and health-check
  settings. Do not pull a different image during cutover unless intended.
- [ ] Document the combined playbook's behavior: the website, Cloudflare,
  Homebridge, Jellyfin, and Jellystat currently deploy on every run. Rendering
  the stacks together makes deployment dependent on all their environment
  templates. For future migrations, keep the new stack's activation gated
  until cutover. Directory creation no longer recursively changes `/opt/compose`
  permissions.
- [x] Remove Cloudflare from the Portainer deployment list in the working tree,
  so that playbook no longer deploys the modified shared template.
- [ ] Preserve a working Portainer rollback path: restoring its stack entry
  with the modified template requires a compatible token configuration.
- [x] Verify the host `.env` file is `root:root 600` without displaying its
  contents:

  ```bash
  sudo stat -c '%U:%G %a %n' /opt/compose/cloudflared/.env
  ```

- [ ] Validate the staged host configuration with the intended project name
  and environment file without printing resolved secrets:

  ```bash
  sudo docker compose -p cloudflared \
    -f /opt/compose/cloudflared/compose.yml config --quiet
  ```

  Do not share full `docker compose config` or container inspection output:
  it can contain the token.
- [ ] Compare the non-secret native settings with the live container and saved
  Portainer definition. Verify the token is passed correctly without exposing
  its value. Record and test the rollback procedure before cutover.

### 3. Cut over and verify

- **Current status:** The user stopped the Portainer Cloudflare stack and
  observed Cloudflare error 1033 at `router.mclaysen.com`. The subsequent
  Ansible run reported the native Cloudflare deployment task as changed and
  completed without failure. The user reports that the sites are reachable
  again. Container labels confirm project `cloudflared` uses
  `/opt/compose/cloudflared/compose.yml` and working directory
  `/opt/compose/cloudflared`; those labels remained unchanged after the user
  reran the Portainer playbook, and the user reports the site is responding.
  Connector status in Cloudflare remains unconfirmed.
- [ ] Verify the working-tree removal of `cloudflared` from Portainer
  automation is in effect at cutover, while retaining the Portainer stack
  record and a working rollback configuration. Ensure no other stack's
  deployment path changes.
- [x] Stop the Portainer-managed Cloudflare stack; error 1033 was observed
  afterward on `router.mclaysen.com`.
- [x] Activate the native project: the Ansible Cloudflare deployment task
  reported `changed` with no failures.
- [x] Confirm sites are reachable again after native deployment.
- [x] Confirm Compose labels point to project `cloudflared`, config
  `/opt/compose/cloudflared/compose.yml`, and working directory
  `/opt/compose/cloudflared`.
- [x] Rerun the Portainer playbook and confirm the Cloudflare container still
  reports the native Compose file and working directory.
- [ ] Confirm the running container is attached to the expected network and
  uses the intended image. Inspect logs carefully without exposing credentials.
- [ ] Confirm the connector is connected in Cloudflare and check representative
  routed services, including `https://router.mclaysen.com/`, against the
  baseline. The user reports that sites are reachable again. The existing
  `cloudflared --version` health check does **not** prove the tunnel is
  connected.
- [ ] Rerun the native deployment and confirm it converges without unnecessary
  recreation. Confirm the website remains healthy.
- [ ] Observe the tunnel for an agreed period and verify recovery after a
  planned host or Docker restart when practical.

### 4. Rollback and cleanup

- [ ] If verification fails, stop the native Cloudflare project, restore the
  saved Portainer definition, token configuration, image and automation, then
  redeploy through Portainer. Verify connector status and external routes.
- [ ] Keep the Portainer stack record during the observation period. Before
  removing it, verify whether the installed Portainer version can remove only
  the record without undeploying resources; do not assume normal stack removal
  is safe for the native project.
- [ ] Confirm all other stacks and routes remain unchanged. Preserve protected
  rollback materials only as long as needed.

## Next migration: Homebridge

Migrate the `smarthome` Homebridge stack to the combined native Compose
playbook. The [current template](stacks/smarthome.yml.j2) defines one
`homebridge` service with host networking, `restart: always`, and a bind mount
for persistent configuration. The configured image is
`homebridge/homebridge:2026-06-24`; the configuration path is defined by
`homebridge_config_dir` in
[`vars.yml`](../group_vars/portainer_managers/vars.yml). The reported running
container was `smarthome-homebridge-1`. Verify the live settings before
cutover.

The user's container inspection on 2026-10-29 reported project `smarthome`,
service `homebridge`, container `smarthome-homebridge-1`, and Portainer config
path `/data/compose/7/docker-compose.yml`. It was running
`homebridge/homebridge:2026-06-24`, image ID
`sha256:4a3964f08b837ac2beab1ce99d7d22d4320d1280c5381242628c88c2a61f0e45`,
started `2026-10-30T02:03:50.21553484Z`, with no Docker health check.
The reported repository digest is
`homebridge/homebridge@sha256:4a3964f08b837ac2beab1ce99d7d22d4320d1280c5381242628c88c2a61f0e45`.
The container uses host networking, `restart: always`, and `json-file` logging
with `max-size=10mb` and `max-file=1`. Its writable bind mount is
`/home/ansible/docker/smarthome/homebridge:/homebridge`.
The reported host directory is owned by `root:root` with mode `0755`, and its
top-level files were also shown as `root:root` and mode `0755`. Some may contain
credentials or pairing information; avoid publishing their contents and review
access separately without changing permissions blindly during migration.

### 1. Inventory, backup, and baseline

- [ ] Choose a maintenance window and identify smart-home integrations that
  will be interrupted. Record how to test the Homebridge UI and at least one
  representative accessory or integration before and after the migration.
- [x] Record the live container's Compose project and service labels, image
  ID, start time, status, and health status; confirm the expected project,
  service, and container names.
- [x] Record the available repository digest, network mode, mounts, restart
  policy, and logging settings.
- [x] Resolve the actual host path mounted at `/homebridge` and verify it
  matches the configured `homebridge_config_dir`. Record its ownership and
  permissions. Do not paste configuration, credentials, or pairing data into
  chat or logs.
- [x] Confirm the user's backup readiness for cutover. The user reports that
  the full container-manager VM is backed up and is comfortable proceeding;
  Homebridge directory coverage and restorability were not independently
  verified.
- [ ] Save the current Portainer stack definition and deployment settings for
  rollback, including the image version and actual mount path.

### 2. Prepare native Compose

- [x] Add Homebridge Compose and environment-file preparation to the combined
  playbook under `/opt/compose/smarthome`.
- [x] Add a gated `community.docker.docker_compose_v2` deployment task with the
  explicit project name `smarthome`.
- [x] Add a separate, initially empty `.env` template and configure its
  rendering as `root:root` / `0600`. Pass any future container values
  explicitly; Compose interpolation alone does not place `.env` values in the
  container.
- [x] Verify the rendered host `.env` file is empty and owned by `root:root`
  with mode `0600`.
- [x] Inspect the host Compose file and confirm the image, host networking,
  bind mount, restart policy, and logging settings match the intended template.
- [ ] Preserve the image version, service and container identity, host
  networking, `/homebridge` bind mount, directory ownership, restart policy,
  and logging settings. Check the template's declared `smarthome-network`
  against the live stack; host networking should not be replaced with a bridge
  network. Avoid pulling a different image during cutover unless intended.
- [ ] Keep activation of the new Homebridge project gated until cutover.
  Existing migrated stacks can continue to be reconciled by the combined
  playbook. Confirm preparation does not stop or recreate Homebridge.
- [x] Validate the staged host configuration with the intended project name,
  using `sudo` to read the restricted `.env` file. The user ran the command
  with no reported errors:

  ```bash
  sudo docker compose -p smarthome \
    -f /opt/compose/smarthome/compose.yml config --quiet
  ```

- [x] Verify the environment file reports `root:root 600`:

  ```bash
  sudo stat -c '%U:%G %a %n' /opt/compose/smarthome/.env
  ```

- [ ] Compare the resolved non-secret settings with the live container and
  saved Portainer definition without exposing credentials.
- [ ] Disable the `smarthome` entry in Portainer deployment automation at
  cutover and retain a working rollback path. Confirm directory preparation
  remains available if it is still required by the native workflow.

### 3. Cut over and verify

- **Status:** The user considers the Homebridge migration complete after
  starting it through Ansible, logging in, and confirming the native Compose
  labels. Unchecked verification items below have not been independently
  confirmed.
- [x] Stop the Homebridge Portainer stack and start the native project through
  Ansible. The user reports that Homebridge is working.
- [x] Confirm the running container's Compose labels report project
  `smarthome`, config `/opt/compose/smarthome/compose.yml`, and working
  directory `/opt/compose/smarthome`.
- [ ] Verify the running container's image, host network, mount path, and
  restart policy. Inspect logs without exposing secrets.
- [x] Confirm the Homebridge UI loads and login works after cutover.
- [ ] Confirm existing accessories and pairings remain present and a
  representative accessory or integration works. Investigate before making
  pairing or configuration changes if they do not.
- [ ] Rerun the combined native playbook and confirm Homebridge is not
  unnecessarily recreated. Rerun Portainer automation and confirm it does not
  take ownership back. Verify the website and Cloudflare routes remain healthy.
- [ ] Observe Homebridge for an agreed period and check recovery after a
  planned host or Docker restart when practical.

### 4. Rollback and cleanup

- [ ] If verification fails, stop the native Homebridge project and restore
  the saved Portainer definition, image, mount path, and automation. Do not
  overwrite the live configuration with the backup unless recovery requires
  it; preserve any changes made since the backup.
- [ ] Confirm the UI and representative integration work after rollback.
- [ ] Keep the Portainer stack record during the observation period. Before
  removing it, verify whether the installed Portainer version can remove only
  the record without undeploying resources used by the native project.

## Jellyfin migration

Migrate only the `jellyfin` stack to the combined Ansible-managed native
Compose workflow. The [current template](stacks/jellyfin.yml.j2) defines one
container, two named volumes, two media bind mounts, and the external
`pangolin_network`. The previously reported image was
`jellyfin/jellyfin:10.11.8`. Recheck the live container before cutover.

The reported volume inventory contains both `jellyfin-config` /
`jellyfin-cache` and `jellyfin_jellyfin-config` /
`jellyfin_jellyfin-cache`. Inspection identified the prefixed pair as active.
Do not delete either pair; a wrong volume can make Jellyfin appear as a fresh
installation.

The user's container inspection on 2026-10-29 reported project and service
`jellyfin`, Portainer config `/data/compose/2/docker-compose.yml`, image
`jellyfin/jellyfin:10.11.8`, and image ID
`sha256:1694ff069f0c9dafb283c36765175606866769f5d72f2ed56b6a0f1be922fc37`.
Docker reported repository digest
`jellyfin/jellyfin@sha256:1694ff069f0c9dafb283c36765175606866769f5d72f2ed56b6a0f1be922fc37`.
The container started at `2026-10-30T02:04:41.106419158Z`, was running and
healthy, used network mode `pangolin_network`, and had restart policy
`unless-stopped`.

The user's mount inspection identified these active writable mounts:

| Type | Source or volume | Container destination |
| --- | --- | --- |
| Named volume | `jellyfin_jellyfin-config` | `/config` |
| Named volume | `jellyfin_jellyfin-cache` | `/cache` |
| Bind mount | `/mnt/truenas_shares/home` | `/home_videos` |
| Bind mount | `/mnt/truenas_shares/movies` | `/movies` |

Preserve the two active prefixed volumes. The separate `jellyfin-config` and
`jellyfin-cache` volumes were present in the earlier inventory, but their use
has not been established; do not remove them.
Both active volumes use the `local` driver and have Compose project label
`jellyfin`. Their Compose volume labels are `jellyfin-config` and
`jellyfin-cache`, respectively. Retaining those project and logical names
should resolve to the existing prefixed names; validate the rendered
configuration before deployment.
The working-tree template now declares the exact names as Compose-managed
volumes, and the separate Ansible volume task has been removed. Local Compose
configuration validation resolved the expected names; these changes have not
yet been verified on the host. Compose creates a missing volume empty when the
stack starts. It can remove Compose-managed volumes with
`docker compose down --volumes`; do not use that command for this stack.
Jellyfin publishes `8096/tcp` and `7359/udp` on both IPv4 and IPv6, has
supplemental group `3004`, and is attached to `pangolin_network`, a local
bridge network.
The user confirmed both expected NFSv4 mounts:

| Host mountpoint | TrueNAS source |
| --- | --- |
| `/mnt/truenas_shares/home` | `192.168.86.200:/mnt/philbert/media/home_videos` |
| `/mnt/truenas_shares/movies` | `192.168.86.200:/mnt/philbert/media/movies` |

### 1. Inventory, backup, and baseline

- [ ] Choose a maintenance window and record baseline UI access, existing
  users and libraries, and playback of a representative media item.
- [x] Record the container's Compose identity, image ID, start time, network
  mode, restart policy, and health. Run on `container-manager`:

  ```bash
  docker inspect jellyfin \
    --format 'project={{ index .Config.Labels "com.docker.compose.project" }} service={{ index .Config.Labels "com.docker.compose.service" }} config={{ index .Config.Labels "com.docker.compose.project.config_files" }} image={{ .Config.Image }} image_id={{ .Image }} started={{ .State.StartedAt }} status={{ .State.Status }} health={{ if .State.Health }}{{ .State.Health.Status }}{{ else }}none{{ end }} network_mode={{ .HostConfig.NetworkMode }} restart={{ .HostConfig.RestartPolicy.Name }}'
  ```

- [x] Record the image repository digest, if available:

  ```bash
  docker image inspect \
    "$(docker inspect --format '{{.Image}}' jellyfin)" \
    --format 'image_id={{ .Id }} repo_digests={{ json .RepoDigests }}'
  ```

- [x] Identify the **actual mounted volume names** for `/config` and `/cache`
  and the host sources for the media bind mounts:

  ```bash
  docker inspect jellyfin \
    --format '{{ range .Mounts }}type={{ .Type }} name={{ .Name }} source={{ .Source }} destination={{ .Destination }} rw={{ .RW }}{{ "\n" }}{{ end }}'
  ```

- [x] Inspect the active volume names, not guessed names:

  ```bash
  docker volume inspect jellyfin_jellyfin-config jellyfin_jellyfin-cache
  ```

  Volume metadata may reveal host paths; avoid sharing any sensitive
  information.
- [x] Record published ports, supplemental group IDs, and attached networks:

  ```bash
  docker port jellyfin
  docker inspect jellyfin \
    --format 'groups={{ json .HostConfig.GroupAdd }}{{ "\n" }}{{ range $name, $_ := .NetworkSettings.Networks }}network={{ $name }}{{ "\n" }}{{ end }}'
  docker network inspect pangolin_network \
    --format 'name={{ .Name }} driver={{ .Driver }} scope={{ .Scope }}'
  ```

- [x] Verify the actual TrueNAS NFS mounts are present at the expected exact
  mountpoints, not merely empty local directories:

  ```bash
  findmnt -rn -M /mnt/truenas_shares/home -o TARGET,SOURCE,FSTYPE
  findmnt -rn -M /mnt/truenas_shares/movies -o TARGET,SOURCE,FSTYPE
  ```

  The reported sources match the configured shares. A missing mount must block
  cutover rather than cause an empty library scan. The existing NFS setup lives in
  [`portainer_setup.yml`](tasks/portainer_setup.yml); preserve it when
  Portainer is eventually removed.
- [x] Verify Jellyfin can read and play media from the mounted shares. The user
  reports being able to view media before cutover.
- [x] Confirm backup readiness for the active Jellyfin configuration volume
  and save the Portainer stack definition and deployment settings. The user
  confirmed a recent recoverable backup covers the config volume and that the
  Portainer definition is saved. The recorded rollback image is
  `jellyfin/jellyfin:10.11.8`.
- [ ] Confirm backup coverage for any required NFS media and storage outside
  the VM; those may require separate backups.

### 2. Prepare native Compose

- [x] Add Jellyfin to the combined Ansible playbook at
  `/opt/compose/jellyfin`, with project name `jellyfin`. Activation was gated
  during cutover; the working-tree playbook has since removed that gate and
  now reconciles Jellyfin on every run.
- [x] Add an empty `.env` template and configure its rendering as `root:root` /
  `0600`. Host-side permissions were verified as `root:root 600`. Supply any
  future container environment variables explicitly; Compose `.env`
  interpolation alone does not inject them into the container.
- [x] Declare the **exact active volume names** in the template. The original
  external declarations and Ansible volume task were subsequently replaced in
  the working tree by Compose-managed volumes. Local Compose configuration
  validation resolves the expected names.
- [ ] Render and validate the updated Compose-managed volume configuration on
  the host, then verify the existing volumes and Jellyfin data are preserved
  after the next Ansible deployment.
- [x] Confirm the active volumes exist and Jellyfin can use their data. The
  preparation run found both volumes, and the user confirmed Jellyfin and media
  work after cutover, before the latest volume-management change. On a fresh
  install or after data loss, restore existing configuration data before
  starting Jellyfin; Compose creates missing volumes empty.
- [ ] Preserve the verified image, `jellyfin` service and container identity,
  `pangolin_network` as an existing external network, supplemental fileshare
  group, `8096/tcp` and `7359/udp` mappings, media mount sources and targets,
  and restart policy. Compare against the live container rather than relying
  on the template alone.
- [x] Render the staged configuration without activating Jellyfin and validate
  it on the host:

  ```bash
  sudo docker compose -p jellyfin \
    -f /opt/compose/jellyfin/compose.yml config --quiet
  sudo stat -c '%U:%G %a %n' /opt/compose/jellyfin/.env
  ```

  The `.env` file should report `root:root 600`. Compare the rendered
  non-secret settings and resolved volume names with the inventory. Do not
  share resolved configuration if it contains secrets. Host validation passed,
  permissions were `root:root 600`, and the resolved settings matched the
  recorded image, mounts, volume names, network, ports, group, and restart
  policy.
- [x] Add an Ansible guard that checks each Jellyfin mountpoint, expected NFS
  source, and filesystem type before deployment. The guard now runs on every
  playbook run; a failure also prevents the later Jellystat task from running.
- [x] Fix and validate the mount guard in Ansible check mode. The read-only
  `findmnt` task now runs in check mode, and both expected mounts passed on
  `container-manager`.
- [x] Exercise the guard's failure behavior safely: an intentionally incorrect
  expected home-videos source caused the assertion to fail before Jellyfin
  deployment. A missing-mount case was not separately tested. The guard checks
  mount metadata at Ansible deployment time, not NAS responsiveness or
  Jellyfin's automatic restart after a host reboot.
- [x] Add native Ansible provisioning for the external `pangolin_network`;
  the preparation run reported the existing network unchanged.
- [ ] Document or provision the NFS mounts for a fresh installation. The
  existing mount tasks are in the Portainer workflow; the native playbook
  checks but does not create them.
- [ ] Save and document an Ansible-based rollback path. At cutover, remove
  Jellyfin from the Portainer deployment list while preserving its stack record
  and saved definition. Jellyfin has been removed from the list in the
  working tree; verify the intended automation uses that change. Do not
  delete the Portainer stack: removal may affect the running native project.

### 3. Cut over and verify

- [x] Deploy Jellyfin using the combined **Ansible playbook**. Inspection
  showed the native Compose file, expected image, volumes and bind mounts;
  the container subsequently reported healthy. The deployment was gated at
  that time; the working-tree task no longer uses `start_containers`.
- [ ] Confirm the Portainer-managed Jellyfin stack was stopped without
  removing volumes or media, and document the full rollback procedure.
- [x] Confirm the running container uses the native Compose file and the same
  mounted volumes, NFS paths, and image:

  ```bash
  docker inspect jellyfin \
    --format 'project={{ index .Config.Labels "com.docker.compose.project" }} config={{ index .Config.Labels "com.docker.compose.project.config_files" }} image_id={{ .Image }}'
  docker inspect jellyfin \
    --format '{{ range .Mounts }}type={{ .Type }} name={{ .Name }} source={{ .Source }} destination={{ .Destination }} rw={{ .RW }}{{ "\n" }}{{ end }}'
  ```

  The reported config label points to `/opt/compose/jellyfin/compose.yml`.
- [ ] Confirm the running container's ports, groups, and network after cutover
  with `docker port` and `docker inspect`.
- [x] Verify the UI, libraries, and media playback. The user reports Jellyfin
  and media work after cutover.
- [ ] Confirm existing users and external access against the baseline. Do not
  run a library scan against missing mounts.
- [x] Check Jellyfin's container ID and start time across the requested repeat
  Ansible deployment. Both reported values were unchanged; playbook output was
  not provided.
- [ ] Rerun Portainer automation and confirm it does not take ownership back.
  Verify the previously migrated stacks remain healthy.
- [ ] Observe Jellyfin for an agreed period and verify recovery after a planned
  host or Docker restart when practical.

### 4. Rollback and cleanup

- [ ] If verification fails, stop the native Jellyfin project and use the saved
  configuration and verified Ansible deployment workflow to restore service.
  Preserve the active volumes and media mounts; do not run volume-removal or
  prune commands. Confirm the UI and playback after rollback.
- [ ] Retain the Portainer stack record until safe record-only removal has
  been verified for the installed version. Keep both sets of similarly named
  Jellyfin volumes until their use is understood and a separate cleanup is
  planned.

## Next migration: Jellystat

Migrate only Jellystat to the combined Ansible-managed Compose workflow. The
[current template](stacks/jellystat.yml.j2) defines an application container
and a PostgreSQL container, two named volumes, and the external
`pangolin_network`. The application image now uses `jellystat_version`, and
PostgreSQL uses `postgres:15.2`. The live image references and network were
confirmed during the inventory below; the remaining template settings still
need comparison with live state.

The working-tree playbook now renders the Compose template, a non-secret
interpolation `.env`, and separate raw PostgreSQL-password and JWT-secret
files. The conflicting secret interpolation entries have been removed.
secret validation runs unconditionally before those files are rendered; the
user chose to retain this fail-fast behavior. Jellystat was gated during
preparation, but the gate has since been removed from the working-tree
playbook; Jellystat now reconciles on every run. Do not print resolved
configuration containing secrets or share container environment variables.
Preserve the existing secrets during migration.

### 1. Inventory, backup, and baseline

- [ ] Choose a maintenance window and verify Jellystat UI access, existing
  statistics, and its connection to Jellyfin. Record the baseline without
  sharing credentials or personal viewing data.
  The user reports that the UI works through both the external address and
  direct port 3000, and that Jellystat is connected to Jellyfin. The
  maintenance window has not yet been confirmed.
- [x] Record the live Compose identity, image, status, and restart policy for
  both containers on `container-manager`:

  ```bash
  docker inspect jellystat jellystat-db \
    --format 'name={{ .Name }} project={{ index .Config.Labels "com.docker.compose.project" }} service={{ index .Config.Labels "com.docker.compose.service" }} config={{ index .Config.Labels "com.docker.compose.project.config_files" }} image={{ .Config.Image }} image_id={{ .Image }} started={{ .State.StartedAt }} status={{ .State.Status }} health={{ if .State.Health }}{{ .State.Health.Status }}{{ else }}none{{ end }} restart={{ .HostConfig.RestartPolicy.Name }}'
  ```

  On 2026-10-30, both containers reported project `jellystat`, their respective
  service names, config `/data/compose/3/docker-compose.yml`, status `running`,
  and restart policy `unless-stopped`. Jellystat reported `healthy`; PostgreSQL
  had no Docker health check. Their image references were
  `cyfershepard/jellystat:latest` and `postgres:15.2`, respectively. Their
  reported start times were `2026-10-30T03:22:46.134780215Z` and
  `2026-10-30T03:22:42.961905804Z`, respectively.
- [x] Record the image IDs and available repository digests, especially for
  the mutable `latest` tag:

  ```bash
  for container in jellystat jellystat-db; do
    docker image inspect \
      "$(docker inspect --format '{{.Image}}' "$container")" \
      --format 'image_id={{ .Id }} repo_digests={{ json .RepoDigests }}'
  done
  ```

  The reported image IDs and repository digests were:

  | Container | Image ID | Repository digest |
  | --- | --- | --- |
  | `jellystat` | `sha256:e61c759ec706da378bc8374e797da1dfd298ab30f804cefd82d192c301a888c7` | `cyfershepard/jellystat@sha256:e61c759ec706da378bc8374e797da1dfd298ab30f804cefd82d192c301a888c7` |
  | `jellystat-db` | `sha256:78a275d4c891f7b3a33d3f1a78eda9f1d744954d9e20122bfdc97cdda25cddaf` | `postgres@sha256:78a275d4c891f7b3a33d3f1a78eda9f1d744954d9e20122bfdc97cdda25cddaf` |

- [x] Identify the actual volume names and mount destinations. In particular,
  preserve the live PostgreSQL data volume and Jellystat backup-data volume;
  do not assume their Docker names from the template.

  ```bash
  docker inspect jellystat jellystat-db \
    --format '{{ .Name }}{{ "\n" }}{{ range .Mounts }}type={{ .Type }} name={{ .Name }} source={{ .Source }} destination={{ .Destination }} rw={{ .RW }}{{ "\n" }}{{ end }}'
  ```

  Inspect each discovered volume with `docker volume inspect <volume-name>`
  and record its driver and metadata. Do not remove any volumes.
  `jellystat_jellystat-backup-data` mounts read-write at
  `/app/backend/backup-data`; `jellystat_jellystat-db` mounts read-write at
  `/var/lib/postgresql/data`. Both use the local driver and scope, have no
  custom driver options, and have Compose labels for project `jellystat`.
  Both paths reside on `/dev/vda4`.
- [x] Record published ports and network membership:

  ```bash
  docker port jellystat
  docker port jellystat-db
  docker inspect jellystat jellystat-db \
    --format '{{ .Name }}{{ range $name, $_ := .NetworkSettings.Networks }} network={{ $name }}{{ end }}'
  docker network inspect pangolin_network \
    --format 'name={{ .Name }} driver={{ .Driver }} scope={{ .Scope }}'
  ```

  Jellystat publishes TCP port 3000 on all IPv4 and IPv6 interfaces;
  PostgreSQL has no published host port. Both containers use
  `pangolin_network`, a local bridge network.
- [x] Save the Portainer stack definition and deployment settings securely.
  The user confirmed these are saved.
- [x] Confirm any referenced environment files and secrets required for
  recovery are available securely. The user confirmed the saved definition
  and required files and secrets are accessible. This does not verify that
  rollback works or that the old Compose interpolation supplies the current
  database password. Do not share credentials.
- [x] Record the backup decision. The user declined a separate Jellystat
  backup. A 2026-10-30 container-manager VM backup was reported successful;
  its recovery has not been tested, and PostgreSQL was running during the
  backup. Do not treat it as a verified database-consistent backup; data may
  be unrecoverable. The user accepted this recovery risk and chose to
  continue. A read-only database inventory listed `postgres`, `jellystat`, and
  `jfstat`; the backup-data volume reported zero disk usage. Preserve both
  existing volumes.

### 2. Prepare native Compose

- [x] Add Jellystat preparation and a gated deployment to the combined
  playbook using the observed Compose project name. A preparation run rendered
  the Jellystat Compose file, completed the environment-file task, and skipped
  Jellystat deployment. The play recap reported zero failures; the other stack
  deployment tasks reported `ok`. The gate was subsequently removed, so
  Jellystat now reconciles on every run. Secret validation also runs on every
  run.
- [x] Preserve the observed PostgreSQL and Jellystat images and data; avoid a
  PostgreSQL major-version upgrade during migration. Decide how to pin the
  Jellystat image so the mutable `latest` tag does not unexpectedly change it.
  The working tree sets `jellystat_version` to `1.1.12` plus the recorded
  digest; host Compose configuration reports that reference and
  `postgres:15.2`. Local image inspection on the host resolved both references
  to the original image IDs. After cutover, both image IDs and the database
  inventory matched, and the user confirmed the expected statistics remain.
- [x] Preserve the observed volume names, network, ports, restart policies,
  PostgreSQL settings, database password, JWT secret, and Jellyfin connection.
  The reported native containers use the recorded volumes, network, ports, and
  restart policies; the database accepts the configured password and the user
  confirmed the Jellyfin connection. The JWT secret matches the staged file.
  Compose creates missing volumes empty: restore existing data before starting
  services on a rebuilt host. Do not use `docker compose down --volumes`.
- [x] Remove the conflicting secret interpolation entries and pass secrets
  through raw service env files. Local Compose configuration tests using
  synthetic values confirmed that dollar signs, quotes, backslashes, hashes,
  equals signs, and surrounding spaces were preserved, even when conflicting
  secret variables were present in the shell. The database received the
  password but not the JWT secret. These tests did not start containers or
  verify the actual secrets.
- [x] Validate that the secret values are nonempty and contain no line breaks
  before rendering the raw files. The assertion uses `no_log: true`, rejects
  invalid values in local synthetic tests, and passed for both secrets during
  the reported host run before the environment-file task.
- [x] Decide how Jellystat secret validation affects other stacks. The user
  chose to retain the current fail-fast behavior: validation runs even when
  Jellystat deployment is disabled, and failure stops the playbook before the
  other stack deployment tasks.
- [x] Verify the actual secrets match the live stack and the resolved Compose
  configuration without printing them before cutover. The user confirmed the
  staged password and JWT secret matched the then-running stack. A host-side
  comparison confirmed both services received the staged database password,
  Jellystat received the staged JWT secret, and PostgreSQL did not receive
  the JWT secret in the resolved configuration. The playbook configures the
  files as `root:root` / `0600` with `no_log: true`; the host reported
  `root:root 600` for `.env`, `db-secrets.env`, and `jwt-token.env`.
- [x] Recheck the staged and container secret settings after the subsequent
  Vault password change without printing values. Both containers' password
  settings and Jellystat's JWT secret matched the staged files, PostgreSQL
  did not receive the JWT secret, and TCP authentication succeeded.
- [x] Confirm the host's Docker Compose version supports `env_file` with
  `format: raw` (Compose 2.30 or later). Both the `ansible` user and `sudo`
  reported Docker Compose `v5.4.0`.
- [x] Validate the staged host configuration with the intended project name
  using `docker compose config --quiet`; compare the image references, volume
  names and destinations, restart policies, published ports, and network with
  the live inventory without exposing credentials. The host command exited
  successfully with an obsolete `version` warning, and the reported settings
  matched the recorded inventory.
- [x] Confirm the staged non-secret database and timezone settings against
  the live stack without sharing credentials or personal data. The reported
  PostgreSQL user, host, port, and timezone matched the staged configuration.
- [ ] Document an Ansible-based rollback procedure and disable Jellystat in
  Portainer deployment automation at cutover. Retain the old stack record and
  saved definition; do not delete the stack or volumes. Jellystat has already
  been removed from the Portainer deployment list in the working tree. Native
  containers are now present; initial authentication failed, but the
  application later reported healthy and the user confirmed the expected data.

### 3. Cut over and verify

**Authentication incident (service restored):** On 2026-10-30, both
containers reported the native Compose configuration and the previously
recorded image IDs and volume names.
PostgreSQL was running, but Jellystat was restarting after PostgreSQL rejected
authentication for `jellystat`. Investigate without printing secrets, changing
the database password, or removing volumes. The user reports manually stopping
the old stack in the Portainer UI and then running the combined Ansible
playbook directly; the precise container takeover behavior was not verified.
A read-only connection attempt
using the PostgreSQL container's configured password failed authentication;
the user reported that manually entering the password from the staged
`db-secrets.env` at a prompt succeeded. A secret-safe comparison reported that
the application and database container password settings both match that
file. A subsequent prompt-based test against the same `jellystat-db` TCP
endpoint also failed authentication; the endpoint used for the earlier
successful test has not yet been confirmed. A local Unix-socket query as
`jellystat` succeeded without an interactive prompt; its authentication rule
uses `trust`. The reported rules also trust loopback connections but require
`scram-sha-256` for other TCP clients. The `jellystat` role can log in and has
no expiry; its verifier and the server's `password_encryption` setting both
use SCRAM-SHA-256. Do not treat successful socket or loopback access as proof
that the password works over the Docker network. The reason the staged
password differs from the credential accepted by the database remains
unconfirmed; the earlier Portainer template used direct Compose
interpolation, while the native template uses raw env files. The user reports
that the old password contained `$`, making interpolation a possible cause;
the previously effective value has not been independently recovered or
verified. The user authorized a role-password reset but did not complete it;
instead, they changed the password in Vault and reran Ansible. After that run,
the user reported Jellystat running and healthy, PostgreSQL running, zero
container restarts, and a successful TCP query using the database container's
configured password. Follow-up inspection reported the original image IDs,
volume names and volume creation timestamps. The database list and reported
sizes also matched the earlier inventory. The user subsequently confirmed
that the expected statistics are present and Jellyfin is connected.

On 2026-10-31, the user chose to defer the remaining operational checks,
including the Portainer automation rerun, rollback procedure preparation, and
planned restart test.

- [ ] Confirm acceptance of the risk of unverified data recovery, document
  rollback readiness and the Portainer cutover sequence, and preserve the
  active volumes and network. The user accepted the recovery risk; rollback
  readiness remains to be documented. The user manually stopped the old stack
  in the Portainer UI and then ran the combined Ansible playbook directly.
- [x] Reconcile Jellystat through the combined Ansible playbook alongside
  existing migrated stacks. A subsequent run reported the Jellystat task
  `ok` and a recap of `changed=0` and `failed=0`.
- [x] Inspect both containers to confirm native Compose labels, expected
  images, mounts, network, ports, and restart policies. Confirm PostgreSQL is
  ready and Jellystat connects to it. The reported post-recovery inspections,
  TCP query, and UI verification passed.
- [x] Verify the UI, existing statistics, and Jellyfin connection against the
  baseline. The user confirmed the expected statistics are present and
  Jellyfin is connected after recovery.
- [x] Check logs carefully without exposing credentials or personal data.
  The reported recent logs show PostgreSQL ready, Jellystat listening, and its
  Jellyfin WebSocket connected. PostgreSQL logged `database "jfstat" already
  exists` for `CREATE DATABASE jfstat` at startup; Jellystat reported that the
  database exists and continued starting. No authentication failures were
  reported in these recent logs.
- [x] Rerun native deployment and compare container IDs and start times to
  check for unnecessary recreation. The repeat run reported Jellystat `ok`
  and `changed=0`; both IDs and start times were unchanged.
  Jellystat reported ID
  `ff3be1f898a744f8eb74885d8cbc49a1ca7178b774d0d940385c3bc056f8985c`
  and start time `2026-10-31T04:03:55.680074084Z`; PostgreSQL reported ID
  `898e9c1ecb2f5e40e2616b71c0cfe1d0c4929dd3944fa6d72ddcad9d56f9be20`
  and start time `2026-10-31T04:03:55.26042178Z`.
- [ ] Verify Portainer automation does not reclaim the stack and the other
  migrated services remain healthy. Jellystat is absent from the Portainer
  stack list in the working tree, but running the Portainer playbook can pull
  images or reconcile other stacks and may restart Docker if its daemon
  configuration changes. Schedule that test accordingly. A read-only
  container-status check reported the website, Cloudflare tunnel, Homebridge,
  and Jellyfin running; the tunnel and Jellyfin reported healthy. This did not
  verify the other services' functionality or a Portainer automation rerun.
- [ ] Observe Jellystat and test recovery after a planned host or Docker restart
  when practical.

### 4. Rollback and cleanup

Rollback is not yet a tested procedure. Before attempting it:

- Prevent native Ansible reconciliation and Portainer automation from
  competing for the Jellystat project. Confirm how the existing containers
  will be handed over without removing either volume or the shared network.
- Do not simply restore the old Portainer deployment-list entry: it points to
  `jellystat.yml.j2`, which is now the native template and references separate
  host-local secret files. The former template interpolated secrets directly
  and used the mutable `latest` image; the former Portainer entry enabled
  image pulls and pruning.
- Prepare an Ansible-based Portainer deployment using a reviewed definition,
  the intended image, and recovery secrets. Verify that the effective database
  password matches the existing PostgreSQL role and that Compose interpolation
  preserves all secret values. Setting `POSTGRES_PASSWORD` does not change
  the password of a role in an existing PostgreSQL data directory.
- Review the scope and side effects of the Portainer playbook before running
  it. Preserve the existing Portainer record, both named volumes, and
  `pangolin_network`; never use `docker compose down --volumes`.

- [ ] If verification fails, prepare and review a rollback procedure before
  using it, then verify the UI and existing statistics. Preserve the existing
  database and backup volumes; restore a backup only if recovery requires it.
- [ ] Retain the Portainer stack record until record-only removal is known to
  be safe. Do not remove or prune volumes as part of this migration.

## Next migration: Newt

Migrate only Newt to the combined Ansible-managed Compose workflow. The
[current template](stacks/newt.yml.j2) defines one container, a blueprint
bind mount, Docker socket access, credentials, and the external
`pangolin_network`. The live configuration must be inventoried rather than
assumed from the template.

Newt also has two Portainer deployment paths:
[`portainer-stacks.yml`](playbooks/portainer-stacks.yml) and
[`pangolin-blueprint-deploy.yml`](playbooks/pangolin-blueprint-deploy.yml).
The latter updates the blueprint and can restart Newt. Both are imported by
[`container-manager.yml`](../container-manager.yml). A migration must
preserve blueprint updates and their restart behavior without allowing either
path to reclaim the native stack. Do not share credentials, blueprint
contents, container environment variables, or resolved secret-bearing Compose
configuration.

**Cutover in progress:** After preparation, the user manually stopped the
Newt stack in Portainer to begin deployment. A subsequent Newt inspection
was reported to return `no such object: newt`. The user then reported running
the native deployment command. A follow-up inspection reported a running
container using the native Compose file and the original image ID, with zero
restarts. The user confirmed that Pangolin shows Newt connected and the
selected sites work externally.

### 1. Inventory and baseline

- [ ] Choose a maintenance window and identify representative
  Pangolin-exposed services to check before and after cutover. A Newt
  interruption may affect access to those services; establish an independent
  management path and a rollback decision point.
- [x] Record the live Compose project, service, configuration path, image,
  status, and restart policy on `container-manager`:

  ```bash
  docker inspect newt \
    --format 'name={{ .Name }} project={{ index .Config.Labels "com.docker.compose.project" }} service={{ index .Config.Labels "com.docker.compose.service" }} config={{ index .Config.Labels "com.docker.compose.project.config_files" }} image={{ .Config.Image }} image_id={{ .Image }} started={{ .State.StartedAt }} status={{ .State.Status }} health={{ if .State.Health }}{{ .State.Health.Status }}{{ else }}none{{ end }} restart={{ .HostConfig.RestartPolicy.Name }}'
  ```

  On 2026-10-31, Newt reported project and service `newt`, config
  `/data/compose/4/docker-compose.yml`, image `fosrl/newt:1.16.0`, image ID
  `sha256:345fdeb369be6608d82c41d70637636c78b2c04a6112ff6ec20fc21c48afc899`,
  start time `2026-10-30T03:22:57.730358856Z`, status `running`, no Docker
  health check, and restart policy `unless-stopped`.

- [x] Record the running image's ID and available repository digests; decide
  how to preserve the same release through cutover and rollback.

  ```bash
  docker image inspect \
    "$(docker inspect --format '{{.Image}}' newt)" \
    --format 'image_id={{ .Id }} repo_digests={{ json .RepoDigests }}'
  ```

  The reported image ID is
  `sha256:345fdeb369be6608d82c41d70637636c78b2c04a6112ff6ec20fc21c48afc899`,
  and the repository digest is
  `fosrl/newt@sha256:345fdeb369be6608d82c41d70637636c78b2c04a6112ff6ec20fc21c48afc899`.
  The user chose to pin the native deployment to
  `fosrl/newt:1.16.0@sha256:345fdeb369be6608d82c41d70637636c78b2c04a6112ff6ec20fc21c48afc899`.
  The working-tree `newt_version` now uses the recorded digest. A read-only
  Docker Hub registry inspection confirmed it is a multi-platform image index;
  the previously configured digest
  `sha256:9e5eed53ecdaeebff11640c58b29adab72e2c4ac5652d391f92c92133f1534ba`
  is its `linux/amd64` image manifest. The staged reference and running
  platform have not yet been verified on the host.

- [x] Record actual mount sources, destinations, and access modes, including
  the blueprint and Docker socket; inspect the blueprint's availability,
  ownership, and permissions without displaying its contents.

  ```bash
  docker inspect newt \
    --format '{{ .Name }}{{ "\n" }}{{ range .Mounts }}type={{ .Type }} name={{ .Name }} source={{ .Source }} destination={{ .Destination }} rw={{ .RW }}{{ "\n" }}{{ end }}'
  ```

  The reported mounts are `/var/run/docker.sock` at the same container path
  read-only, and
  `/home/ansible/docker/newt/config/home1_pangolin_blueprint.yml` at
  `/app/config/home1_pangolin_blueprint.yml` read-write. The blueprint is a
  5,924-byte regular file owned by `ansible:ansible` with mode `0644`.

- [x] Record published ports, network membership, and configured extra hosts.

  ```bash
  docker port newt
  docker inspect newt \
    --format '{{ .Name }}{{ range $name, $_ := .NetworkSettings.Networks }} network={{ $name }}{{ end }} extra_hosts={{ json .HostConfig.ExtraHosts }}'
  ```

  The reported container is attached to `pangolin_network` and has no
  published ports. Extra hosts are `host.docker.internal:host-gateway` and
  `pangolin.mclaysen.com:198.46.215.121`.
- [x] Compare the post-deployment network, ports, and extra hosts with the
  live baseline. Newt reports the same `pangolin_network`, no published ports,
  and the same two extra-host mappings.

- [x] Confirm Newt is connected and the selected Pangolin services work.
  Review logs privately, without sharing credentials or personal data.
  The reported logs show Jellystat's target refusing connections from
  `03:51:55` through `04:03:55`, then changing from unhealthy to healthy at
  `04:04:10`. This is consistent with the earlier Jellystat recovery, but
  these historical messages do not establish Newt's current connection or
  end-to-end Pangolin access. The user confirmed that Pangolin shows Newt
  connected and that `media-stats` and `photos.mclaysen.com` are accessible
  through Pangolin from an external connection.
- [x] Save the Portainer definition, deployment settings, blueprint, and
  required recovery credentials securely. Record the backup and rollback
  decision; do not assume a saved definition alone is a tested recovery path.
  The user confirmed the definition and deployment settings, blueprint, and
  recovery credentials are saved and accessible. The user chose to plan for
  restoring Portainer management through Ansible if needed; the recovery
  procedure remains to be prepared and reviewed.

### 2. Prepare native Compose and automation

- [x] Add Newt preparation and a deployment task to the combined Ansible
  playbook, with activation gated during preparation. After cutover, the user
  chose unconditional reconciliation and the gate was removed from the
  working tree. Newt secret validation remains unconditional and can stop
  reconciliation of the other stacks.
- [ ] Compare the rendered project and container names, image, restart policy,
  network, mounts, extra hosts, and non-secret settings with the live baseline.
  Verify the staged image reference and host platform before deployment.
- [x] Add separate raw credential templates without duplicating their keys in
  Compose `environment`. The working-tree playbook renders environment files
  as `root:root` / `0600` with `no_log: true`.
- [x] Verify that the host Compose version supports `env_file: format: raw`.
  The earlier Jellystat check on this host reported Compose `v5.4.0` for both
  the `ansible` user and `sudo`.
- [x] Verify actual rendered-file permissions. The user reported `.env`,
  `id.env`, and `secret.env` as `root:root` / `0600`.
- [ ] Verify effective Newt credentials without printing values. Account for
  Compose interpolation and special characters. The old container was stopped
  before its effective credentials were compared with the staged files. The
  native container established a tunnel and the selected sites work, but
  credential equality with the old container has not been verified.
- [x] Retain Ansible-managed blueprint rendering and the existing Newt restart
  notification in the working tree; remove the unconditional Compose restart
  task.
- [ ] Verify the existing external network and blueprint bind mount are
  preserved without replacing shared resources. The post-deployment
  inspection shows the same network name and blueprint bind mount as before
  cutover; the network's prior ID was not recorded.
- [x] Verify an unchanged blueprint does not restart Newt. Both the
  check-mode and normal blueprint playbook runs reported `changed=0` and
  `failed=0`. Before the normal run, Newt reported ID
  `bfc30df8a88a17833bd3947f176267d57652120ce729b393b2eb9fc509aba5c9`
  and start time `2026-10-31T05:26:08.125898049Z`; both were unchanged after
  the run.
- [x] Verify a changed blueprint triggers the intended restart. With the
  user's approval, a temporary YAML comment was added to the blueprint
  template and then removed. Each normal blueprint playbook run reported the
  template and `Restart newt` handler changed, with no failures. The
  container ID remained
  `bfc30df8a88a17833bd3947f176267d57652120ce729b393b2eb9fc509aba5c9`;
  its start time changed from `2026-10-31T05:26:08.125898049Z` to
  `2026-10-31T05:39:59.31908749Z`, then
  `2026-10-31T05:40:40.987992698Z`. After each restart, Newt logged that its
  tunnel was established and HTTP checks for media-stats and photos returned
  200. Immediately after the second restart media-stats first returned 502,
  then returned 200 on a subsequent check. The temporary source change was
  removed, and a final blueprint check-mode run reported `changed=0` and
  `failed=0`. HTTP status checks do not prove full application functionality
  or that a substantive routing change would be applied correctly.
- [x] Remove Newt from the general Portainer stack list and remove the
  Portainer deployment task from the blueprint playbook in the working tree.
  The blueprint playbook does not reconcile native Compose configuration; the
  combined deployment playbook remains a separate operation.
- [ ] Verify the normal `container-manager.yml` workflow and direct playbook
  runs do not reclaim Newt through Portainer. The blueprint playbook ran with
  no changes and did not restart or recreate Newt; the general Portainer
  playbook and full workflow remain unverified.
- [x] Validate the local Newt Compose template with synthetic values. Compose
  2.31.0 accepted the configuration and represented literal dollar signs with
  Compose escaping in canonical output. A synthetic deployment without the
  new env files failed validation.
- [x] Validate Ansible syntax for the combined and blueprint playbooks. The
  user ran both syntax checks successfully with the Vault password file; both
  reported the existing `home_server` group/host naming warning. The combined
  playbook syntax check also passed after removing the Newt gate.
- [x] Validate the staged host Compose configuration without exposing
  secrets. The user confirmed `docker compose config --quiet` exited
  successfully.
- [x] Confirm the preparation run did not recreate or restart Newt. The run
  with `deploy_container=false` rendered the Newt directory and templates,
  passed secret validation, and skipped the Newt deployment task. Its recap
  reported `changed=3`, `failed=0`, and `skipped=1`; the other deployment
  tasks reported `ok`. Before the run, Newt reported ID
  `dc011a841f3a8d1aa5f75f02359bfc9aeea050f16df46e12146fdf71efb1d2b4`,
  start time `2026-10-30T03:22:57.730358856Z`, and status `running`. The
  post-run inspection reported the same ID, start time, and running status;
  Pangolin access was not rechecked before the old stack was stopped.
- [ ] Document a reviewed Ansible-based rollback procedure before cutover:
  prevent competing reconcilers, preserve the blueprint and network, restore
  the intended image and effective credentials, and verify Pangolin access.
  Do not treat rollback as tested unless it has actually been exercised.

### 3. Cut over and verify

- [ ] In the maintenance window, disable both Portainer deployment paths,
  stop the old stack using the agreed sequence, and activate Newt through the
  combined Ansible playbook. Retain the Portainer stack record and shared
  network; do not remove or prune resources. The user has manually stopped
  the old Newt stack in Portainer and reported running the native activation
  command. A container inspection shows native Compose ownership and running
  status; the play recap has not been reported.
- [x] Inspect Newt's native Compose labels, image ID, mounts, network, extra
  hosts, restart policy, status, and any health check against the baseline.
  Review recent logs privately and confirm Newt reconnects. Post-deployment
  inspection reported project `newt`, config
  `/opt/compose/newt/compose.yml`, status `running`, zero restarts,
  restart policy `unless-stopped`, and the same image ID as before cutover.
  Pangolin shows Newt connected. The service label is `newt` and there is no
  Docker health check, as before. The socket and blueprint mounts, network,
  extra hosts, and absence of published ports match the earlier inspection.
  Recent logs reported a WebSocket connection, an established tunnel, and
  healthy initial target checks. They also reported that Newt 1.19.0 is
  available; the migration retains the pinned 1.16.0 image.
- [x] Verify the selected Pangolin-exposed services from an external client
  against the baseline. The user confirmed that the selected sites work
  through Pangolin externally after cutover.
- [ ] Check applicable direct access paths against the baseline.
- [x] Record Newt's container ID and start time, rerun the native deployment,
  and confirm neither changed unnecessarily. Before the repeat deployment,
  Newt reported ID
  `bfc30df8a88a17833bd3947f176267d57652120ce729b393b2eb9fc509aba5c9`
  and start time `2026-10-31T05:26:08.125898049Z`. The repeat run reported
  the Newt task `ok`, with `changed=0` and `failed=0`; the post-run inspection
  reported the same ID and start time.
- [x] After removing the Newt gate, rerun the combined playbook without
  `deploy_container` and verify Newt is reconciled without an unnecessary
  restart or recreation. The reported run included the Newt task as `ok`
  and recapped `changed=0` and `failed=0`. The post-run inspection reported
  the same container ID and start time as the preceding baseline.
- [ ] At an agreed time, verify the normal automation paths do not redeploy
  Newt through Portainer and that blueprint updates still work. Review each
  playbook's other side effects before running it; do not treat a full
  `container-manager.yml` run as a read-only test.
- [ ] Observe Newt and, when practical, test recovery after a planned host or
  Docker restart. Keep the Portainer stack record until record-only removal is
  known to be safe.

## Next migration: Proton Mail Bridge

Migrate only Proton Mail Bridge to the combined Ansible-managed Compose
workflow. The current [template](stacks/proton_mail_bridge.yml.j2) defines one
service, an explicitly named `protonmail` volume mounted at `/root`, the
external `protonmail-network`, and a keyring passphrase supplied through
Portainer. The image reference is digest-pinned in the working tree; compare
all settings with the live container rather than assuming they match.

The shared network is also used by Immich, Ghost, and Dawarich templates.
Those services may depend on the bridge for mail delivery. Preserve the
bridge's working DNS name and aliases as well as the network; do not assume
that a running container proves SMTP authentication or delivery works.
Do not print secrets, message contents, or resolved secret-bearing Compose
configuration.

### 1. Inventory, recovery, and baseline

- [ ] Choose a maintenance window. Mail delivery may be interrupted during
  the bridge cutover. The user approved starting cutover now.
- [x] Record a representative mail-delivery baseline. The user confirmed
  that the Ghost blog had recently sent a successfully delivered email and
  chose Ghost as the representative application for migration verification.
  Other applications' mail delivery has not been verified. Do not send test
  messages without agreement.
- [x] Identify the actual container name and record its Compose project,
  service, configuration path, image, image ID, start time, status, health,
  and restart policy. Record available image digests and compare them with
  the pinned template. The user reported container
  `protonmail_bridge-protonmail-bridge-1` under project `protonmail_bridge`,
  with service `protonmail-bridge` and config
  `/data/compose/9/docker-compose.yml`. Inspection reported image
  `dancwilliams/protonmail-bridge:v3.25.0@sha256:32c44aaa56c168ec796c72a59159c1db0f55b8ba920a20e00c0e4ee129845134`,
  image ID
  `sha256:32c44aaa56c168ec796c72a59159c1db0f55b8ba920a20e00c0e4ee129845134`,
  start time `2026-10-30T03:24:16.733586874Z`, status `running`, health
  `healthy`, and restart policy `unless-stopped`. The image reference matches
  the working-tree pinned template and variables. Image inspection reported
  the same digest for both the tagged and untagged repository references:
  `dancwilliams/protonmail-bridge@sha256:32c44aaa56c168ec796c72a59159c1db0f55b8ba920a20e00c0e4ee129845134`.
- [x] Record all live mount sources, destinations, and access modes. Inspect
  the actual volume name and metadata without exposing its contents; preserve
  its identity, driver, and existing data. The live container mounts volume
  `protonmail` from `/var/lib/docker/volumes/protonmail/_data` at `/root`
  read-write. Volume inspection reported local driver and scope, creation time
  `2026-07-24T21:00:20-04:00`, Compose project `protonmail_bridge`, and no
  driver options.
- [x] Record the network name, ID, container aliases, and published ports,
  and verify the bridge's SMTP hostname and port used by Ghost without
  exposing credentials. The live container is attached to
  `protonmail-network`, with aliases
  `protonmail_bridge-protonmail-bridge-1` and `protonmail-bridge`; no
  published ports were reported. Network inspection reported ID
  `d9a162b856038177a7d46fb88a8881161056279298092e05ae60a114eb126d1e`,
  driver `bridge`, and scope `local`. The Ghost service container was
  identified as `ghost-ghost-1` and reported running. Its configured SMTP
  host is `protonmail-bridge`, its port is `25`, and it is attached to both
  `ghost_network` and `protonmail-network`.
- [x] Compare relevant non-secret bridge settings with the staged native
  configuration. The staged file specifies the recorded image, service
  name, restart policy, `protonmail` volume at `/root`, external
  `protonmail-network`, and no published ports. The native container's actual
  aliases and mounts still need verification after cutover.
- [x] Save the Portainer definition, deployment settings, keyring passphrase,
  and other required recovery materials securely. Verify availability without
  sharing their values. The user confirmed these materials are saved and
  accessible; rollback and rebuilding the volume have not been tested.
- [x] Record the backup and recovery decision. The user is not concerned
  about a backup and expects the volume could be rebuilt if needed, rather
  than relying on a verified backup. The rebuild procedure has not been
  verified. Do not remove, overwrite, or prune the existing volume.

### 2. Prepare native Compose

- [x] Add staged preparation to the combined Ansible playbook and gate bridge
  activation until cutover. The working tree updates the existing bridge
  template for native Compose and initially gated the deployment task with
  `deploy_protonmail_bridge`, defaulting to false. After cutover, the user
  removed the gate for unconditional reconciliation. The user chose to rely
  on Git for recovery rather than keep conditional Portainer support in the
  template.
- [x] Preserve the effective keyring passphrase without printing it. Account
  for Compose interpolation and special characters; use secure `root:root`
  / `0600` environment files and `no_log: true`. Validate secrets and compare
  effective values safely before the old container is stopped. The working
  tree uses a separate raw secret file and validates the passphrase as a
  nonempty, single-line string without logging it. The user chose fail-fast
  behavior: an invalid passphrase stops the combined playbook before any
  stack deployment, including when bridge deployment was gated. The host reported
  `.env` and `secret.env` owned by `root:root` with mode `0600`. A secret-safe
  comparison reported that the staged raw passphrase matches the running
  container's effective setting.
- [ ] Prepare the existing external network and volume without replacing or
  removing shared resources. Decide explicitly how the volume is managed;
  avoid any command that removes volumes or the shared network. The user
  chose a Compose-managed volume with the existing explicit `protonmail`
  name, which the new native template specifies. Never use
  `docker compose down --volumes`; it can remove this volume. Host validation
  remains open. After the preparation run, `protonmail-network` reported the
  same ID as before the run; endpoint membership has not been rechecked.
- [x] Remove the bridge from the Portainer deployment list in the working tree
  so that playbook does not redeploy the native-only template through
  Portainer. The existing Portainer-managed container and stack record are
  unchanged; the Portainer playbook has not been rerun.
- [ ] Document an Ansible-based rollback procedure before cutover. The user
  plans to rely on Git to recover the prior configuration; Git alone does not
  restore credentials, volume contents, or a working deployment. Preserve the
  old stack record, image, volume, network, and effective credentials. Record
  whether rollback has actually been tested. The user chose to proceed with
  the recovery path untested; a reviewed rollback procedure remains open.
- [ ] Validate Ansible syntax and staged Compose configuration without
  exposing secrets. Compare the rendered non-secret settings and effective
  secret with the live baseline. Confirm the preparation run does not
  restart or recreate the bridge and understand its effects on other stacks.
  Local Ansible syntax validation passed. A synthetic Compose configuration
  check confirmed the expected image, named volume, external network, restart
  policy, and canonical raw-secret escaping; a missing secret file failed
  validation. These checks do not prove the real credentials match or that a
  container can connect. Before host preparation, the bridge reported ID
  `ed40615287f48ee87bd51c7f40d5b37e4124aa67f6f8f76c835c453fdb580d98`,
  start time `2026-10-30T03:24:16.733586874Z`, and status `running`. The
  host preparation run passed secret validation, reported the Proton network
  task `ok`, skipped bridge deployment, and recapped `changed=3`,
  `failed=0`, and `skipped=1`. The bridge's post-run container ID, start
  time, and running status were unchanged; the shared network ID also matched
  the baseline. The staged `docker compose config --quiet` command succeeded.
  The staged passphrase matched the running container in a secret-safe
  comparison, and the reported staged non-secret settings matched the live
  baseline. The network endpoint membership and Ghost mail delivery after
  preparation have not been rechecked.

### 3. Cut over and verify

The user accepted the migration after the successful Ghost delivery and
ungated idempotency checks. The unchecked recovery and Portainer-automation
checks below remain open.

- [x] During the agreed window, stop the Portainer-managed bridge and deploy
  the native project through Ansible using the agreed handoff procedure.
  Retain the Portainer stack record, persistent volume, and shared network.
  After the user stopped the stack, no containers were reported for project
  `protonmail_bridge`. The `protonmail` volume retained its recorded
  creation time, and `protonmail-network` retained its recorded ID. The
  subsequent Ansible run reported the bridge deployment `changed`, with a
  recap of `changed=1` and `failed=0`.
- [x] Verify native Compose labels, image ID, volume, network and aliases,
  ports, restart policy, container status, and logs against the baseline.
  Inspection reported the expected project and service, native config path
  `/opt/compose/protonmail_bridge/compose.yml`, baseline image reference and
  ID, `protonmail` mounted at `/root`, `protonmail-network` with both expected
  aliases, and restart policy `unless-stopped`. The container was running and
  healthy with zero restarts. No published ports were reported; the volume
  creation time and network ID matched the baseline. The new container ID is
  `91a17399a2177889767be321abc31097fc4bc054b08c312b3830028af7e2f740`, with
  start time `2026-11-01T03:29:41.384486602Z`. The user reviewed logs: sync
  completed, with a warning that test credentials could not be added through
  the D-Bus keychain helper because `dbus-launch` was unavailable. Ghost's
  subsequent test email was delivered despite the warning.
- [x] Confirm Ghost can resolve the bridge and complete end-to-end mail
  delivery, as agreed for the baseline. This does not verify other
  applications' mail delivery. Do not expose credentials or message contents.
  The user confirmed receipt of a test email after cutover.
- [x] Rerun the native deployment and compare container ID and start time for
  idempotency. After the user removed the activation gate, the ungated run
  reported the bridge task `ok` and recapped `changed=0` and `failed=0`.
  The subsequent container inspection reported the same ID and start time,
  with status `running`, health `healthy`, and zero restarts.
- [ ] At an agreed time, verify Portainer automation does not reclaim the
  bridge and other services remain healthy. Review the playbook's other
  effects before running it.
- [ ] Observe the bridge and test recovery after a planned host or Docker
  restart when practical. Keep the old stack record until its safe removal
  is understood.

## Next migration: Ghost

Migrate Ghost and its MySQL database from Portainer to the combined
Ansible-managed Compose workflow. This is a stateful migration: preserve the
existing content and database, the shared mail network, and the current image
versions. Preparation is not authorization to stop or replace the live stack.

### Current preparation

- The user had already added `/opt/compose/ghost` and the Ghost Compose and
  environment templates to the combined playbook, pinned the Ghost and MySQL
  image references in the variables, changed `ghost_network` to external, and
  added its network task. The user's changes also split the passwords into
  raw environment files; the service-specific environment names still needed
  correction. No native Ghost deployment task was present.
- The preparation now uses separate raw files for the Ghost database password,
  MySQL user password, MySQL root password, and Ghost mail password. The files
  and interpolation `.env` are rendered as `root:root` with mode `0600`;
  passwords are checked for nonempty single-line values with `no_log: true`.
  This validation is unconditional and can stop the combined playbook before
  it deploys any stack.
- Native Ghost deployment is gated by `deploy_ghost`, which defaults to false.
  When enabled, it checks that the content directory, MySQL data directory,
  and MySQL system directory already exist before deploying. These checks do
  not prove that the paths contain the correct or recoverable data.
- The user chose to remove Ghost from the Portainer Ansible stack list now,
  while retaining the existing Portainer stack and containers. This is a
  working-tree change only; it does not stop or remove the live stack.
  The native-only template must not be deployed through the old Portainer
  definition. Preserve the old definition and credentials securely for
  recovery.
- The user reports having a full VM backup and is not very concerned about
  the amount of Ghost content. The backup's database consistency and a
  successful restore have not been verified.
- The user confirmed that the public blog and admin login work and that the
  current Portainer definition and required credentials are saved securely.
- The user approved proceeding with cutover despite the untested VM backup
  and rollback, and agreed to test email before and after cutover. The
  user confirmed that the pre-cutover test email was delivered.
- The user prefers stopping the existing containers through Portainer.
  Stop Ghost first and MySQL second using the containers' Stop actions;
  retain the stack record, data, and networks. Verify the stopped state
  and network identities before native deployment.
- **Cutover in progress:** After the user's Portainer stop action on
  2026-11-02, no Ghost project containers were listed and `ghost_network`
  no longer existed. The exact Portainer action and removal behavior have not
  been confirmed. The shared `protonmail-network` retained its ID and other
  application endpoints. Read-only inspection confirmed that the Ghost
  content, MySQL data, and MySQL system directories still exist and that both
  pinned images remain available. This does not verify data integrity.
  The combined playbook recreated `ghost_network` and deployed Ghost with
  `deploy_ghost=true`; its recap was `ok=21`, `changed=2`, `failed=0`.
  The new network ID is
  `bde1915e01200ee110d9209c719424e1fc5df3b54d4266ed6c76baa3047fd76c`,
  different from the original as expected.
- Post-cutover inspection found both containers running under project `ghost`
  and `/opt/compose/ghost/compose.yml`, with the original pinned image IDs,
  bind mounts, ports, network aliases, and restart policies. MySQL was healthy,
  and both containers had zero restarts. The shared Proton Mail network kept
  its original ID and application endpoints. New container IDs are
  `a9a5f1759a12222a345eeaef8ff6cbbc099f4cde321d3dc237056a97c8c3c80a`
  for Ghost and
  `d8c027a8043522492a38f653a6592ab98caadfa368d5b18f13bb1f5d389df143`
  for MySQL.
- Initial local and public HTTP checks returned 503 while the new containers
  were starting. A later check returned HTTP 200 from Ghost inside the
  container, from its published local port, and from the public blog; the
  reason for the transient 503 is not confirmed. Recent MySQL logs contained
  a readiness marker and no error or access-denied markers. An HTTP 200 does
  not verify login, content, or mail delivery.
- The user confirmed that the public blog loads with expected content, but
  reported that Ghost said the post-cutover test email was sent but it did
  not arrive. Ghost and Proton Mail Bridge were running with zero
  restarts, the bridge was healthy, and a TCP connection from Ghost to
  `protonmail-bridge:25` succeeded. The running Ghost mail password matched
  the staged raw file without printing it. A limited scan of recent logs
  found no common SMTP authentication, connection, TLS, or send-error
  markers. A subsequent Nodemailer verification using Ghost's running mail
  settings authenticated successfully without sending a message. This does
  not establish that the test email was accepted or delivered.
- The missing message was a welcome-email test. Inspection of the installed
  Ghost version showed that this test uses `GhostMailer` and the configured
  SMTP transport, not the bulk-newsletter delivery path. Three test requests
  returned HTTP 204, and Proton Mail Bridge logged SMTP message-sent events
  at the corresponding times on 2026-11-03: 03:20:50, 03:21:14, and
  03:23:30 UTC. The user identified a duplicate-message warning, and the
  bridge logs confirm duplicate suppression at all three times. The 204
  responses and message-sent events therefore do not prove that these tests
  produced new messages or were delivered. The user reported that the
  message was absent from Proton's Sent folder and the recipient's inbox.
  Retest with a distinct message or after the suppression window, and verify
  the test recipient, sending account, and actual delivery before declaring
  mail verified.
- The existing Proton Mail Bridge migration recorded `ghost-ghost-1`
  running on `ghost_network` and `protonmail-network`, using
  `protonmail-bridge:25` for SMTP, and a delivered test email. Reconfirm this
  and the full Ghost/MySQL state; that earlier observation is not a complete
  Ghost baseline.
- Local synthetic checks passed for the default-off deployment gate, the
  missing-data guard, and the rendered Compose configuration, including raw
  secret characters and a missing-secret-file failure. Syntax checks of both
  playbooks passed with an empty synthetic vault; normal syntax checks could
  not decrypt the real vault without its password.
- On 2026-11-02 the user ran host preparation with the Ghost gate off.
  Ghost's Compose directory and template were created, five environment-file
  loop items reported changed without exposing their values, and secret
  validation passed. The other stack deployment and network tasks reported
  `ok`; the Ghost directory checks and deployment were skipped. The recap was
  `ok=18`, `changed=3`, `failed=0`, `unreachable=0`, and `skipped=3`.
  The user subsequently confirmed that both container IDs and start times
  and both shared network IDs matched the baseline. Both containers remained
  running with zero restarts. A later read-only inspection confirmed that the
  shared network membership also matched the pre-preparation inventory.
- Host-side Compose `v5.4.0` validated the staged configuration with
  `config --quiet`. The five Ghost environment files reported `root:root`
  ownership and mode `0600`. Secret-safe comparisons found the staged Ghost
  database, MySQL user, MySQL root, and Ghost mail passwords equal to their
  respective live container values. These comparisons did not print secrets
  or independently test authentication.
- A read-only comparison found that the staged and live image references,
  active services, bind mounts, networks, published ports, restart policies,
  and relevant Ghost and MySQL environment settings matched. The comparison
  included the SMTP user and sender address without printing their values.

### Live inventory on 2026-11-02

Read-only inspection reported both containers running under project `ghost`
and `/data/compose/10/docker-compose.yml`. The Ghost service has no Docker
health check; the MySQL service is healthy. Both use `restart: always`.
The user repeated the project container listing on 2026-11-02 at about
22:03: both containers were still running, with MySQL reported healthy.
A subsequent read-only inspection confirmed zero restarts for both. Ghost's
container ID was `00861c3287512032d94d0bfa9598a278141a0d7240785e921cb608bf4edefdef`,
started `2026-10-30T03:24:00.380691264Z`; MySQL's was
`cc21a8ad20be0fe60dac214498572e7b9904ef5977b669b21d59e55f823c3c19`,
started `2026-10-30T03:23:49.087001839Z`.

| Service | Image ID and repository digest | Mount | Networks |
| --- | --- | --- | --- |
| `ghost-ghost-1` | `ghost@sha256:29886ddcf4ae5c005099c8ade34707d7c8d5d71b9dc5e31473c632b27b2ea18a` | `/home/ansible/docker/ghost/content` to `/var/lib/ghost/content` | `ghost_network`, `protonmail-network` |
| `ghost-db-1` | `mysql@sha256:f37951fc3753a6a22d6c7bf6978c5e5fefcf6f31814d98c582524f98eae52b21` | `/home/ansible/docker/ghost/mysql` to `/var/lib/mysql` | `ghost_network` |

These image digests and bind paths match the staged variables. Ghost publishes
`192.168.86.202:2368` to container port 2368; MySQL has no published ports.
Ghost's aliases on both networks are `ghost-ghost-1` and `ghost`; MySQL's
aliases on `ghost_network` are `ghost-db-1` and `db`. The existing network
IDs are `00f51ef7427c0d5c4b0308496ad6ab6ca71dcd0c03861c5a33a2bf9b830df06d`
for `ghost_network` and
`d9a162b856038177a7d46fb88a8881161056279298092e05ae60a114eb126d1e`
for `protonmail-network`; both report bridge driver and local scope.
The user repeated the mount and network inspection at about 22:04 and
confirmed the same bind paths and aliases.

The configured database user and database are `ghost`, and the running
Ghost and MySQL user passwords were present and equal. The root and SMTP
passwords were present; no secret values were printed. These checks do not
compare any value against the staged vault. Live SMTP transport, host, port,
security and TLS-verification settings, plus non-secret Ghost URLs, database
settings, and Tinybird endpoints match the staged configuration. The
Tinybird admin token and workspace ID were empty. Only
the Ghost and MySQL containers were reported for the project, and the usual
project-prefixed analytics volumes were not present. The user confirmed they
do not use the optional Tinybird analytics services.

### Before cutover

- [x] Inspect both live containers' Compose project and config path, image
  references and IDs, restart policies, ports, network names and aliases,
  health and mount sources. Compare these with the staged configuration,
  including the digest-pinned images.
- [x] Confirm the intended analytics profile. The user does not use the
  optional Tinybird services, so keep the `analytics` profile disabled during
  this migration. Its build context, volumes, and configuration would need
  separate validation before enabling it later.
- [ ] Confirm the existing Ghost content and MySQL bind mounts match
  `ghost_upload_path` and `ghost_mysql_data_path`. Verify an application-
  consistent database backup and content backup, plus a practical recovery
  path. Do not initialize a new database, change data permissions blindly,
  remove the existing stack or networks, or prune volumes.
- [x] Save the current Portainer stack definition and effective credentials
  securely. Compare the staged database and SMTP credentials with the live
  settings without printing them. Git alone does not back up credentials,
  application data, or the database.
- [ ] Confirm the public blog, admin login, existing content, and mail
  delivery baseline. The user confirmed the public blog and admin login work;
  the pre-cutover test email was delivered. Existing content has not been
  separately confirmed.
- [x] Validate the staged Compose configuration on the host without exposing
  secrets. A preparation run of the combined playbook reconciles the other
  migrated stacks and manages shared networks; review its effects first.
  Verify that Ghost remains untouched with `deploy_ghost` unset and that the
  existing shared networks retain their identities and membership.
- [ ] Agree on a maintenance window, an Ansible-based rollback procedure,
  and a decision point. Stop the Portainer-managed stack only when ready,
  retain its record and data, then enable `deploy_ghost` for the native
  Ansible deployment. Never run both projects against the same database.
- [ ] After cutover, verify the live project labels, images, mounts, networks,
  health, blog, admin, existing content, and mail. Rerun Ansible to check
  idempotency, and confirm Portainer automation does not reclaim the stack.
  Keep the deployment gate until the migration is accepted.

### Ghost verification commands

Run these read-only commands on the container-manager host. The container
names are from the inventory above; verify the project list first if they
change. They do not stop, create, or deploy containers.

**Inventory and post-cutover comparison:**

```bash
sudo docker ps -a --filter label=com.docker.compose.project=ghost \
  --format 'name={{.Names}} image={{.Image}} status={{.Status}}'

sudo docker inspect ghost-ghost-1 ghost-db-1 \
  --format '{{$health := index .State "Health"}}{{.Name}} id={{.Id}} project={{index .Config.Labels "com.docker.compose.project"}} service={{index .Config.Labels "com.docker.compose.service"}} config={{index .Config.Labels "com.docker.compose.project.config_files"}} image={{.Config.Image}} image_id={{.Image}} started={{.State.StartedAt}} status={{.State.Status}} health={{if $health}}{{index $health "Status"}}{{else}}none{{end}} restarts={{.RestartCount}} restart_policy={{.HostConfig.RestartPolicy.Name}} ports={{json .NetworkSettings.Ports}}'

sudo docker inspect ghost-ghost-1 ghost-db-1 \
  --format '{{.Name}}{{range .Mounts}}{{println}}mount_type={{.Type}} source={{.Source}} destination={{.Destination}} rw={{.RW}}{{end}}{{range $name, $network := .NetworkSettings.Networks}}{{println}}network={{$name}} aliases={{json $network.Aliases}}{{end}}'

sudo docker network inspect ghost_network protonmail-network \
  --format 'name={{.Name}} id={{.Id}} driver={{.Driver}} scope={{.Scope}}{{range .Containers}}{{println}} member={{.Name}}{{end}}'

sudo docker volume ls --filter name=ghost_
```

Compare container IDs and start times before and after preparation to confirm
that it did not recreate Ghost or MySQL. After cutover, verify the Compose
config path is `/opt/compose/ghost/compose.yml` and compare the other settings
with the live inventory. Network membership can include other applications;
preserve those endpoints. The volume listing can help identify analytics
volumes but does not establish whether analytics is intended to be used.

**After the gated preparation run**, validate the staged files without
printing their contents:

```bash
sudo docker compose version
sudo stat -c '%a %U:%G %n' /opt/compose/ghost/.env \
  /opt/compose/ghost/ghost-db-pass.env /opt/compose/ghost/db-pass.env \
  /opt/compose/ghost/db-root-pass.env /opt/compose/ghost/email-pass.env
sudo docker compose -p ghost --project-directory /opt/compose/ghost \
  -f /opt/compose/ghost/compose.yml config --quiet
sudo docker compose -p ghost --project-directory /opt/compose/ghost \
  -f /opt/compose/ghost/compose.yml config --profiles
sudo docker compose -p ghost --project-directory /opt/compose/ghost \
  -f /opt/compose/ghost/compose.yml config --services
```

Compose must support `env_file` with `format: raw` (version 2.30 or later).
The profiles command lists *declared* profiles, not whether they are active
or needed; the services command shows the default-profile services. Review
any intended analytics build context separately. Do not run `docker compose
config` without a limiting option: its output can contain secrets.

**Compare staged secrets with the still-running Portainer containers** without
printing the values. Run this only after preparation has rendered the files:

```bash
sudo python3 - <<'PY'
import json
import subprocess
from pathlib import Path

containers = json.loads(subprocess.check_output(
    ["docker", "inspect", "ghost-ghost-1", "ghost-db-1"], text=True
))
environment = {
    container["Name"].lstrip("/"): container["Config"]["Env"]
    for container in containers
}
checks = [
    ("Ghost database", "ghost-ghost-1", "database__connection__password",
     "ghost-db-pass.env"),
    ("MySQL user", "ghost-db-1", "MYSQL_PASSWORD", "db-pass.env"),
    ("MySQL root", "ghost-db-1", "MYSQL_ROOT_PASSWORD", "db-root-pass.env"),
    ("Ghost mail", "ghost-ghost-1", "mail__options__auth__pass",
     "email-pass.env"),
]
ok = True
for label, container, key, filename in checks:
    prefix = key + "="
    live = [entry[len(prefix):] for entry in environment[container]
            if entry.startswith(prefix)]
    path = Path("/opt/compose/ghost") / filename
    staged = [line[len(prefix):] for line in path.read_text().splitlines()
              if line.startswith(prefix)]
    match = len(live) == len(staged) == 1 and bool(live[0]) and live[0] == staged[0]
    print(f"{label}: {'MATCH' if match else 'MISSING OR MISMATCH'}")
    ok = ok and match
if not ok:
    raise SystemExit(1)
PY
```

An error, missing entry, or mismatch requires investigation before cutover.
Matching environment values do not prove MySQL authentication or mail
delivery works; verify those separately. Do not post raw container environments,
secret files, or unrestricted Compose output.

## Next migration: monitoring stack

Move the existing monitoring project from Portainer to the combined
Ansible-managed Compose playbook. Preserve its data and the shared network;
preparation alone is not authorization to stop or replace the live stack.

### Inventory and recovery

- [x] Inventory the seven running services, their images, mounts, ports,
  restart policies, and networks. On 2026-11-04, all seven were running
  under project `monitoring_stack` and `/data/compose/1/docker-compose.yml`.
- [x] Identify the four volumes in use: `monitoring_stack_grafana_storage`,
  `monitoring_stack_prometheus_data`, `monitoring_stack_loki_data`, and
  `monitoring_stack_alloy_data`. The shared `monitoring-network` also has
  `dawarich_app` and `photon-dawarich` members. The separate
  `monitoring_stack_monitoring-network` had no members at inventory time.
- [x] Record a basic baseline: Grafana, Loki, Alloy, and unpoller HTTP
  checks succeeded, and all 23 active Prometheus targets were up. Unpoller
  was healthy but had eight restarts; recent log classifications included
  authentication and timeout markers. Their cause has not been established.
- [ ] Confirm Grafana login and expected dashboards and data, current logs,
  and scrape targets. Recheck unpoller and decide whether its earlier
  restarts need investigation before cutover.
- [ ] Confirm the backup covers all four volumes and required bind-mounted
  configuration. Verify a practical restore or explicitly accept the
  untested recovery risk. Save the existing Portainer definition and
  credentials securely.

### Review and prepare

- [ ] Correct the native playbook's missing monitoring Compose template
  source. As written, it fails during template staging, before the combined
  playbook can reconcile its stacks.
- [ ] Preserve the existing project and volume identities. The proposed
  project name `monitoring` would resolve different volume names from the
  existing `monitoring_stack` project and could start with empty data.
  Verify that all four intended volumes exist before deployment; volume
  existence alone does not establish recoverability.
- [ ] Manage the existing `monitoring-network`, not a newly created
  `monitoring_network`. Keep the network available to Dawarich, including
  on a clean install or recovery, and do not remove either existing network
  or its members during the migration.
- [ ] Keep monitoring deployment gated until the cutover is approved. The
  current native task runs unconditionally, while Portainer's running
  containers still own the fixed container names. Decide when to remove
  monitoring from Portainer automation so the two workflows do not compete.
- [ ] Keep the unpoller password only in the raw service secret file.
  Its duplicate in the Compose interpolation `.env` is parsed as dotenv
  syntax, so some otherwise valid raw passwords can make Compose fail.
  Compare the staged secret with the live value without printing either.
- [ ] Preserve the existing node-exporter and cAdvisor management workflow:
  moving their role import out of the normal container-manager playbook
  changes what that workflow manages. Review the relocated Docker daemon
  configuration and its restart handler for possible effects on all stacks.
- [ ] Validate the rendered Compose configuration, images, environment,
  ports, bind mounts, named volumes, networks, and dependencies against
  the live inventory. Verify secret file ownership and mode, and avoid
  printing secrets. Pin or otherwise preserve the live image versions for
  cutover. Review the combined playbook's effects on other stacks.

### Cutover and verification

- [ ] Agree on the maintenance window, backup and rollback decision, and
  stop/start order. Expect a monitoring gap; do not prune volumes or networks.
  Only stop the Portainer stack when the user approves cutover.
- [ ] Confirm old containers are stopped or removed as intended while the
  four data volumes and shared network remain intact. Deploy the native
  project through Ansible, not manual Compose deployment.
- [ ] Verify container labels and config path, image identities, volume
  mounts, ports, network members, and health. Confirm Grafana dashboards,
  Prometheus targets, Loki logs, Alloy ingestion, and unpoller metrics.
  Check that Dawarich remains on the shared network.
- [ ] Rerun the combined playbook to check idempotency and confirm Portainer
  automation does not reclaim the stack. Preserve the old definition and
  recovery data until the migration is accepted.

## Later migrations

Use the website pilot's lessons to plan the other stacks separately. Stateful
services will require verified backups, volume and bind-mount preservation,
Portainer environment-variable migration, and shared-network checks. Compose
interpolation `.env` files and service `env_file` entries are different:
preserve or deliberately replace both where used, including Immich's
`stack.env`. Beszel, Portainer agent removal, and eventual Portainer retirement
are outside this pilot.
