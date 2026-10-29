# Portainer migration: website pilot

## Goal and scope

Move the `mclaysen_website` stack from Portainer to native Docker Compose,
deployed by Ansible. Migrate only the website in this pilot. Keep Portainer,
the Portainer agent, and all other stacks running and managed as they are.

The website's current definition is
[`stacks/mclaysen_website.yml.j2`](stacks/mclaysen_website.yml.j2). It
declares one `server` service, the
`ghcr.io/mclaysen/mclaysen-website:latest` image, `NODE_ENV=production`,
port mapping `5001:3000`, and `restart: unless-stopped`. It declares no
volumes or external networks. The reverse proxy is configured to forward
`mclaysen.com` to `192.168.86.202:5001`.

The reported running container is `mclaysen_website-server-1` on
`mclaysen_website_default`. Verify these names and the Compose labels before
cutover; do not assume the names alone prove the project identity.

Portainer references for the current endpoint:

- [Containers](https://container-manager.mclaysen.com/#!/3/docker/containers):
  select `mclaysen_website-server-1`.
- [Website network](https://container-manager.mclaysen.com/#!/3/docker/networks/mclaysen_website_default):
  `mclaysen_website_default`.

The container inspection reported on 2026-10-28 confirms:

| Property | Observed value |
| --- | --- |
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

- [ ] Add an Ansible playbook that renders only the website template to a
  stable host path, such as `/opt/compose/mclaysen_website/compose.yml`, and
  deploys it using `community.docker.docker_compose_v2`.
- [ ] Render `/opt/compose/mclaysen_website/.env` separately, initially with
  `NODE_ENV=production`. Configure the native Compose service to explicitly
  pass `NODE_ENV: ${NODE_ENV:?NODE_ENV must be set}` to the container. Compose
  uses `.env` for interpolation; it does not automatically pass every entry
  into the container.
- [ ] Preserve the current Portainer deployment until cutover. If the existing
  shared template is changed to require `NODE_ENV`, provide it to Portainer too,
  or use a separate native template until the website is removed from the
  Portainer deployment path.
- [ ] Keep rendered environment files on the Docker host with restricted
  permissions. For future secret-bearing stacks, render Vault-backed values
  with `no_log: true`, avoid logging resolved configuration, and remember that
  the resulting host files contain plaintext secrets.
- [ ] Explicitly set the Compose project name to the verified existing project
  name, expected to be `mclaysen_website`, regardless of the directory name.
- [ ] Preserve the current service, port, network identity, environment,
  restart policy, and image behavior. Do not introduce a pull of a newer
  `latest` image during cutover unless explicitly intended. Record the current
  image so rollback can use the same release.
- [ ] Separate preparation from activation so rendering and validation cannot
  replace the live Portainer-managed container. Ansible check mode alone does
  not create the rendered file or prove it is valid.
- [ ] On the host, validate the staged Compose configuration with the intended
  project name:

  ```bash
  docker compose -p mclaysen_website \
    -f /opt/compose/mclaysen_website/compose.yml config
  ```

- [ ] Compare the rendered configuration with the live service and saved
  Portainer definition. Confirm that the website needs no Portainer-supplied
  environment variables or other configuration missing from the template, and
  that `NODE_ENV` resolves to `production`. Check that the inherited shell
  environment does not override the intended `.env` values.
- [ ] Prevent the existing Portainer deployment automation from managing this
  stack after cutover, while leaving its entry and the other stacks available
  for rollback. Account for the imported
  [`portainer-stacks.yml`](playbooks/portainer-stacks.yml) in
  [`container-manager.yml`](../container-manager.yml).
- [ ] Document and test the rollback sequence before cutover, including how to
  re-enable the old deployment path and which image to use.

## 3. Cut over and verify

- [ ] Confirm the native configuration is validated and the Portainer
  automation will not redeploy the website.
- [ ] Stop only the website stack in Portainer. Do not delete the stack
  definition, remove volumes, or change any other stack.
- [ ] Start the native Compose project with the verified project name. Check
  for port or container-name conflicts before proceeding.
- [ ] Verify the expected container is running, attached to the expected
  network, and using the expected image ID. Inspect its logs for errors.
- [ ] Check local HTTP on port `5001` and the public
  `https://mclaysen.com/` response against the baseline. Verify representative
  website content, not just container status.
- [ ] Run the native deployment again and confirm it converges without
  unnecessary recreation. Verify that a normal
  [`container-manager.yml`](../container-manager.yml) run does not take
  ownership back through Portainer.
- [ ] Observe the website for an agreed period and, when practical, confirm
  recovery after a host or Docker restart.

## 4. Rollback if needed

- [ ] Stop the native website project without removing unrelated resources.
- [ ] Restore the saved Portainer definition and deployment settings, including
  the recorded image release, and re-enable its deployment automation.
- [ ] Redeploy the website through Portainer and check both the local and public
  HTTP endpoints. Confirm the original container/project is healthy.

## 5. Retire the website's Portainer ownership

- [ ] After the observation period, remove the website entry from the Portainer
  deployment automation and keep the native playbook as its sole deployment
  owner.
- [ ] Determine a safe way to retire the Portainer stack record for the
  installed Portainer version. Deleting a stack may stop or remove its live
  Compose resources, even when native Compose now manages the same project.
  Do not delete it until the behavior and recovery plan are verified; retaining
  an unused record is safer than interrupting the website.
- [ ] Confirm the rest of the Portainer-managed stacks remain unchanged.

## Later migrations

Use the website pilot's lessons to plan the other stacks separately. Stateful
services will require verified backups, volume and bind-mount preservation,
Portainer environment-variable migration, and shared-network checks. Compose
interpolation `.env` files and service `env_file` entries are different:
preserve or deliberately replace both where used, including Immich's
`stack.env`. Beszel, Portainer agent removal, and eventual Portainer retirement
are outside this pilot.
