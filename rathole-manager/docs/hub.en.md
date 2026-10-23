# ratholehub — Central Management Web Panel & REST API

`ratholehub` is a multi-server management panel that works over SSH (no agent on managed servers) — a single Python 3 stdlib file, no pip. Every capability in this document was executed and verified on a real server pair (v1.8.9).

## Installation

```bash
sudo ratholectl hub on 2087
```

* First run executes `install-hub.sh`: generates the hub SSH key at `/etc/ratholehub/id_ed25519`, prompts for the admin password **interactively from the tty** (errors out without a tty), writes the config with **PBKDF2-HMAC-SHA256**, starts `ratholehub` on `127.0.0.1:2087`, and creates the nginx `/hub/` block.
* URL: `https://<domain>/hub/` — the hub never listens on a public interface.
* Re-running the installer never touches an existing config (token/password preserved).
* Zero-port access: `ssh -L 2087:127.0.0.1:2087 root@<panel>` → `http://localhost:2087`

## Security (actual behavior)

| Item | Behavior |
| :--- | :--- |
| Password | PBKDF2-HMAC-SHA256, 100k iterations + salt; legacy sha256 hashes upgrade automatically on first login |
| Session | `rhsession` cookie `HttpOnly; SameSite=Strict` + `Secure` behind TLS (needs `X-Forwarded-Proto` — present in the generated nginx block); **changing the password instantly invalidates every session** |
| API token | `Authorization: Bearer <api_token>` — no expiry; revoked only by rotation |
| Login limiting | 5 attempts / 300s per IP, atomic (race-safe) → 429 |
| Headers | `X-Frame-Options: DENY` + `CSP frame-ancestors 'none'` + `nosniff` |
| Audit log | `/etc/ratholehub/audit.log` (0600) — every write op including server add/delete; commands redacted |
| Server access | hub SSH key only; `ssh_opts` validated against a whitelist (ProxyCommand/LocalCommand/… forbidden) |

> The API token is also returned by `/api/login` and stored by the UI in localStorage — log out on shared machines and rotate when in doubt.

## Using the UI

* **Servers:** manual add (`role: iran/node`), edit, delete — all audited.
* **Provision:** `host` + `ssh_user` + `ssh_port` + SSH password → the hub installs its key with sshpass, deploys the scripts (release download with checksum verification) and registers the server. For nodes, an `iran`-role server must exist in the inventory first.
* **Server page:** live overview (manager/rathole versions, services, doctor), actions: show/status/restart/logs/update(deploy)/regen + kcp/plain/noise/backhaul switching + watchdog/adaptive/fakeweb/proxy/game + upstreams.
* **Routing:** graphical path view; **Audit:** operation log; **Settings:** password change (kills sessions), token rotation, ssh_opts, key path.

## REST API

All routes under `/hub/api/...` (behind nginx) or unprefixed on loopback. Auth: session cookie or `Authorization: Bearer`.

| Method & path | Purpose |
| :--- | :--- |
| `POST /api/login` `{password}` | login → token + cookie (429 after 5 failures) |
| `GET /api/health` | health (no auth) |
| `GET /api/servers` | inventory |
| `POST /api/servers` `{name,role,host,ssh_user,ssh_port}` | add (409 duplicate, 400 invalid) |
| `PUT /api/servers/<name>` | edit host/user/port |
| `DELETE /api/servers/<name>` | delete (404 if missing) — all audited |
| `POST /api/provision` `{name,role,host,ssh_user,ssh_port,ssh_password}` | full auto-install |
| `GET /api/servers/<n>/overview` / `/details` | live status (versions, services, doctor) |
| `POST /api/servers/<n>/action` `{action,args}` | whitelisted action execution |
| `GET /api/audit?limit=N` | audit log |
| `GET /api/config` / `POST /api/config` | safe view / change password (`current_password`,`new_password`) and `rotate_token` |
| `GET /api/hubstatus` | hub version + latest release |

Allowed actions (samples): `show, ls, status, restart, logs, doctor(panel), regen_full, backup, paths, add_node, rm_node, edit_node, rename_node, rotate_node, set_config, kcp_on/off/status, plain_on/off, noise_on/off/node_on/node_off, backhaul_on/off/node_on/node_off/show, direct_on/off, proxy_add/ls/rm, game_add/ls/rm, fakeweb_*, watchdog_*, adaptive_*, upstream_*, deploy, tune, migrate`. Unknown action or missing server → explicit error; every action response carries `rc`.

## Operational notes (tested)

* **Panel whose port 22 is externally blocked:** the hub can SSH to itself over loopback — `PUT /api/servers/<n> {"host":"127.0.0.1"}` on the panel's own inventory entry and its actions keep working.
* `deploy` (update from GitHub) can take minutes through the anti-censorship mirrors — poll `overview` for the new version.
* Hub path change: `sudo ratholectl set hub-path <seg>` + `hub on <port>`.
* Disable: `sudo ratholectl hub off` (service and credentials kept; full removal via `bootstrap.sh --purge`).
