# System Architecture — Three Roles, Core Principles & Security Hardening (v1.8.9)

`rathole-manager` is a production-grade, modular, and hardened reverse tunnel management system built on **rathole + Nginx**. An edge relay in Iran (fronted by a single domain, valid TLS certificate, and port 443) multiplexes traffic to multiple external nodes connected via reverse tunnels.

![Architecture Overview](assets/architecture.svg)

---

## 1. Three Roles, Three Executables

| Role | Binary / Script | Stack | Responsibilities |
| :--- | :--- | :--- | :--- |
| **Iran Panel** | [`ratholectl`](../rathole-manager/ratholectl) | Bash (zero-dep) | Manages rathole-server & Nginx, maintains state inventory, generates hardened `server.toml` & `rathole.conf`, manages TLS certs and active fake web probe defense. |
| **External Node** | [`ratholenode`](../rathole-manager/ratholenode) | Bash (zero-dep) | Manages rathole-client, establishes reverse tunnel to Iran, generates `client.toml`, and maps ports to local Xray/V2Ray inbounds. |
| **Central Hub** | [`ratholehub/hub.py`](../rathole-manager/ratholehub/hub.py) | Python 3 (stdlib only) | Central visual web panel & REST API managing multiple servers over secure SSH using sanitized argv lists, PBKDF2 authentication, and tamper-evident audit logging. |

The shared library [`common.sh`](../rathole-manager/common.sh) is sourced by all Bash tooling to enforce `umask 077`, fail-closed file locking, numeric port validation, BBR kernel tuning, and fake web server templates.

---

## 2. Core Architectural Principles (Hardened Core)

### A) Atomic Mutation Cycle: State → Regenerate → Hot-Reload
Configs are never manually altered. All changes follow a transactional path:
1. **Transactional State (`rth_state_tx`):** Every mutation writes to a secure temporary file (`0600`), validates JSON integrity, and atomically swaps the state file.
2. **Fail-Closed Locking (`rth_with_lock`):** If a lock file cannot be acquired or opened, the process terminates immediately with a non-zero exit code, preventing race conditions and silent unlocked runs.
3. **Zero-Downtime Hot-Reload:** Configurations are written in-place to preserve inodes so that rathole's `config_watcher` updates tunnels without dropping active user connections. Nginx syntax is validated via `nginx -t` prior to reload, with automatic fallback to `.rathole-good.bak` on failure.

### B) Path Alignment: Path == Node Name == Nginx Map == Xray Inbound
In Layer 7 mode, a node name (e.g., `trk01`) aligns across three planes:
- Client request URL: `https://domain.com/trk01`
- Nginx upstream map: `map $uri $backend_port`
- Target node Xray inbound: `path: /trk01`

---

## 3. Active Probe & Censorship Defense

The architecture provides active defense against Deep Packet Inspection (DPI) and active network probing:
- **Fake Web 200 OK:** Unauthenticated root (`/`) requests or scanning probes receive a clean corporate website response with status `200 OK` rather than suspicious 502 Bad Gateway or closed ports.
- **Hidden Control Path:** Node reverse tunnels connect through an obfuscated, randomized path using standard WebSocket upgrade headers.
- **Unbuffered XHTTP (SplitHTTP):** Real-time chunked streaming with disabled buffering to evade machine-learning traffic classifiers.

---

## 4. Supported Transport Modes

The system supports multiple transport protocols suited for varied ISP filtering conditions:
1. **WebSocket + TLS (Default):** Standard HTTPS camouflage on port 443 behind Nginx.
2. **XHTTP (SplitHTTP):** Resilient bidirectional web stream protocol with zero buffering.
3. **Layer 4 Gaming (Game 0-RTT Vision):** Zero-latency direct TCP/UDP SNI passthrough via Nginx Stream module without L7 interception or TLS decryption on the Iran server.
4. **KCP (UDP+FEC):** Packet-loss mitigation protocol utilizing Reed-Solomon forward error correction, simulating Google QUIC on UDP port 443.
5. **Noise & Backhaul (SMUX):** Encrypted ChaCha20-Poly1305 multi-stream tunnels.
6. **Direct-IP & Reverse Proxy:** Custom header-based routing or standalone upstream reverse proxying.

---

## 5. Related Documentation

- [Transport Modes Deep Dive (`transport-modes.en.md`)](transport-modes.en.md)
- [Packet Life Cycle & Flow (`traffic-flow.en.md`)](traffic-flow.en.md)
- [Central Hub Security & API (`hub.en.md`)](hub.en.md)
- [Kernel Tuning & Performance (`performance.en.md`)](performance.en.md)
- [Manual Installation Guide (`install-manual.md`)](install-manual.md)
- [GitHub Wiki CLI Reference](https://github.com/oldrcesupport/rathole-tunnel/wiki/CLI-Reference)
