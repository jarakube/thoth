# Integrating Suricata with an Existing Docker Compose Application

**Scope:** Passive, continuous network-security monitoring of **one existing application container** using a Suricata sidecar.  
**Audience:** Developers and operators familiar with Docker Compose.  
**Last reviewed:** 2026-11-10

## 1. Goal and expected outcome

Add Suricata to an existing `Dockerfile` + Docker Compose deployment without modifying application code or routing application requests through a proxy. Suricata will observe packets on the application's selected network interface and write structured **EVE JSON** events for flows, DNS, TLS, HTTP, alerts, and sensor statistics.

**What this does not do:** decrypt HTTPS, guarantee visibility into every network namespace/interface, identify initiating processes, or block connections. A passive IDS reports observed traffic; it is not an egress firewall. Packet drops, startup ordering, encrypted DNS and Docker's internal DNS forwarding can create blind spots.

## 2. Architecture

```text
Existing Compose project
┌────────────────────────────────────────────────────────┐
│ app (existing Dockerfile)                              │
│   └── network namespace (eth0, loopback, etc.)          │
│          ▲                                             │
│          │ shared via network_mode: service:app        │
│ suricata (new container) ──> /var/log/suricata/eve.json│
└────────────────────────────────────────────────────────┘
                                 │ bind mount
                                 ▼
                     ./suricata/logs/eve.json
                                 │
                    jq / log shipper / SIEM
```

The monitoring container shares the application's **network namespace**, not its filesystem or process namespace. It sees packets traversing the interface(s) on which capture is enabled. It also sees incoming traffic; filter outbound application connections during analysis.

## 3. Prerequisites

- Docker Engine with Compose v2, running Linux containers.
- An existing service named `app` in `compose.yaml` or `docker-compose.yml`. Replace `app` in all examples with your actual service name.
- A capture-capable Docker environment. Rootless Docker or tightly restricted platforms may require adjustments.
- Enough disk space for logs; add log rotation/retention before permanent deployment.
- Basic tools: `docker`, `jq` (optional, for querying EVE JSON), and optionally `curl` in your application container.

**Assumptions:** The application uses the ordinary Compose bridge network and its outgoing traffic crosses `eth0`. If your service uses multiple networks, host networking, or routes traffic over additional interfaces, inspect the interfaces first and adapt the capture configuration. Docker Desktop runs containers inside a Linux VM; the sidecar approach is generally more portable than host-interface capture.

## 4. Files to add

```text
project/
├── Dockerfile                         # existing; unchanged
├── compose.yaml                       # existing; unchanged
├── compose.suricata.yaml              # new: sidecar override
└── suricata/
    ├── config/                        # generated Suricata configuration
    ├── data/                          # downloaded rules and persistent data
    └── logs/                          # EVE JSON and other logs
```

Create directories:

```bash
mkdir -p suricata/config suricata/data suricata/logs
```

To avoid committing logs and security-sensitive information, add these lines to your `.gitignore`:

```gitignore
/suricata/logs/
/suricata/data/
```

You may version-control reviewed configuration files, but avoid committing secrets or generated state.

## 5. Initialize Suricata configuration

Use the Suricata container image to seed the config directory **once**, before starting the Compose sidecar:

```bash
docker run --rm \
  -v "$(pwd)/suricata/config:/etc/suricata" \
  jasonish/suricata:8.0 -V
```

The `jasonish/suricata` image documents automatic population of an empty bind-mounted configuration directory. Check that the file exists:

```bash
test -f suricata/config/suricata.yaml && echo 'Config initialized'
```

> **Versioning:** `8.0` is a moving release-series tag; for reproducible production deployments, replace it with a tested immutable image digest. Use the *same image* for initialization, testing, and running the sensor.
>
> **Permissions:** Initialization may create root-owned files. Adjust host ownership or permissions to allow editing and Suricata to write logs and rule data without broad world-writable permissions.

## 6. Compose sidecar

Create **`compose.suricata.yaml`**:

```yaml
services:
  suricata:
    image: jasonish/suricata:8.0
    network_mode: "service:app"
    depends_on:
      - app
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_NICE
    command: ["-i", "eth0"]
    volumes:
      - ./suricata/config:/etc/suricata
      - ./suricata/logs:/var/log/suricata
      - ./suricata/data:/var/lib/suricata
    restart: unless-stopped
```

**Why these settings?**

- `network_mode: "service:app"`: captures from the same network namespace as the application.
- `-i eth0`: enables passive packet capture on the application's first network interface. This is not a guarantee of monitoring every interface.
- `NET_ADMIN`, `NET_RAW`, `SYS_NICE`: follow the image maintainer's documented capabilities for network capture and dropping privileges. Avoid `privileged: true` unless specifically justified.
- Bind mounts persist configuration, logs, and rule downloads.
- There is **no `ports:` section**; passive capture needs no exposed application port.

**Important lifecycle caveat:** `depends_on` does not guarantee Suricata is ready before the application emits its first packets. To monitor startup traffic, arrange a controlled application startup after sensor readiness, or test separately under a controlled deployment procedure. Recreating/replacing the application container can require restarting the namespace-sharing monitor.

## 7. Enable useful EVE JSON outputs

Edit **the existing** `outputs:` section in `suricata/config/suricata.yaml`. Find the existing `- eve-log:` entry and modify its `types:` list. **Do not paste a second top-level `outputs:` block.** A minimal relevant excerpt is:

```yaml
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      community-id: true
      types:
        - alert
        - anomaly:
            enabled: yes
        - flow
        - dns:
            enabled: yes
            requests: yes
            responses: yes
        - tls:
            extended: yes
        - http:
            extended: yes
        - stats:
            totals: yes
            threads: no
```

This snippet illustrates the EVE logger configuration. Preserve any other `outputs` entries and unrelated settings from the generated config, or deliberately disable ones you don't need.

| Event type | Typical value | Key limitation |
|---|---|---|
| `flow` | Source/destination IPs, ports, packet and byte counters | Often logged at flow end/timeout, not immediately on connection attempt |
| `dns` | Observable DNS queries/answers | Cached, encrypted, and Docker-forwarded DNS may be invisible on `eth0` |
| `tls` | TLS version and exposed SNI, when available | Cannot read encrypted HTTP paths/bodies; ECH may hide SNI |
| `http` | Cleartext HTTP method, host and URI | Ordinary HTTPS is encrypted |
| `alert` | Rule match, signature and severity | Requires installed/enabled rules; a match is not proof of compromise |
| `stats` | Sensor performance and counters | Requires monitoring to detect drops or interruptions |

If you need **loopback (`lo`)** visibility, for example requests to a local service or Docker's embedded DNS resolver at `127.0.0.11`, consider adding an additional capture interface after checking supported capture methods. Capturing just `eth0` will miss packets confined to `lo`.

## 8. Validate configuration and launch

First validate the combined Compose configuration:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml config
```

If your existing file is named `docker-compose.yml`, substitute that filename throughout.

Start the application and Suricata:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml up -d
```

Check containers and sensor logs:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml ps
docker compose -f compose.yaml -f compose.suricata.yaml logs --tail=100 suricata
```

Check Suricata's configuration using the mounted config:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml \
  exec suricata suricata -T -c /etc/suricata/suricata.yaml
```

Check the host log directory:

```bash
ls -lh suricata/logs/
tail -n 5 suricata/logs/eve.json
```

If the file is absent, inspect the service logs, file permissions, capture-interface name, and `eve-log` configuration. A valid config alone does not prove that Suricata is seeing traffic.

## 9. Generate test traffic

Generate traffic **from the monitored application's network namespace**. If the application image contains `curl`:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml \
  exec app curl -I https://example.com
```

If it lacks `curl`, use a temporary helper in the same namespace (traffic from this helper is useful for testing capture, but should not be attributed to the application process):

```bash
APP_ID=$(docker compose -f compose.yaml -f compose.suricata.yaml ps -q app)
docker run --rm --network "container:${APP_ID}" curlimages/curl:8.11.1 \
  -I https://example.com
```

The helper image tag is an example; pin a vetted digest if reproducibility is important.

Then inspect event types:

```bash
jq -r '.event_type' suricata/logs/eve.json | sort | uniq -c
```

Expect at least some `flow` events after connections close or time out, and possibly `tls` events. DNS events are **not guaranteed**, especially when DNS resolution occurs via Docker's embedded resolver on loopback.

## 10. Useful EVE queries

### Recent flow destinations

```bash
jq -r 'select(.event_type == "flow") |
  [.timestamp, .src_ip, (.src_port|tostring), .dest_ip, (.dest_port|tostring), .proto] |
  @tsv' suricata/logs/eve.json | tail -n 30
```

The result includes **both inbound and outbound** flows. To report application egress reliably, first identify the app's IP address(es) and filter `src_ip` accordingly. In some cases, flow direction and NAT location require additional interpretation.

### TLS SNI values (when visible)

```bash
jq -r 'select(.event_type == "tls") | .tls.sni // empty' \
  suricata/logs/eve.json | sort -u
```

### DNS query names (Suricata 8 default DNS v2 examples)

```bash
jq -r 'select(.event_type == "dns") |
  .dns.queries[]?.rrname // empty' suricata/logs/eve.json | sort -u
```

DNS event shapes vary with configured DNS logger version and request/response type. Inspect one actual event and adapt the query:

```bash
jq 'select(.event_type == "dns")' suricata/logs/eve.json | head -n 35
```

### Security alerts

```bash
jq -c 'select(.event_type == "alert") |
  {timestamp,src_ip,dest_ip,dest_port,signature:.alert.signature,severity:.alert.severity}' \
  suricata/logs/eve.json
```

## 11. Optional: Enable detection signatures

Flow/DNS/TLS logging can work **without** threat signatures. To obtain useful `alert` events, add and maintain rules.

The image maintainer documents updating rule data from the running container:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml \
  exec -u suricata suricata suricata-update -f
```

The image's normal rule-loading configuration and rule file paths should be checked after the update. Test the configuration again and reload or restart the sensor when necessary. For custom rules, add a reviewed rule file and reference it in the `rule-files:` section of `suricata.yaml`.

Do not assume `alert` logging is broken merely because you see no alerts: ordinary traffic may not match any enabled signature.

## 12. Operational hardening

1. **Retention:** `eve.json` can grow indefinitely. Configure rotation and a retention policy; for centralized monitoring, ship events to Loki, OpenSearch, or a SIEM. Plan rotation with the sensor/log collector so file handles and ingestion offsets are handled correctly.
2. **Permissions:** Protect `suricata/logs/` from unnecessary access. DNS names, HTTP metadata, and connection details can be sensitive.
3. **Health:** Monitor container restarts, capture errors, event freshness, Suricata `stats`, and packet-drop counters. A running container does not guarantee complete capture.
4. **Privilege:** Grant only capabilities required by the selected capture mode. Avoid exposing Suricata's control socket or any management port publicly.
5. **Configuration review:** Keep a copy of your customized YAML, test it before deploys, and pin tested image/rule versions.
6. **Resource budget:** Measure CPU, RAM, and storage under representative application traffic; full protocol logging has overhead.
7. **Service lifecycle:** If the application container is replaced, verify the sidecar still shares the current namespace; recreate the sidecar as needed.
8. **Coverage:** Check `eth0`, loopback, IPv6, additional network interfaces, UDP, and internal service-to-service traffic. There is no universal single-interface guarantee.

## 13. Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| `suricata` immediately exits | Bad YAML, interface missing, permissions | `docker compose ... logs suricata`; run `suricata -T` |
| No `eve.json` | EVE disabled, unwritable mount, no events | Config `outputs`, directory owner/permissions, startup logs |
| Flows but no DNS | Docker embedded DNS on loopback, cached DNS, DoH | Inspect `lo`, application resolver, actual traffic path |
| TLS events lack SNI | Direct-IP TLS, ECH, incomplete handshake | Inspect sample events and TLS client behavior |
| No alert events | No matching rules / rules not loaded | `suricata-update`, rule paths, test with controlled traffic |
| Only some traffic is visible | Multiple interfaces, packet loss, nonstandard network mode | Capture interface selection, `stats`, network namespace topology |
| Startup connections missing | `depends_on` is not sensor readiness | Start sensor before controlled traffic or redesign startup sequencing |

## 14. Rollback

Stop the monitoring sidecar while retaining the existing application:

```bash
docker compose -f compose.yaml -f compose.suricata.yaml stop suricata
```

To return to the unmodified deployment definition, run subsequent Compose commands with **only the original `compose.yaml`**. Do not delete logs before exporting anything required for investigation or retention compliance.

## 15. Acceptance checklist

- [ ] Suricata starts and reports the monitored interface.
- [ ] Generated EVE events are written to the host-mounted log directory.
- [ ] A controlled outbound HTTPS request produces observed traffic.
- [ ] DNS behavior is understood (including possible `127.0.0.11` loopback handling).
- [ ] Correct application IP(s) are used when reporting outbound flows.
- [ ] Detection rules are installed if security alerts are required.
- [ ] Packet-drop and sensor-health signals are monitored.
- [ ] Log rotation, retention, and access controls are defined.
- [ ] Application restarts/recreates are tested for sidecar continuity.

## References

- Docker Compose networking (`network_mode: service:<name>`): https://docs.docker.com/compose/how-tos/networking/
- `jasonish/suricata` image README (configuration initialization, capabilities, capture, rules): https://github.com/jasonish/docker-suricata/blob/main/README.md
- Suricata 8 EVE JSON output reference: https://docs.suricata.io/en/suricata-8.0.0/output/eve/eve-json-output.html
- Suricata YAML configuration: https://docs.suricata.io/en/suricata-8.0.0/configuration/suricata-yaml.html
- Suricata rule management: https://docs.suricata.io/en/latest/rule-management/suricata-update.html

---

**Recommended starting configuration:** a single Suricata sidecar, `eth0` capture, and EVE `flow`, `dns`, `tls`, `alert`, and `stats` events. Expand interface coverage and centralized collection only after verifying what traffic the first setup actually observes.
