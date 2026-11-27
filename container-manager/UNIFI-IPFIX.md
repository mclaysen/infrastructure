# UniFi IPFIX with GoFlow2 and Loki

This proposed setup sends sampled UniFi gateway flows to GoFlow2, then uses
the existing Alloy, Loki, and Grafana stack:

```text
UniFi gateway --IPFIX/UDP--> GoFlow2 --JSON logs--> Alloy --> Loki --> Grafana
```

The monitoring stack includes the GeoIP database updater, the GoFlow2
collector, a GoFlow2 Prometheus scrape job and health probe, and a GoFlow2
overview dashboard. The Sankey visualization plugin and GeoIP enrichment are
not yet configured. This guide describes a proposed setup; it has not been
tested end to end with UniFi flow records.

## 1. GoFlow2 collector

[monitoring.yml.j2](stacks/monitoring.yml.j2) defines the `goflow2` service on
`monitoring-network`. Its image is pinned by `goflow2_version` in
[vars.yml](../group_vars/portainer_managers/vars.yml). It publishes UDP 2055 on
the container-manager host IP, exposes HTTP port 8080 only to the Docker network,
and has a Docker health check against `/__health`.

GoFlow2 listens for IPFIX on UDP 2055 and prints JSON to stdout by default.
The existing [Alloy configuration](templates/alloy_config.alloy.j2) discovers
Docker containers and forwards their logs to Loki, so no additional log shipper
is needed. Restrict access to UDP 2055 to the gateway using the firewall.

GoFlow2 also serves `/metrics` and `/__health` on TCP port 8080 by default.
The health endpoint returns 200 after the collector starts and 503 when it is
not collecting; it does not prove that flows are arriving or being decoded.
Docker reports an unhealthy status but does not restart a running container
solely because its health check fails. The Docker health check relies on the
image's `wget`.
See the [GoFlow2 HTTP server implementation](https://github.com/netsampler/goflow2/blob/v2.2.7/pkg/goflow2/httpserver/httpserver.go).

[prometheus_config.yml.j2](stacks/prometheus_config.yml.j2) scrapes
`goflow2:8080/metrics` in the `goflow2` job and probes
`http://goflow2:8080/__health` through the `blackbox_http2xx` job. The
playbook's existing `Recreate Prometheus` handler applies changes to the
Prometheus configuration.

## 2. GoFlow2 overview dashboard

[goflow2_overview.json](grafana_dashboards/goflow2_overview.json) is a
provisioned Grafana dashboard that uses the Prometheus datasource. It shows:

| Panel | PromQL | Meaning |
| --- | --- | --- |
| Metrics scrape | `min(up{job="goflow2"})` | Whether Prometheus can scrape the collector. |
| Collector health | `min(probe_success{job="blackbox_http2xx", instance="http://goflow2:8080/__health"})` | Whether the HTTP health probe succeeds. |
| Active exporters | `count(sum by (remote_ip) (increase(goflow2_flow_traffic_packets_total{job="goflow2", type="netflow"}[$__range])) > 0)` | Exporters that sent packets in the selected range. |
| Packets in range | `sum(increase(goflow2_flow_traffic_packets_total{job="goflow2", type="netflow"}[$__range]))` | Packets received in the selected range. |
| Received packets/s | `sum(rate(goflow2_flow_traffic_packets_total{job="goflow2", type="netflow"}[$__rate_interval]))` | NetFlow/IPFIX export datagrams received. |
| IPFIX data records/s | `sum(rate(goflow2_flow_process_nf_flowset_records_total{job="goflow2", version="10", type="DataFlowSet"}[$__rate_interval]))` | Records in processed IPFIX data sets. |
| Decoder errors/s | `sum(rate(goflow2_flow_decoder_error_total{job="goflow2", name="netflow"}[$__rate_interval]))` and `sum(rate(goflow2_flow_process_nf_errors_total{job="goflow2", error="template_not_found"}[$__rate_interval]))` | Decoding errors, including missing-template errors. |
| Dropped packets/s | `sum(rate(goflow2_flow_dropped_packets_total{job="goflow2"}[$__rate_interval]))` | Drops reported by the GoFlow2 receiver. |

These are collector metrics, not total network traffic. Data-record counts
do not prove that records reached Loki, and receiver drops do not represent
every possible network or kernel drop. Some counters appear only after the
relevant event occurs; a panel with no data is not necessarily zero. Missing
scrape or probe data is shown as unknown, not healthy. Missing-template errors
are expected briefly after GoFlow2 restarts, until the exporter resends
templates.

Deploy the dashboard with [grafana.yml](playbooks/grafana.yml), which
provisions all repository dashboards and removes deployed JSON dashboards
absent from the repository. Validate the panels after GoFlow2 is deployed and
UniFi is exporting flows.

## 3. Install the Grafana plugin

Add the Sankey plugin to the existing setting in
[monitoring.env.j2](stacks/monitoring.env.j2):

```env
GF_PLUGINS_PREINSTALL=grafana-clock-panel,netsage-sankey-panel
```

Grafana downloads the plugin when it starts.

## 4. Configure Loki retention

The existing [Loki configuration](templates/loki_config.yml.j2) specifies
90-day retention, but does not enable retention enforcement. Without it, logs
may remain indefinitely. Flow logs can be voluminous and contain network
activity, so configure retention and monitor available disk space.

For the existing filesystem-backed Loki setup, add:

```yaml
compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
```

The existing `/loki` volume must remain persistent. Enabling retention affects
all Loki logs, not just flows; review the existing 90-day policy before enabling
it. A shorter flow-specific policy can be added under `limits_config`, for
example:

```yaml
  retention_stream:
    - selector: '{container_name="goflow2"}'
      priority: 1
      period: 168h
```

The playbook currently renders the Loki configuration without recreating Loki.
To ensure Loki picks up a replaced bind-mounted file, add
`notify: Recreate Loki` to the `Place Loki configuration` task in
[process-containers.yml](playbooks/process-containers.yml), and add this handler
to [main.yml](handlers/main.yml):

```yaml
- name: Recreate Loki
  community.docker.docker_compose_v2:
    project_src: /opt/compose/monitoring
    project_name: monitoring
    services: [loki]
    dependencies: false
    recreate: always
```

See the [Loki retention documentation](https://grafana.com/docs/loki/v3.6.x/operations/storage/retention/)
for details.

## GeoIP enrichment

The monitoring Compose configuration includes `geoipupdate`, which downloads
GeoLite2 City and ASN databases into the persistent
`monitoring_stack_geoip_data` Docker volume and checks for updates every 72
hours. The City database also provides country information. Its account ID
and license key come from `max_mind_account_id` and `max_mind_license_key` in
the container-manager Ansible Vault and are rendered into a separate raw
environment file with mode `0600`. The VPS has its own Vault copy, so update
both Vaults when rotating shared MaxMind credentials.

After deploying the monitoring stack through Ansible, check the updater logs
and confirm that both `GeoLite2-City.mmdb` and `GeoLite2-ASN.mmdb` exist in
the volume. The updater runs independently of Alloy; downloads and future
updates must be monitored for errors.

The existing Alloy container can later enrich GoFlow2 logs before sending them
to Loki. The intended fields are country, city, approximate coordinates, and
ASN for both the source and destination IP. This enrichment has not yet been
configured or tested:

1. Mount the database volume read-only into Alloy. Ensure both files exist and
   are readable before enabling GeoIP stages; missing databases can prevent
   Alloy from starting.
2. In [alloy_config.alloy.j2](templates/alloy_config.alloy.j2), restrict
   processing to the `goflow2` container. Extract `src_addr` and `dst_addr`
   from its JSON and look up each address in both databases using
   `stage.geoip`. Use distinct source and destination field names and attach
   the results with `stage.structured_metadata`, not `stage.labels`.
3. Recreate Alloy when its bind-mounted configuration is replaced. The updater
   does not itself reload Alloy after replacing a database; an update-aware
   reload or restart mechanism still needs to be designed and tested.

GeoLite's license requires old databases to be deleted within 30 days of a new
release. See [MaxMind's update documentation](https://dev.maxmind.com/geoip/updating-databases/).

Alloy's GeoIP stage reuses extracted field names, so source and destination
lookups must be kept separate; otherwise, a missing lookup can leave values
from the previous address. Validate public and private IPs in both directions
before relying on the results. Private addresses generally have no GeoIP
match, and public IP locations are approximate, especially for VPNs and CDNs.
See the [Alloy GeoIP documentation](https://grafana.com/docs/alloy/v1.14/reference/components/loki/loki.process/#stagegeoip)
for the stage configuration.

## Other enrichment to consider

These are ideas for making flows easier to understand; they are not configured:

- **Device names:** Map local IPs to UniFi client names for diagrams such as
  `Laptop -> Cloudflare`. This requires a client inventory or cached lookup.
  IPs can be reassigned, so preserve the original IP and the name observed
  when the flow was processed.
- **Network grouping:** Map local subnets to names such as trusted, IoT, or
  guest. A subnet mapping is not necessarily the actual VLAN; NAT and routing
  can obscure the original network.
- **Direction:** Classify flows as inbound, outbound, or local-to-local based
  on known local IPv4 and IPv6 ranges. VPNs and NAT can make this ambiguous.
- **Protocol and port:** Use these fields for filtering when the exporter
  provides them. A port does not reliably identify an application.

Start with device names and network grouping. Keep enriched values as
structured metadata rather than Loki stream labels, and retain the original
flow fields.

## 5. Deploy and enable IPFIX

Review the changes, then deploy using the existing Ansible workflow:

```bash
ansible-playbook container-manager/playbooks/process-containers.yml \
  --limit container-VM --vault-password-file ./.vault_pass \
  -e immich_stack_enabled=true
```

The playbook reconciles multiple stacks. As described in the
[main README](../README.md), omit the Immich variable only if its deployment
should be skipped.

In UniFi Network, open **Settings > CyberSecure > Traffic Logging** and enable
**NetFlow (IPFIX)**. Set the collector to the container-manager host IP and
UDP port 2055. Ubiquiti documents version and storage requirements; in
particular, the UDM Pro needs installed storage for full traffic logging.
See [Ubiquiti's traffic logging documentation](https://help.ui.com/hc/en-us/articles/32201256219799-Traffic-Flows-and-Traffic-Logging-in-UniFi-Network).

## 6. Query and visualize flows

In Grafana Explore, select Loki and check for decoded records:

```logql
{container_name="goflow2"} | json
```

IPFIX templates may take a few minutes to arrive. If no records appear, check
the gateway destination, UDP firewall rules, and GoFlow2 logs.

In Grafana Explore, select Prometheus and verify that the metrics scrape and
health probe succeed:

```promql
up{job="goflow2"}
```

```promql
probe_success{job="blackbox_http2xx", instance="http://goflow2:8080/__health"}
```

Both should return `1`. Check the container's Docker health status as well;
neither an HTTP health check nor a successful scrape confirms that IPFIX
packets or decoded flows are arriving.

Create a Sankey panel using Loki and an **instant** query:

```logql
topk(20,
  sum by (src_addr, dst_addr) (
    sum_over_time(
      {container_name="goflow2"}
      | json src_addr="src_addr", dst_addr="dst_addr", flow_bytes="bytes"
      | unwrap flow_bytes
      | __error__="" [$__range]
    )
  )
)
```

This sums reported bytes for the top 20 source/destination pairs in the
selected time range. Use Grafana's **Labels to fields** and **Organize fields**
transformations to produce one table ordered `src_addr`, `dst_addr`, `Value`.
Check the result in table view, then select the Sankey visualization. The query
syntax was checked against Loki, but the transformations and panel still need
validation with actual flows.

Keep IP addresses and ports in JSON, not Loki stream labels, to avoid excessive
label cardinality. Queries over many IP pairs can still be expensive; start
with a short time range. UniFi exports sampled traffic, and the query does not
scale for sampling, so values are not necessarily exact traffic totals.
