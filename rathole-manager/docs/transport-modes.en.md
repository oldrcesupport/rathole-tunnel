# Traffic Transport Modes — Comprehensive Reference (v1.8.9)

`rathole-manager` supports multiple underlying transport protocols to match different network environments and censorship severity levels. On each node, a single state variable (`TUNNEL`) dictates the active transport mode.

---

## 1. Transport Modes Comparison

| Mode | Layer & Protocol | Public Port | Overhead | Censorship Resistance | Best Suited For |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **WebSocket + TLS** | L7 (HTTPS) | 443 | Medium | Very High (Camouflaged) | Everyday browsing, video streaming, regular workloads |
| **XHTTP (SplitHTTP)** | L7 (Chunked HTTP) | 443 | Medium | Maximum (Anti-DPI) | Severe disruption scenarios and AI-based firewalls |
| **Gaming (Game / Vision)** | L4 (SNI Passthrough) | 443 | Minimal | High (Direct TLS Stream) | Competitive gaming, VoIP, real-time calls, minimum latency |
| **KCP (UDP+FEC)** | L4 (QUIC Emulation) | 443 (UDP) | Higher | High (Packet-loss immune) | Jittery networks with heavy international packet loss |
| **Noise** | L4 (ChaCha20) | Custom (2334) | Very Low | High (Pure Cryptography) | Fast node-to-node links without domain dependencies |
| **Backhaul (SMUX)** | L4 / L7 (TCP/WS) | 443 / Direct | Low | Very High (Multiplexed) | Stream consolidation and connection optimization |

---

## 2. In-Depth Transport Details

### 1) WebSocket + TLS (Default)
- Standard reverse tunnel compatible with VLESS+WS and VMess+WS.
- Terminated on Nginx port 443 with path multiplexing to local rathole data ports.

### 2) Modern XHTTP (SplitHTTP)
- Utilizes `chunked_transfer_encoding on` with zero proxy buffering.
- Emulates asynchronous bidirectional web communications, avoiding conventional WebSocket traffic signatures.

### 3) Layer 4 Gaming Mode (Game 0-RTT Vision)
- **Zero Latency Passthrough:** Handled by Nginx Stream module directly on port 443. Routes traffic based on SNI (e.g. `game.yourdomain.com`) straight to the foreign node without Layer 7 inspection or TLS termination on the Iran server.
- Supports **0-RTT Vision** and **UDP FullCone** for the lowest possible ping in online gaming.
- Activation command:
  ```bash
  sudo ratholectl game add mygame 20001 game.example.com
  ```

### 4) KCP Forward Error Correction (UDP+FEC)
- Simulates Google QUIC protocol over UDP port 443.
- Utilizes Reed-Solomon coding to recover dropped packets transparently.
- Three tuned profiles: `balanced`, `lossy`, and `aggressive`.
- Activation command:
  ```bash
  sudo ratholectl kcp on 443 balanced
  ```

### 5) Noise & Backhaul
- **Noise:** Ultra-fast cryptographic tunnel based on Noise Protocol Framework (ChaCha20-Poly1305 + Curve25519) without PKI or certificate requirements.
- **Backhaul:** Multiplexes concurrent TCP streams over a persistent channel, minimizing handshake overhead.

---

## 3. Alternative Ingress Modes

- **Direct-IP:** Direct client access using custom routing headers (`X-Cdn-Id: <node_name>`) on port 8081 without domain names.
- **Reverse Proxy:** Forwarding path requests (`/<name>/`) to external non-rathole backends.

---

## 4. Related Documentation
- [Architecture (`architecture.en.md`)](architecture.en.md)
- [Traffic Flow (`traffic-flow.en.md`)](traffic-flow.en.md)
- [Persian Guide (`transport-modes.md`)](transport-modes.md)
