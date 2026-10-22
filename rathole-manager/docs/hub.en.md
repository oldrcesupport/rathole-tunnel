# ratholehub — Central Management Web Panel & REST API

`ratholehub` is a centralized multi-server web dashboard and API that provides visual management for multiple Iran edge relays and external nodes without opening unnecessary ports or installing external daemons on target servers.

![Hub Architecture](assets/hub-architecture.svg)

---

## 1. Key Features & Hardened Architecture

- **Agentless over SSH:** Installs on a single relay (typically the primary Iran server) and issues validated commands to downstream nodes via **SSH with public key authentication**. No background agents or extra ports required on nodes.
- **Zero Third-Party Dependencies:** 100% Python 3 standard library. Runs out-of-the-box without `pip` or virtual environments.
- **PBKDF2-HMAC-SHA256 Password Hashing:** User passwords are encrypted using PBKDF2 with 100,000 iterations. Legacy SHA-256 hashes are detected and automatically upgraded on login.
- **Anti-Spoofing Rate Limiter:** The rate limiter resolves client IPs securely; proxy headers (`X-Real-IP`, `X-Forwarded-For`) are only honored when requests originate from trusted loopback proxies (`127.0.0.1`, `::1`), preventing rate limit bypass via forged HTTP headers.
- **Automated Secret Redaction:** Tokens, passwords, private keys, and positional arguments are intercepted and scrubbed (`***REDACTED***`) via `redact_cmd()` before being recorded to `audit.log` or console outputs.
- **Atomic State Persistence (`save_json`):** Configuration and inventory files are written to process-unique temp files with `0600` permissions and atomically swapped (`os.replace`), guarding against data corruption or empty state files.

---

## 2. Installation & Access

### A) Installation
```bash
cd /root/rathole-manager/ratholehub
sudo bash install-hub.sh
```
The installer guides you through setting an admin password and generates an API token.

### B) Secure Access
The recommended method (without exposing public ports) is using SSH local port forwarding:
```bash
ssh -L 8088:127.0.0.1:8088 root@<IRAN_IP>
# Browser: http://localhost:8088
```
Alternatively, expose it behind Nginx under your relay domain:
```bash
sudo ratholectl hub on 8088
# Browser: https://<domain>/hub/
```

---

## 3. Web UI Overview

The responsive interface located in `ui/` includes:
- **Dashboard (`#/dashboard`):** Real-time server cards, reachability indicators, automated provisioning wizard, and quick actions.
- **Server View (`#/server/<name>`):** Node inventory table, available transports toggle (KCP, Plain, Noise, Backhaul), and exclusive per-node transport selector.
- **Routing View (`#/routing`):** Interactive SVG visualization showing end-to-end traffic flow from user to the internet.
- **Audit Logs (`#/audit`):** Tamper-evident operation records with timestamps, user, target server, and exit codes with scrubbed secrets.
- **Settings (`#/settings`):** Language selection, auto-refresh intervals, SSH key management, and TLS domain settings.

---

## 4. REST API Reference

All API calls must include the `X-API-Token` header or valid session cookies:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/status` | Hub service health and basic system metrics |
| `GET` | `/api/servers` | Server inventory with connection status |
| `POST` | `/api/servers` | Register a new server to the inventory |
| `DELETE` | `/api/servers/<id>` | Remove a server from inventory |
| `POST` | `/api/action` | Execute a whitelisted management action on a server (`add`, `rm`, `ls`, etc.) |
| `GET` | `/api/audit` | Fetch redacted security audit logs |
| `POST` | `/api/login` | Authenticate with username and password |

---

## 5. Related Documentation
- [System Architecture (`architecture.en.md`)](architecture.en.md)
- [Transport Modes (`transport-modes.en.md`)](transport-modes.en.md)
- [Persian Hub Guide (`hub.md`)](hub.md)
