# Self-hosting room-code multiplayer

The backend is Node.js + `ws` for transient signaling and coturn for STUN/TURN.
No database, account provider, paid service, or simulation server is required.
Both players configure the same signaling URL; they then exchange only a room
code. Hosting infrastructure requires a Linux VPS with a reachable public IP.

**Validation status:** this is a reproducible deployment procedure prepared from
the repository, not a claim that a VPS has been deployed. No VPS/domain or second
network was available in this environment. Docker daemon and SSH access were
unavailable. See [PUBLIC_TEST_REPORT.md](PUBLIC_TEST_REPORT.md) for exact results
and remaining public-network evidence.

## Quick local development (no TURN)

Install Node.js 22 or newer. From the repository root:

```sh
cd server/signaling
npm ci --ignore-scripts
npm test
npm start
```

On a restricted Windows environment where Node cannot spawn test subprocesses:

```powershell
node --test --test-isolation=none
```

This starts WS on `127.0.0.1:8080`. Launch two GrimTable instances. Keep the
default network URL, create an online room in one, and join its code in the other.
Local WebRTC can connect without STUN/TURN. This does not validate remote NAT
traversal. `/health` returns protocol version 1 and does not disclose room data.
Use Ctrl+C to stop the service.

Automated two-process test (start signaling first):

```powershell
./tools/network_smoke.ps1 -Godot 'C:/path/to/Godot_v4.6.1-stable_win64_console.exe'
./tools/network_smoke.ps1 -Godot 'C:/path/to/Godot_v4.6.1-stable_win64_console.exe' -Lan
./tools/network_smoke.ps1 -Godot './builds/windows/GrimTable.exe' -Exported
```

The test runs the real app/menu session path and gameplay systems in separate
processes, with isolated settings/saves. It compares recorded combat and final
hashes, and checks deployment, movement, undo/redo, damage/casualties, dice,
phase changes and disconnection. For WebRTC it deliberately closes signaling
after connection. Logs are under `.runtime/network-smoke-<timestamp>/`.
The smoke scenario uses demo squads with an open firing lane and wider deployment
zones; it is not written to the player's scenario library.

## Linux VPS deployment

### Clean Ubuntu 24.04 server

Obtain a small Linux VPS with a public IPv4, console/SSH access, and your own
domain. No server purchase, account, DNS registration, or certificate provisioning
was performed by this repository. On a fresh Ubuntu 24.04 LTS server, install
Docker from its [official apt repository](https://docs.docker.com/engine/install/ubuntu/):

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
# Replace this marker with the URL of the repository/fork you control:
git clone YOUR_GRIMTABLE_REPOSITORY_URL grimtable
cd grimtable
```

Use `sudo` for subsequent Docker commands unless your account already has Docker
access. For other distributions follow Docker's corresponding official install
instructions. No development-machine paths belong in server configuration.

Install Docker Engine with Compose v2. Configure DNS A records:

* `signal.example.com` → VPS public IP, for HTTPS/WSS.
* `turn.example.com` → VPS public IP, for STUN/TURN (direct DNS, no HTTP CDN proxy).

Copy and edit the example; the placeholder IP/domain are not working services:

```sh
cp infra/.env.example infra/.env
chmod 600 infra/.env
# Generate a secret, then paste it into TURN_SHARED_SECRET in infra/.env:
openssl rand -hex 32
# Edit infra/.env: secret, actual public IP, realm, STUN_URLS, TURN_URLS.
docker compose --env-file infra/.env -f infra/docker-compose.yml config --quiet
docker compose --env-file infra/.env -f infra/docker-compose.yml up -d --build
docker compose --env-file infra/.env -f infra/docker-compose.yml logs --tail=50 signaling
```

Compose builds `server/signaling/Dockerfile` and starts coturn
`coturn/coturn:4.18.0-r0`. Coturn uses Linux host networking to preserve relay
addresses and avoid a large Docker NAT port mapping. The signaling port binds
only to the VPS loopback interface. The Compose file is a **Linux VPS** deployment,
not a Docker Desktop coturn recipe. It is provided and structurally checked;
Docker image builds and coturn runtime were not available on the development host.

Configure a TLS reverse proxy for `signal.example.com` to
`http://127.0.0.1:8080`, including WebSocket upgrades. An optional host Caddy example
is in `infra/Caddyfile.example`; nginx or another proxy also works. Supply your own
domain/TLS deployment. The application only accepts WSS for remote signaling.
Set GrimTable's Network Server Settings to `wss://signal.example.com` on both PCs.

For a concrete host Caddy setup using an **already provisioned** certificate,
install Caddy with its [official Debian/Ubuntu package procedure](https://caddyserver.com/docs/install#debian-ubuntu-raspbian),
then install your valid full chain and private key on the VPS. The `caddy` service
account needs read access. The following assumes you have securely transferred
the files into the ignored `infra/certs/signal/` directory:

```sh
sudo install -d -o root -g caddy -m 0750 /etc/grimtable/signal
sudo install -o root -g caddy -m 0640 infra/certs/signal/fullchain.pem /etc/grimtable/signal/fullchain.pem
sudo install -o root -g caddy -m 0640 infra/certs/signal/privkey.pem /etc/grimtable/signal/privkey.pem
sudo install -m 0644 infra/Caddyfile.manual-tls.example /etc/caddy/Caddyfile
# Edit /etc/caddy/Caddyfile: replace signal.example.com with your real DNS name.
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
curl --fail https://signal.example.com/health
```

The manual TLS example does not buy domains or provision certificates. The
shorter original `Caddyfile.example` remains an optional automatic-HTTPS example
for operators who intentionally choose that deployment. Caddy handles WebSocket
upgrades without a separate path rule. Certificate renewal/reload is the
operator's responsibility for manual TLS. Never disable verification to get a
smoke test to pass.

### Firewall

| Inbound | Purpose |
|---|---|
| TCP 443 | HTTPS/WSS reverse proxy |
| TCP 80, if your TLS deployment requires it | HTTP redirect / certificate validation |
| UDP 3478 | STUN binding and TURN/UDP client allocation |
| TCP 3478 | TURN/TCP client allocation |
| UDP 49160–49260 | Coturn relay allocation range (default `TURN_MIN_PORT`–`TURN_MAX_PORT`) |
| TCP 5349, optional | TURN over TLS, only if configured below |

Allow outbound network traffic for coturn to reach clients. The game clients do
not need forwarded router ports. Direct IP fallback uses UDP 7777 by default and
does require a reachable host port for internet use.

Apply those rules in **both** the VPS provider firewall and the host firewall.
For UFW with the default relay range, allow your actual SSH port before enabling
the firewall (port 22 below assumes the default). Add TCP 5349 only with TURN TLS:

```sh
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 49160:49260/udp
# Optional TURN TLS:
sudo ufw allow 5349/tcp
sudo ufw enable
```

Coturn uses host networking, so these exact host UDP/TCP rules apply; no Docker
bridge relay port publication is involved. Signaling publishes only loopback
8080. Do not add a public 8080 rule. If `TURN_MIN_PORT`/`TURN_MAX_PORT` change,
update UFW and provider rules to the identical range. Check the startup range in
coturn logs against the firewall. IPv6 is not enabled by this IPv4 VPS recipe;
do not publish AAAA records until IPv6 routing/firewall/TURN are configured.

`TURN_EXTERNAL_IP` must match the public IPv4 of the VPS; for a cloud VM behind
1:1 NAT use coturn's `public/private` mapping form. Keep the server clock in sync.
The example blocks private/multicast/loopback relay peers to avoid exposing
private services. Test relay with clients connecting to a public VPS. A local
loopback coturn test requires a separate private development configuration;
do not weaken these production blocks just to make a local relay test pass.

`TURN_LISTENING_IP` defaults to `0.0.0.0`. `TURN_RELAY_IP` defaults to the local
part of `TURN_EXTERNAL_IP` (`public/private` mapping), or to that public IP if no
mapping is present. The relay address **must exist on a VPS interface**. Verify
with `ip -4 address` before starting. Startup rejects malformed IPv4 values,
invalid secret/realm, reversed/out-of-range relay ports, and missing TLS files.
It prints configuration status and the relay port range without exposing secrets.

### Environment

| Variable | Default / purpose |
|---|---|
| `TURN_SHARED_SECRET` | Required private random secret, shared by signaling/coturn only |
| `TURN_EXTERNAL_IP` | Required actual VPS public IPv4 or public/private mapping |
| `TURN_REALM` | Coturn authentication realm, e.g. `turn.example.com` |
| `STUN_URLS` | Comma separated `stun:` URLs supplied to room members |
| `TURN_URLS` | Comma separated `turn:` / `turns:` URLs supplied with temporary credentials |
| `TURN_TTL_SECONDS` | 7200; credential TTL, refreshed/cached before expiry; live allocation replacement unsupported |
| `ROOM_TTL_SECONDS` | 1800; waiting-room lifetime |
| `MATCH_TTL_SECONDS` | 43200; fixed joined-match signaling/token lifetime |
| `TURN_LISTENING_IP` | `0.0.0.0`; listener interface |
| `TURN_RELAY_IP` | Local address for allocations; derived from public/private mapping if empty |
| `TURN_MIN_PORT`, `TURN_MAX_PORT` | 49160, 49260; relay UDP range, update firewall when changing |
| `TURN_TLS` | False; true requires TLS overlay and readable certificate files |
| `METRICS_ENABLED` | False; optional `/metrics` returns aggregate counters only |
| `HOST`, `PORT` | Standalone Node bind defaults `127.0.0.1`, 8080; container binds all internally |
| `TRUST_PROXY` | False; only set true if backend is exclusively behind a trusted proxy overwriting `X-Real-IP` |
| `ALLOWED_ORIGINS` | Optional comma-separated browser Origin allowlist; leave empty for native clients |

No permanent username/password is shipped in the client. Room creation/join issues
a short-lived `timestamp:random_connection_id` username. Password is Base64
HMAC-SHA1(username, shared secret), coturn's documented TURN REST mechanism.
The shared secret is read from environment into a mode-600 tmpfs coturn config;
it is not passed in process arguments. Never commit `.env`, credentials, or SDP.
Room admission is anonymous and rate-limited, not account authentication. People
who can create a room can obtain temporary relay access; quotas and firewall
controls are necessary to limit public-server abuse.

### TURN over TLS (optional)

The example supports TURN over UDP/TCP 3478. Gameplay data remains DTLS-encrypted.
For restrictive networks, provision a valid certificate for `turn.example.com`,
copy its chain/key to `infra/certs/turn/fullchain.pem` and `privkey.pem` with
appropriate permissions for the container, set `TURN_TLS=true`, and start with
the optional overlay. The directory is gitignored. Expose TCP 5349 and include
`turns:turn.example.com:5349?transport=tcp` in `TURN_URLS`. This is separate from
WSS reverse-proxy TLS; Caddy's HTTP proxy does not relay TURN traffic.

```sh
docker compose --env-file infra/.env -f infra/docker-compose.yml -f infra/docker-compose.tls.yml up -d --build
```

When renewing TURN certificates, copy the updated chain/key into that mounted
directory and restart coturn in a maintenance window. Updating files alone does
not reload a running server. This interrupts relayed games; plan accordingly.

## Operational limits and privacy

Messages are capped at 64 KiB, SDP at 60,000 characters, candidates at 2,048.
Compression is off. Per-address limits: 30 connections/minute, 6 room creation
attempts/minute, 20 join attempts/minute. Per-connection message limit:
240/minute. Maximum 1,000 connections and 500 rooms per process. Heartbeats remove
dead connections; room sweeps expire abandoned rooms. Names are sanitized and
limited to 32 characters. Unknown message types, binary frames, incompatible
versions, invalid fields and wrong-role SDP are rejected.

The service trusts no forwarding headers by default. Behind a proxy, limits are
shared under the proxy IP unless `TRUST_PROXY=true` and the proxy supplies a
trusted `X-Real-IP`. Caddy's sample leaves this false deliberately; tune your
proxy/edge limits for a larger community deployment. Do not expose port 8080
publicly while trusting arbitrary forwarding headers. Use a single signaling
instance: rooms are in memory, so scaling replicas needs sticky routing or a
future shared room coordinator.

Logs contain operational events/error codes, not room codes, IP addresses, SDP,
ICE candidates, TURN credentials or secrets. Native Godot/plugin verbose logging
can include connection internals: use it only locally. Coturn defaults to warning
logs; do not enable verbose public connection logging casually. Configure normal
reverse-proxy log retention according to your privacy policy.

### Public backend verification

From a machine with Node.js 22+ and `npm ci --ignore-scripts` completed in
`server/signaling`, run:

```sh
node tools/probe_backend.mjs --signal-url=wss://signal.example.com
```

This verifies HTTPS health/TLS using Node's certificate trust, WSS upgrade,
room creation/join, SDP/ICE message forwarding, authenticated credential renewal,
STUN binding, and authenticated TURN allocation/release for each supplied URL.
TURN responses have their message integrity checked. It never prints credentials,
tokens, SDP, or client IPs. The forwarding probe uses labeled test payloads; it
does **not** establish a WebRTC peer connection. Allocation is not evidence that
the advertised relay address is reachable from both players. Windows Godot trust
and a real two-network gameplay test are separate required checks.

For actual expiry rejection, use a separate test deployment with
`TURN_TTL_SECONDS=60`, then:

```sh
node tools/probe_backend.mjs --signal-url=wss://signal.example.com --check-expiry
```

The probe allocates successfully, waits past the issued TTL, then requires an
authentication rejection for the same credentials. Network timeout is **not**
counted as expiry rejection. Restore production TTL afterward. CI contains a
private loopback coturn fixture for this test; it has not been run remotely here.

### Testing relay on genuinely separate networks

With your public VPS stack running, test from two desktop clients:

```powershell
# Machine A, home network; read the room code from its host.log:
./tools/internet_peer.ps1 -Godot './builds/windows/GrimTable.exe' -Role host `
  -SignalingUrl 'wss://signal.example.com' -ForceTurn

# Machine B, another ISP / phone hotspot; use the code printed by Machine A:
./tools/internet_peer.ps1 -Godot './builds/windows/GrimTable.exe' -Role guest `
  -SignalingUrl 'wss://signal.example.com' -RoomCode ABCDEF -ForceTurn
```

Both clients filter non-relay SDP/ICE candidates. A pass therefore requires real
TURN allocations; compare hashes/combat in the resulting logs. The normal UI
reports route as unavailable because the native API does not expose a selected
candidate pair. **TURN fallback was not runtime-tested in this environment.**
Do not treat a local P2P pass as a relay pass.

Omit `-ForceTurn` for normal ICE. Both machines must opt into forced relay for
the diagnostic to exclude all direct candidates. The script passes `--force-turn`
to the app and gives the host five minutes to invite the guest. Ordinary UI users
can also launch the build with `-- --force-turn` for a diagnostic session, then
use the normal create/join menus. The setting is deliberately not prominent.

Do not use `tools/network_smoke.ps1` as evidence of different networks: it starts
both processes on one machine, even when pointed at a public service. Use it for
local regression and latency checks. `-DelayMs 50`, `100`, or `200` adds that much
outbound **application** delay on each side. It is not OS packet-loss emulation.

### Failure exercises

Use `-KeepSignaling -HoldSeconds 30` on both single-peer commands to leave a
window for an operator to inject a failure after negotiation/credential refresh.
The default test instead closes host signaling intentionally before playing.

| Exercise | Operator action | Required evidence |
|---|---|---|
| Signaling failure during established direct game | `docker compose ... stop signaling` | Gameplay finishes, dice/hashes equal; diagnostics distinguish signaling unavailable |
| New room while service is down | Create Online Game | Actionable service/TLS/DNS message within 15 seconds; Cancel remains available |
| Coturn failure during a known direct game | `docker compose ... stop coturn` | Gameplay continues; do not label direct from candidate types alone |
| Coturn failure during forced relay | Stop coturn after relay connection | Connection-lost state without crash; host can continue locally |
| Invalid relay secret / blocked listener | Separate test deployment only | No relay candidate or timeout with useful TURN diagnostics |
| Block relay range | Temporary firewall rule on test VPS | Allocation may succeed, but forced gameplay must fail cleanly |
| Invalid WSS/TURN certificate or DNS | Separate test hostname/config | Certificate validation stays enabled; clean connection failure |

Use the full Compose invocation from above in place of `docker compose ...`.
Restore the service/firewall after each exercise. Do not interrupt other people's
matches to run failure tests. The API cannot expose coturn's exact authentication
failure reason, so client messages list possible causes rather than falsely
asserting that a secret is wrong. Use the backend probe and server-side health
to isolate the cause.

### TURN troubleshooting

| Symptom | Check |
|---|---|
| No relay candidate | TURN hostname resolution; TCP/UDP 3478; temporary credential TTL; identical secret on signaling/coturn |
| Allocation succeeds, forced gameplay fails | `TURN_EXTERNAL_IP`, actual local `TURN_RELAY_IP`, UDP relay range on provider firewall **and** host firewall |
| VPS behind NAT | Use `public/private` mapping, relay IP must be local/private address, NAT must preserve the allocated relay port |
| Auth 401/441 after challenge | Wrong shared secret or expired credentials; keep both servers' clocks synchronized |
| Realm/auth problems | One consistent configured realm; probe derives auth from the actual challenge realm; clear stale test config |
| TURN TLS fails | Correct SAN for `turn.example.com`, full certificate chain, readable key, TCP 5349, TLS overlay enabled |
| WSS fails on Windows | Valid public certificate chain and hostname, correct system clock/trust store; never disable verification |
| Works on LAN only | Public IP and relay ports, CGNAT/symmetric NAT; run forced test from separate networks |

Useful VPS diagnostics (outputs can include infrastructure IPs; do not post
credentials or full SDP):

```sh
getent ahostsv4 signal.example.com turn.example.com
ip -4 address
ss -lntup | grep -E ':(443|8080|3478|5349)\b'
curl --fail https://signal.example.com/health
openssl s_client -connect signal.example.com:443 -servername signal.example.com -verify_return_error </dev/null
openssl s_client -connect turn.example.com:5349 -servername turn.example.com -verify_return_error </dev/null
docker compose --env-file infra/.env -f infra/docker-compose.yml logs --tail=100 coturn
```

The pinned native WebRTC API cannot replace live ICE credentials or restart ICE.
See [RECONNECT.md](RECONNECT.md) for the exact renewal/reconnect scope and blockers.

### Updating / stopping

Pull reviewed source updates, run tests, then rebuild signaling and pull the
pinned/reviewed coturn image. Recreate services during a maintenance window;
signaling restarts discard rooms. Existing direct WebRTC gameplay is independent
of signaling; restarting coturn will interrupt relayed sessions.

```sh
docker compose --env-file infra/.env -f infra/docker-compose.yml build signaling
docker compose --env-file infra/.env -f infra/docker-compose.yml pull coturn
docker compose --env-file infra/.env -f infra/docker-compose.yml up -d
docker compose --env-file infra/.env -f infra/docker-compose.yml down
```

There is no database to migrate. Save/replay files stay on player machines.
