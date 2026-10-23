#!/usr/bin/env bash
# install-node.sh — nasab samt node kharej (rathole client)
# nasb tazh:
#   sudo bash install-node.sh --server btli.ir:443 [--tls-hostname btli.ir] \
#        [--tls-trusted-root /etc/rathole/ip-root-ca.crt] --name trk01 --token <T> --inbound-port 2087 \
#        [--api-token <T> --api-inbound-port 62050]
# nasb ba CLI (bedoon argument — tanzimat baad az nasb ba ratholenode):
#   sudo bash install-node.sh
# nasb az rooye backup:
#   sudo bash install-node.sh --restore /root/rathole-node-backup-....tar.gz
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RATHOLE_VERSION="${RATHOLE_VERSION:-v0.5.0}"
SERVER="" TLS_HOSTNAME="" TLS_TRUSTED_ROOT="" NAME="" TOKEN="" INBOUND="" API_TOKEN="" API_INBOUND="" RESTORE=""

log(){ printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[*]\033[0m %s\n' "$*"; }
err(){ printf '\033[1;31m[!]\033[0m %s\n' "$*" >&2; }
die(){ err "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --server)            [ $# -ge 2 ] || die "--server be yek meghdar niaz darad."; SERVER="$2"; shift 2;;
    --tls-hostname)      [ $# -ge 2 ] || die "--tls-hostname be yek meghdar niaz darad."; TLS_HOSTNAME="$2"; shift 2;;
    --tls-trusted-root)  [ $# -ge 2 ] || die "--tls-trusted-root be yek meghdar niaz darad."; TLS_TRUSTED_ROOT="$2"; shift 2;;
    --name)              [ $# -ge 2 ] || die "--name be yek meghdar niaz darad."; NAME="$2"; shift 2;;
    --token)             [ $# -ge 2 ] || die "--token be yek meghdar niaz darad."; TOKEN="$2"; shift 2;;
    --inbound-port)      [ $# -ge 2 ] || die "--inbound-port be yek meghdar niaz darad."; INBOUND="$2"; shift 2;;
    --api-token)         [ $# -ge 2 ] || die "--api-token be yek meghdar niaz darad."; API_TOKEN="$2"; shift 2;;
    --api-inbound-port)  [ $# -ge 2 ] || die "--api-inbound-port be yek meghdar niaz darad."; API_INBOUND="$2"; shift 2;;
    --restore)           [ $# -ge 2 ] || die "--restore be yek masir niaz darad."; RESTORE="$2"; shift 2;;
    --version)           [ $# -ge 2 ] || die "--version be yek meghdar niaz darad."; RATHOLE_VERSION="$2"; shift 2;;
    *) die "argument nashenakhte: $1";;
  esac
done

[ "$(id -u)" -eq 0 ] || die "bayad ba root ejra shavad (sudo)."

CONFIG_NOW=0
if [ -n "$RESTORE" ]; then
  [ -f "$RESTORE" ] || die "file backup peyda nashod: $RESTORE"
elif [ -n "$SERVER" ] || [ -n "$NAME" ] || [ -n "$TOKEN" ] || [ -n "$INBOUND" ] || [ -n "$TLS_HOSTNAME" ] || [ -n "$TLS_TRUSTED_ROOT" ]; then
  [ -n "$SERVER" ] && [ -n "$NAME" ] && [ -n "$TOKEN" ] && [ -n "$INBOUND" ] || \
    die "argumenthaye lazem: --server --name --token --inbound-port  (ya --restore <file>)"
  if [[ "$SERVER" =~ ^[A-Za-z0-9_.-]+:([0-9]+)$ ]]; then
    p="${BASH_REMATCH[1]}"
    [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || die "port-e SERVER bayad beine 1 ta 65535 bashad: $p"
  elif [[ "$SERVER" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    SERVER="${SERVER}:443"
  else
    die "SERVER namotabar: $SERVER"
  fi
  [[ "$INBOUND" =~ ^[0-9]+$ ]] && [ "$INBOUND" -ge 1 ] && [ "$INBOUND" -le 65535 ] || die "inbound port bayad beine 1 ta 65535 bashad: $INBOUND"
  if [ -n "$API_INBOUND" ]; then
    [[ "$API_INBOUND" =~ ^[0-9]+$ ]] && [ "$API_INBOUND" -ge 1 ] && [ "$API_INBOUND" -le 65535 ] || die "api inbound port bayad beine 1 ta 65535 bashad: $API_INBOUND"
  fi
  { [ -n "$API_TOKEN" ] || [ -n "$API_INBOUND" ]; } && { [ -z "$API_TOKEN" ] || [ -z "$API_INBOUND" ]; } && \
    warn "--api-token va --api-inbound-port bayad BA HAM dade shavand; API service rad mishavad."
  [ -z "$TLS_HOSTNAME" ] || echo "$TLS_HOSTNAME" | grep -qE '^[A-Za-z0-9_.-]+$' || die "TLS hostname namotabar."
  [ -z "$TLS_TRUSTED_ROOT" ] || echo "$TLS_TRUSTED_ROOT" | grep -qE '^/[A-Za-z0-9_./-]{1,255}$' || die "TLS trusted root namotabar."
  [ -z "$TLS_TRUSTED_ROOT" ] || [ -n "$TLS_HOSTNAME" ] || die "--tls-trusted-root be --tls-hostname niaz darad."
  [ -z "$TLS_TRUSTED_ROOT" ] || [ -f "$TLS_TRUSTED_ROOT" ] || die "TLS trusted root peyda nashod: $TLS_TRUSTED_ROOT"
  # NAME/TOKEN mostaghim dar services.conf (name|token|port) va TOML (token = "...",
  # [client.services.NAME]) mishinand — haman ghayeed-e 'ratholenode add-svc' (fail-closed).
  echo "$NAME" | grep -qE '^[a-zA-Z0-9_-]+$' || die "NAME namotabar (faghat harf/adad/_/-): '$NAME'"
  echo "$TOKEN" | grep -qE '^[A-Za-z0-9._=+/-]+$' || die "TOKEN namotabar (faghat [A-Za-z0-9._=+/-]; '|' / newline / naqol mojaz nist)."
  [ -z "$API_TOKEN" ] || echo "$API_TOKEN" | grep -qE '^[A-Za-z0-9._=+/-]+$' || die "API TOKEN namotabar (hman ghayeed-e TOKEN)."
  CONFIG_NOW=1
fi

case "$(uname -m)" in
  x86_64)  RH_ARCH="x86_64-unknown-linux-gnu" ;;
  aarch64) RH_ARCH="aarch64-unknown-linux-musl" ;;
  *) die "memari poshtibani-nashode: $(uname -m)" ;;
esac

# ---------- nasb rathole ----------
install_rathole(){
  log "nasb pish-niazha va download rathole ${RATHOLE_VERSION}..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y && apt-get install -y curl unzip tar ca-certificates
  local tmp; tmp="$(mktemp -d)"
  local gh="rapiz1/rathole/releases/download/${RATHOLE_VERSION}/rathole-${RH_ARCH}.zip"
  local urls=(
    "https://github.com/${gh}"
    "https://ghproxy.net/https://github.com/${gh}"
    "https://gh-proxy.com/https://github.com/${gh}"
    "https://mirror.ghproxy.com/https://github.com/${gh}"
  )
  local ok=0
  for u in "${urls[@]}"; do
    if curl -fsSL --connect-timeout 20 --speed-limit 1024 --speed-time 30 --retry 2 \
         "$u" -o "$tmp/rathole.zip" 2>/dev/null; then
      if unzip -t "$tmp/rathole.zip" >/dev/null 2>&1; then ok=1; break; fi
    fi
  done
  [ "$ok" -eq 1 ] || die "download rathole az hameye mnaba shekast khord (shabake/filtr?)."
  unzip -o "$tmp/rathole.zip" -d "$tmp" >/dev/null
  install -m 755 "$tmp/rathole" /usr/local/bin/rathole
  rm -rf "$tmp"
}

if ! [ -x /usr/local/bin/rathole ] || ! /usr/local/bin/rathole --version >/dev/null 2>&1; then
  # agar core/SHA256SUMS vojood darad, az binary-e patched-e bundle estefade kon
  if [ -f "$SCRIPT_DIR/core/SHA256SUMS" ] && [ -f "$SCRIPT_DIR/core-install.sh" ]; then
    bash "$SCRIPT_DIR/core-install.sh" 2>/dev/null || install_rathole
  else
    install_rathole
  fi
fi

mkdir -p /etc/rathole /usr/local/share/rathole

# ---------- nasb ratholenode ----------
# ghablan `A && { B; C; } || D` bood: shekast-e install (B) bi-seda rad mishod va «nasb shod»
# chap mishod; ba CLI-e kohde alakar adamh midad (nasb-e nimesh).
if [ -f "$SCRIPT_DIR/ratholenode" ]; then
  install -m 755 "$SCRIPT_DIR/ratholenode" /usr/local/bin/ratholenode || die "nasb-e ratholenode shekast khord."
  log "ratholenode nasb shod."
else
  die "ratholenode knar askript peyda nashod (baste naghes ast)."
fi
if [ -f "$SCRIPT_DIR/common.sh" ]; then
  install -m 644 "$SCRIPT_DIR/common.sh" /usr/local/share/rathole/common.sh && rm -f /usr/local/bin/common.sh && log "common.sh nasb shod." \
    || die "nasb-e common.sh shekast khord (ratholenode bedoon-e an bala nemiayad)."
fi
# core-e backhaul-e patch-shode (uTLS)
if [ -f "$SCRIPT_DIR/core-backhaul/SHA256SUMS" ]; then
  cp -rf "$SCRIPT_DIR/core-backhaul" /usr/local/share/rathole/
  chmod +x /usr/local/share/rathole/core-backhaul/*/backhaul 2>/dev/null || true
  log "core-e backhaul (uTLS) nasb shod."
fi

# ---------- service systemd (tunnel asli) ----------
log "nasb service systemd..."
cat > /etc/systemd/system/rathole-client.service <<'UNIT'
[Unit]
Description=rathole client (foreign node)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rathole /etc/rathole/client.toml
Restart=always
RestartSec=2
Environment=RUST_LOG=info
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload

# faalsazi khodkar-e sait-e fik rooye node (baraye fallback-e 3x-ui / Xray dar service game)
if [ ! -f /etc/systemd/system/rathole-fakeweb.service ]; then
  /usr/local/bin/ratholenode fakeweb start 8081 >/dev/null 2>&1 || true
fi

# ---------- halat restore az backup ----------
if [ -n "$RESTORE" ]; then
  log "restore node az backup: $RESTORE"
  if command -v ratholenode >/dev/null 2>&1; then
    ratholenode restore "$RESTORE"
  else
    if tar -tzf "$RESTORE" | grep -E '(^/|\.\.)'; then
      die "tar archive daraye masirhaye khatarnak (absolute ya ..) ast."
    fi
    tar -xzf "$RESTORE" -C / || die "baz kardan backup shekast khord."
    systemctl enable --now rathole-client 2>/dev/null || true
  fi
  log "nasb node az backup kamel shod."
  echo "barresi:  ratholenode ls   |   journalctl -u rathole-client -n 10 --no-pager"
  exit 0
fi

# ---------- nasb tazh ba argument ----------
if [ "$CONFIG_NOW" -eq 1 ]; then
  # idempotency + hefz-e karbar: ejra-ye dobar-e installer rooye node-e faal (mesl node-e
  # TUNNEL=kcp/backhaul ya ba service-haye add-svc-shode) node.env/services.conf ra JAYGOZIN
  # mikond va tunnel/config-e mojood pak mishavad. backup-e zaman-dar mishavad ta bargasht
  # dasti momken bashad.
  if [ -f /etc/rathole/node.env ] || [ -f /etc/rathole/services.conf ]; then
    bdir="/var/backups/rathole-manager/pre-reconfig-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$bdir" && chmod 700 "$bdir" || true
    [ -f /etc/rathole/node.env ] && cp -a /etc/rathole/node.env "$bdir/" 2>/dev/null || true
    [ -f /etc/rathole/services.conf ] && cp -a /etc/rathole/services.conf "$bdir/" 2>/dev/null || true
    [ -f /etc/rathole/client.toml ] && cp -a /etc/rathole/client.toml "$bdir/" 2>/dev/null || true
    warn "tanzimat-e ghabli be $bdir backup shod (node.env/services.conf jaygozin mishavand)."
    warn "agar node dar halat-e kcp/plain/noise/backhaul ast ya service-ezafe dasht, in nasb be ws barmigardad."
  fi
  log "neveshtan /etc/rathole/node.env va services.conf..."
  {
    echo "SERVER=${SERVER}"
    [ -n "$TLS_HOSTNAME" ] && echo "TLS_HOSTNAME=${TLS_HOSTNAME}"
    [ -n "$TLS_TRUSTED_ROOT" ] && echo "TLS_TRUSTED_ROOT=${TLS_TRUSTED_ROOT}"
    echo "RATHOLE_VERSION=${RATHOLE_VERSION}"
  } > /etc/rathole/node.env
  chmod 600 /etc/rathole/node.env
  {
    echo "${NAME}|${TOKEN}|${INBOUND}"
    [ -n "$API_TOKEN" ] && [ -n "$API_INBOUND" ] && echo "${NAME}_api|${API_TOKEN}|${API_INBOUND}"
  } > /etc/rathole/services.conf
  chmod 600 /etc/rathole/services.conf

  if command -v ratholenode >/dev/null 2>&1; then
    ratholenode apply
  else
    HOST="${TLS_HOSTNAME:-${SERVER%%:*}}"
    [ -z "$TLS_TRUSTED_ROOT" ] || [ -f "$TLS_TRUSTED_ROOT" ] || die "TLS trusted root peyda nashod: $TLS_TRUSTED_ROOT"
    {
      echo "[client]"; echo "remote_addr = \"${SERVER}\""; echo "retry_interval = 1"; echo "heartbeat_timeout = 40"; echo
      echo "[client.transport]"; echo "type = \"websocket\""; echo "[client.transport.websocket]"; echo "tls = true"
      echo "[client.transport.tls]"; echo "hostname = \"${HOST}\""
      [ -n "$TLS_TRUSTED_ROOT" ] && echo "trusted_root = \"${TLS_TRUSTED_ROOT}\""
      echo
      echo "[client.services.${NAME}]"; echo "token = \"${TOKEN}\""; echo "local_addr = \"127.0.0.1:${INBOUND}\""; echo "type = \"tcp\""
      if [ -n "$API_TOKEN" ] && [ -n "$API_INBOUND" ]; then
        echo; echo "[client.services.${NAME}_api]"; echo "token = \"${API_TOKEN}\""; echo "local_addr = \"127.0.0.1:${API_INBOUND}\""; echo "type = \"tcp\""
      fi
    } > /etc/rathole/client.toml
    chmod 600 /etc/rathole/client.toml
    systemctl enable --now rathole-client
  fi
  sleep 1
  if systemctl is-active --quiet rathole-client; then
    log "node '${NAME}' nasb va ba movafaghiat faal shod."
  else
    err "rathole-client start nashod ya dar halat-e khata ast. log-e service:"
    journalctl -u rathole-client -n 15 --no-pager 2>&1 | sed 's/^/    /' >&2 || true
    die "rathole-client start nashod (exit ba khata)."
  fi
else
  # nasb-e sarih-e CLI bedoon argument
  log "ratholenode ba movafaghiat nasb shod."
  echo
  echo "──────── marhale-ye baad rooye hamin server kharej ────────"
  echo "۱. tanzim adres server Iran:"
  echo "   sudo ratholenode set SERVER <domain_ya_ip_iran>:443"
  echo
  echo "۲. etesal service (inbound 3x-ui):"
  echo "   sudo ratholenode add-svc <name> <token> <port_inbound_3xui>"
  echo
  echo "nemooneh:"
  echo "   sudo ratholenode set SERVER iran.example.com:443"
  echo "   sudo ratholenode add-svc node1 <TOKEN> 10001"
  echo "   sudo ratholenode status"
  echo "────────────────────────────────────────────────────────────"
fi
