<div align="center">

<img src="assets/logo.svg" alt="rathole-tunnel" width="110" height="110" />

# Full Installation Guide — rathole-tunnel

**Iran panel + foreign nodes + central hub** — version 1.8.9

_Every command and scenario below was executed and verified on a real server pair (Ubuntu 24.04)._

[**فارسی**](install-manual.fa.md) · [CLI reference](wiki/CLI-Reference.md) · [Web hub](hub.en.md)

</div>

## 1. Prerequisites

| Requirement | Value |
| :--- | :--- |
| OS | Ubuntu 20.04+ / Debian 11+ — x86_64 or arm64 |
| Access | root |
| Iran panel | free ports: `443/tcp` (+ `443/udp` for KCP, `2334/tcp` for Noise, plain/direct ports if used) |
| Foreign node | one local port per service (e.g. `2087`) + outbound HTTPS to the panel |
| Domain (optional) | A record → panel IP + fullchain/privkey, or certbot |

Packages (`nginx jq curl unzip openssl python3 certbot sshpass`) are installed automatically. The rathole binary ships in the bundle and is verified against `core/SHA256SUMS`.

### Port table

| Server | Port | Exposure | Purpose |
| :--- | :--- | :--- | :--- |
| Iran | 443/tcp | public | nginx TLS — control (secret `/_rh/…` path), per-node paths `/<name>`, hub `/hub/`, proxies |
| Iran | 443/udp | public | KCP mode only |
| Iran | 2334/tcp | public | Noise mode only |
| Iran | 8880 / 8090 … | public | plain / direct modes only |
| Iran | 2333 / 8080 / 2096 / 1001+ / 8088 | 127.0.0.1 only | control / decoy site / subscription / data ports / hub (loopback by design) |
| Node | 2087+ | 127.0.0.1 only | service inbounds (Xray/3x-ui) |

## 2. Panel install (Iran)

**One-liner with a domain:**

```bash
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel \
  --domain panel.example.ir \
  --fullchain /root/cert/panel.example.ir/fullchain.pem \
  --key /root/cert/panel.example.ir/privkey.pem
```

**Interactive:** `... | sudo bash -s -- --panel` (prompts for domain/cert/ports; without a tty it prints guidance instead of hanging).

**IP-only server:** install with the IP as the domain, then:

```bash
sudo ratholectl ip-cert <IPv4>     # self-signed cert with SAN=IP, switches the 443 vhost
sudo ratholectl ip-cert-show       # public cert to trust on nodes
```

**certbot:** `sudo ratholectl cert panel.example.ir admin@example.ir`
**Cert obtained elsewhere:** `sudo ratholectl set fullchain <fc>` / `set key <k>` / `set domain <d>`

Install order: deps → rathole binary (checksum) → ratholectl/common.sh → systemd unit → nginx + websocket map → init (state, server.toml, rathole.conf) → nginx reload → start/enable service → decoy site. **Any failure (nginx -t, port bind) rolls everything back**; since v1.8.9 the real listener bind is verified with `ss` after reload.

## 3. Node install (foreign server)

```bash
# on the panel:
sudo ratholectl add trk01 2087 && sudo ratholectl token trk01

# on the node — domain mode (cert verified with the system CA store):
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --node -- \
  --server panel.example.ir:443 --name trk01 --token <TOKEN> --inbound-port 2087

# IP mode (panel self-signed):
#   --server 213.0.113.10:443 --tls-hostname 213.0.113.10 --tls-trusted-root /root/panel-ip.pem
```

Validation: name `[A-Za-z0-9_-]`, token `[A-Za-z0-9._=+/-]`, port 1-65535. Re-running the installer on a configured node takes a timestamped backup first and warns that the tunnel reverts to ws.

Then create the real inbound (VLESS+WS in 3x-ui): `listen=127.0.0.1`, `port=2087`, `path=/trk01`, TLS off.

Verify: `ratholenode status` on the node and `sudo ratholectl doctor` on the panel — "node … amade ast" means the tunnel is connected.

More services on the same tunnel: panel `sudo ratholectl add trk02 2088` → node `ratholenode add-svc trk02 <TOKEN> 2088`.

## 4. Update / rollback / uninstall

```bash
sudo ratholectl update stable        # panel (also: beta / vX.Y.Z)
ratholenode update stable            # node — the downloaded install.sh is verified against the release SHA256SUMS
sudo bash /opt/rathole-manager/update.sh --list-backups
sudo bash /opt/rathole-manager/update.sh --rollback [timestamp]
sudo bash /opt/rathole-manager/bootstrap.sh --uninstall     # full removal (confirmed)
sudo bash /opt/rathole-manager/bootstrap.sh --purge --yes   # + binaries / hub config / kcptun
```

Every update takes a full snapshot first; a failed health check triggers automatic rollback. A downgrade guard blocks accidental rollbacks from beta (`--allow-downgrade` to force).

## 5. Hub (web panel) — summary

```bash
sudo ratholectl hub on 2087     # first run installs the hub → https://<domain>/hub/
```

Admin password login (PBKDF2), server inventory + audit log, SSH-password provisioning, remote actions, token rotation. Full guide: [`hub.en.md`](hub.en.md)

## 6. Quick troubleshooting

| Symptom | Cause / fix |
| :--- | :--- |
| doctor: node port not listening | node down, or the token was rotated — after rotate: `ratholenode add-svc <name> <TOKEN> <port>` |
| `Service not exist` in the node journal | the node-side service name must exactly match the panel node name |
| `bind() failed` | port collision — use another port; since v1.8.9 failed binds roll back |
| 30s lock timeout | concurrent operation — retry shortly |
| Log bundle for support | `sudo ratholectl logs 200 --bundle` (tokens redacted) |

More: [`wiki/Troubleshooting.md`](wiki/Troubleshooting.md)
