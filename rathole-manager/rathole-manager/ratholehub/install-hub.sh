#!/usr/bin/env bash
# install-hub.sh — nasb ratholehub rooye server mdirit (maamoolan haman rp01)
# panel rooye 127.0.0.1 mishnvd; amntrin dstrsi = SSH local-forward (bedoon baz kardan hich port).
# ejra:  sudo bash install-hub.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

c_g(){ printf '\033[1;32m%s\033[0m' "$*"; }
c_y(){ printf '\033[1;33m%s\033[0m' "$*"; }
log(){ printf '%s %s\n' "$(c_g '[+]')" "$*"; }
warn(){ printf '%s %s\n' "$(c_y '[*]')" "$*"; }
die(){ printf '[!] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "ba root ejra kon (sudo)."
command -v python3 >/dev/null 2>&1 || die "python3 lazem ast (apt install -y python3)."

APP_DIR=/opt/ratholehub
CONF_DIR=/etc/ratholehub
PORT="${HUB_PORT:-8088}"

BUNDLE_DIR="$APP_DIR/bundle"
mkdir -p "$APP_DIR" "$CONF_DIR" "$BUNDLE_DIR"
# CONF_DIR shamel token/ramz/kelid-e SSH ast → 0700 (moshtarak ba umask-e hub).
chmod 700 "$CONF_DIR" 2>/dev/null || true
install -m755 "$SCRIPT_DIR/hub.py" "$APP_DIR/hub.py"
# hubcmds.py (naghshe-ye action→argv، bakhsh-e amniati) va asset-haye UI joda hastand
# va HATMAN bayad kenar-e hub.py nasb shavand، vagarna hub bala nemiayad / UI khali ast.
install -m644 "$SCRIPT_DIR/hubcmds.py" "$APP_DIR/hubcmds.py"
mkdir -p "$APP_DIR/ui"
for f in index.html app.css app.js i18n.js; do
  [ -f "$SCRIPT_DIR/ui/$f" ] || die "file-e UI peyda nashod: ui/$f (baste naghes ast)."
  install -m644 "$SCRIPT_DIR/ui/$f" "$APP_DIR/ui/$f"
done
# asset-haye ghadimi ke digar dar baste nistand ra pak kon (apdit az noskhe-ye ghadimi)
find "$APP_DIR/ui" -maxdepth 1 -type f ! -name 'index.html' ! -name 'app.css' \
     ! -name 'app.js' ! -name 'i18n.js' -delete 2>/dev/null || true
log "hub.py + hubcmds.py + ui/ nasb shod: $APP_DIR"

# astij kardan bainriha baraye ghablit deploy (apdit az rah dvr nodeha)
for f in ratholectl ratholenode common.sh update.sh kcptest-iran.sh kcptest-node.sh; do
  [ -f "$SCRIPT_DIR/../$f" ] && install -m755 "$SCRIPT_DIR/../$f" "$BUNDLE_DIR/$f"
done
log "bundle baraye deploy amade shod: $BUNDLE_DIR"

# tvlid config fght agar naboodan (ta token/ramz mojood pak nshvd)
if [ ! -f "$CONF_DIR/config.json" ]; then
  API_TOKEN="$(openssl rand -hex 24 2>/dev/null || head -c24 /dev/urandom | xxd -p 2>/dev/null | tr -d '\n')"
  # fail-closed: agar hala openssl va xxd ham nabashand, API_TOKEN khali mishavad va
  # `Authorization: Bearer ` (khali) dar hub compare_digest("","")=True mishod —
  # dastresi-e kamel-e gheyr-mojaz. pas bedoon-e token EJRA NEMISHAVAD.
  [ -n "$API_TOKEN" ] || die "nemitoonam token-e amn tolid konam (openssl/xxd peyda nshod). python3 nasb ast: sudo apt install -y openssl xxd"
  # ramz ra tty-safe bekhan (zir-e curl|bash ya ejra az ratholectl، stdin momken ast pipe bashad).
  # `[ -r /dev/tty ]` DOROGH migoyad (device hamishe readable ast hatta bedoon-e controlling
  # terminal) — pas VAGHEAN bazesh mikonim. timeout ham lazem ast vagarna terminal-e
  # bi-morajea nasb ra ta abad gir miandazad (haman bug-e hang-e nasb).
  PW=""
  if [ -t 0 ]; then read -rst "${RTH_READ_TIMEOUT:-300}" -p "ramz mdirit panel ra vared kon: " PW; echo
  elif { : < /dev/tty; } 2>/dev/null; then
    read -rst "${RTH_READ_TIMEOUT:-300}" -p "ramz mdirit panel ra vared kon: " PW </dev/tty; echo
  fi
  [ -n "$PW" ] || die "ramz khali nemishavad (bedoon tty؟ dasti ejra kon: sudo bash install-hub.sh)."
  # hash-e PBKDF2-HMAC-SHA256 (100k iter + salt-e tasadofi) — haman format-e hub.py.
  # ghablan sha256-e sade (bi-salt) neveshte mishod; hub dar avvalin login upgrade mikard vali
  # nasb-e taze nabayad az ebteda rooye hash-e zaif bashand.
  PWHASH="$(python3 - "$PW" <<'PYEOF'
import sys, hashlib, secrets
pw = sys.argv[1].encode("utf-8")
salt = secrets.token_hex(16)
dk = hashlib.pbkdf2_hmac("sha256", pw, salt.encode("utf-8"), 100000)
print(f"pbkdf2:sha256:100000:{salt}:{dk.hex()}")
PYEOF
)" || die "tolid-e hash-e PBKDF2 ba khata movajeh shod."
  # ramz az hafeze-ye shell/var raft; faghat hash zakhire mishavad.
  unset PW
  cat > "$CONF_DIR/config.json" <<EOF
{
  "api_token": "$API_TOKEN",
  "admin_password_hash": "$PWHASH",
  "listen_host": "127.0.0.1",
  "listen_port": $PORT,
  "ssh_key_path": "$CONF_DIR/id_ed25519",
  "ssh_opts": ["-o","BatchMode=yes","-o","ConnectTimeout=8","-o","StrictHostKeyChecking=accept-new"],
  "bundle_dir": "$BUNDLE_DIR"
}
EOF
  chmod 600 "$CONF_DIR/config.json"
  log "config sakhte shod: $CONF_DIR/config.json"
  echo "  $(c_y 'API TOKEN:') $API_TOKEN   (baraye atsal abzarhaye digar nghdar)"
else
  warn "config mojood ast; dst nkhvrd."
fi
[ -f "$CONF_DIR/inventory.json" ] || { echo "[]" > "$CONF_DIR/inventory.json"; chmod 600 "$CONF_DIR/inventory.json"; }

cat > /etc/systemd/system/ratholehub.service <<UNIT
[Unit]
Description=ratholehub web panel (REST API + UI)
After=network.target

[Service]
Type=simple
Environment=RATHOLEHUB_CONF=$CONF_DIR/config.json
Environment=RATHOLEHUB_INV=$CONF_DIR/inventory.json
ExecStart=/usr/bin/python3 $APP_DIR/hub.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now ratholehub
systemctl restart ratholehub

sleep 1
if systemctl is-active --quiet ratholehub; then
  log "ratholehub faal shod rooye 127.0.0.1:$PORT"
else
  die "ratholehub bala niamd; journalctl -u ratholehub -n 30"
fi

# ---------- kelid SSH baraye atsal hab be serverha ----------
# MOHEM: kilid DAR HAMIN CONF_DIR sakhte mishavad (na /root/.ssh) — haman masiri ke
# config.json ssh_key_path negah midarad. ghablan masir-ha mokhalef boodand va
# ensure_hub_key() dar avvalin provision kilid-e DIGARI dar /etc/ratholehub misakht va
# tamame etslat-e SSH bi-seda be kilid-e jadid mireftid (server-haye ghabli mishkastand).
KEY="$CONF_DIR/id_ed25519"
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "ratholehub@$(hostname)" >/dev/null
  chmod 600 "$KEY" 2>/dev/null || true
  chmod 644 "$KEY.pub" 2>/dev/null || true
  log "kelid SSH hab sakhte shod: $KEY"
else
  log "kelid SSH mojood estefade mishavad: $KEY"
fi
echo
echo "$(c_y '⚠ hab fght ba kelid SSH vsl mishavad (bedoon ramz). in kelid amvmi ra rooye har server authorize kon:')"
echo "───────────────────────────────────────────────"
cat "$KEY.pub"
echo "───────────────────────────────────────────────"
echo "$(c_y 'baraye har server ikbar ejra kon (rmze an server ra ikbar miporsad):')"
echo "  ssh-copy-id -i $KEY.pub -p 22 root@<server_ip>"
echo "  (ya dasti: mohtava-ye bala ra be /root/.ssh/authorized_keys an server ezafe kon)"
echo "baad az kpi, tst:  ssh -i $KEY root@<server_ip> 'ratholenode show || ratholectl ls'"

# ---------- ikparchgi khodkar ba nginx (agar hamin server panel Iran ast) ----------
# agar az dakhel-e `ratholectl hub on` seda shode bashim، khodesh nginx ra tanzim mikonad — dobare nazan
if [ -z "${RATHOLECTL_HUB_FROM_CTL:-}" ] && command -v ratholectl >/dev/null 2>&1 && [ -f /etc/rathole-manager/state.json ]; then
  if ratholectl hub on "$PORT" >/dev/null 2>&1; then
    DOMAIN="$(sed -n 's/.*"domain"[^"]*"\([^"]*\)".*/\1/p' /etc/rathole-manager/state.json | head -1)"
    HUB_SEG="$(sed -n 's/.*"hub_path"[^"]*"\([^"]*\)".*/\1/p' /etc/rathole-manager/state.json | head -1)"
    HUB_SEG="${HUB_SEG:-hub}"
    log "panel khodkar psht nginx gharar grft: https://${DOMAIN:-<domain>}/${HUB_SEG}/"
    warn "chvn panel hala amvmi ast, motmaen shv ramz ghvi gzashti."
  else
    warn "faalsazi khodkar nginx nshd; dasti: ratholectl hub on $PORT"
  fi
fi

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "$(c_g '──────── dstrsi be panel ────────')"
echo "$(c_y 'rvsh amn (bedoon baz kardan port) — SSH local-forward az system khvdt:')"
echo "  ssh -L ${PORT}:127.0.0.1:${PORT} root@${IP:-<SERVER_IP>}"
echo "  sps mrvrgr:  http://localhost:${PORT}"
echo
echo "$(c_y 'ya psht nginx zir haman damnh (ekhtiari):') in blak ra dakhl server{} damnhat bgzar:"
HUB_SNIP_SEG="${HUB_PATH:-hub}"
cat <<NGINX
  location /${HUB_SNIP_SEG}/ {
      proxy_pass http://127.0.0.1:${PORT}/;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-Proto \$scheme;
  }
NGINX
echo "$(c_g '───────────────────────────────')"
echo "$(c_y 'X-Forwarded-Proto ELZAMI ast:') bedoon-e in, hub flag-e Secure rooye cookie-e nshst nemigozarad va cookie az kanal-e HTTP-e ghayr-ramz dobare ferestade mishavad."
echo "pish-niaz: az in server be baghie serverha SSH ba kelid st bashad (ssh-copy-id root@<node>)."
echo "SSH-agente service ndard; agar kelid ramz dard, dar config masir ssh_key_path bdh."
