#!/usr/bin/env bash
# harns tst mahalli baraye ratholectl bedoon niaz be root/systemd/nginx vaghai
set -uo pipefail

# BASE khod-tashkhis ast (ghablan masir-e sabet-e WSL bood va rooye MINGW/Linux kar nemikard).
BASE="${BASE:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)}"
# sandbox: rooye MSYS/MINGW (Git-Bash-e Windows) masir-e `/tmp` majazi ast va abzar-haye
# NATIVE-e Windows (jq-e choco/scoop) an ra be C:/Users/.../Temp tarjome mikonand ke vojood
# nadarad → hameye test-ha bi-dalil FAIL mishavand. pas anja sandbox ra KENAR-e repo mizanim
# ta har do (bash va jq-e native) yek masir bebinand. rooye Linux/WSL hamon /tmp.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) ROOT="$(mktemp -d "$BASE/.harness-XXXXXX")" ;;
  *)                    ROOT="$(mktemp -d)" ;;
esac
trap 'rm -rf "$ROOT"' EXIT
export RATHOLE_TEST_MODE=1
export RTH_TEST_DIR="$ROOT"
mkdir -p "$ROOT/bin" "$ROOT/etc/rathole" "$ROOT/etc/rathole-manager" "$ROOT/etc/nginx/conf.d" "$ROOT/etc/nginx/stream.d"
cat > "$ROOT/etc/nginx/nginx.conf" <<'EOF'
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/conf.d/*.conf;
}
EOF

# jq: agar jq-linux (binary-e ELF baraye WSL/Linux) knar-e script bashad az an estefade kon
if [ -f "$BASE/jq-linux" ] && head -c4 "$BASE/jq-linux" 2>/dev/null | grep -q ELF; then
  cp "$BASE/jq-linux" "$ROOT/bin/jq"; chmod +x "$ROOT/bin/jq"
  export PATH="$ROOT/bin:$PATH"
elif command -v jq >/dev/null 2>&1; then
  :   # jq-e sistem rooye PATH ast — dast nazan
else
  for cand in \
    "/c/Users/${USER:-coder}/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe" \
    "/c/Users/coder/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe" \
    /c/ProgramData/chocolatey/bin/jq.exe \
    "/c/Users/${USER:-coder}/scoop/shims/jq.exe"; do
    if [ -x "$cand" ] || [ -f "$cand" ]; then
      export PATH="$(dirname "$cand"):$PATH"
      break
    fi
  done
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "khata: jq peyda nashod (na jq-linux-e ELF knar-e script، na dar PATH)."; exit 1
fi
jq --version >/dev/null 2>&1 || { echo "khata: jq ejra nashod."; exit 1; }
echo "sandbox: $ROOT ; jq: $(jq --version)"

# common.sh EJBARI ast: ratholectl bedoon-e an (rth_commit_config/...) balaa nemiayad va
# hala sarih die mikonad. pas knar-e nskhh-ye sandbox mizarimesh ta SCRIPT_DIR peydash konad.
sed 's/\r$//' "$BASE/common.sh" > "$ROOT/common.sh"

sed \
  -e "s#^STATE=.*#STATE=\"$ROOT/etc/rathole-manager/state.json\"#" \
  -e "s#^SERVER_TOML=.*#SERVER_TOML=\"$ROOT/etc/rathole/server.toml\"#" \
  -e "s#^NGINX_CONF=.*#NGINX_CONF=\"$ROOT/etc/nginx/conf.d/rathole.conf\"#" \
  -e "s#^STREAM_CONF=.*#STREAM_CONF=\"$ROOT/etc/nginx/stream.d/rathole-stream.conf\"#" \
  -e "s#^NGINX_MAIN_CONF=.*#NGINX_MAIN_CONF=\"$ROOT/etc/nginx/nginx.conf\"#" \
  -e 's/\r$//' \
  "$BASE/ratholectl" > "$ROOT/ratholectl.lib"

sed 's/\r$//' "$BASE/ratholenode" > "$ROOT/ratholenode.lib"

PASS_COUNT=0
FAIL_COUNT=0
assert_ok() {
  local code="$1" msg="$2"
  if [ "$code" -eq 0 ]; then
    ((PASS_COUNT++))
    echo "OK: $msg"
  else
    ((FAIL_COUNT++))
    echo "FAIL: $msg"
  fi
}
assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [ "$actual" = "$expected" ]; then
    ((PASS_COUNT++))
    echo "OK: $msg"
  else
    ((FAIL_COUNT++))
    echo "FAIL: $msg (expected '$expected', got '$actual')"
  fi
}

# wrapper: aval source, baad override tavabe sistmi, baad ejra
RUN="$ROOT/run.sh"
cat > "$RUN" <<EOF
#!/usr/bin/env bash
set -uo pipefail
export PATH="$ROOT/bin:\$PATH"
# LIB_ONLY: jelo-ye ejra-ye main hangam-e source ra migirad
export RATHOLECTL_LIB_ONLY=1
export RATHOLE_TEST_MODE=1
export RTH_TEST_DIR="$ROOT"
export NGINX_MAIN_CONF="$ROOT/etc/nginx/nginx.conf"
source "$ROOT/ratholectl.lib"
# khnsisazi tavabe niazmnd system vaghai
need_root(){ :; }
nginx(){
  if [ "\${FAIL_NGINX_T_ONCE:-0}" = "1" ] && [ "\${1:-}" = "-t" ]; then
    FAIL_NGINX_T_ONCE=0
    return 1
  fi
  if [ "\${FAIL_NGINX_T:-0}" = "1" ] && [ "\${1:-}" = "-t" ]; then
    return 1
  fi
  return 0
}
systemctl(){
  if [ "\${SYSTEMCTL_NOT_FOUND:-0}" = "1" ]; then
    return 127
  fi
  if [ "\${FAIL_SYSTEMCTL_RELOAD_ONCE:-0}" = "1" ]; then
    if [ "\${1:-}" = "reload" ] || [ "\${1:-}" = "restart" ]; then
      FAIL_SYSTEMCTL_RELOAD_ONCE=0
      return 1
    fi
  fi
  if [ "\${FAIL_SYSTEMCTL_RELOAD:-0}" = "1" ]; then
    if [ "\${1:-}" = "reload" ] || [ "\${1:-}" = "restart" ]; then
      return 1
    fi
  fi
  if [ "\${FAIL_SYSTEMCTL_START:-0}" = "1" ]; then
    if [ "\${1:-}" = "start" ]; then
      return 1
    fi
  fi
  if [ "\${FAIL_SYSTEMCTL_IS_ACTIVE:-0}" = "1" ]; then
    if [ "\${1:-}" = "is-active" ]; then
      return 1
    fi
  fi
  return 0
}
dpkg(){ return 0; }
apt-get(){ return 0; }
certbot(){ return 0; }
ssh(){ return 0; }
scp(){ return 0; }
"\$@"
EOF
chmod +x "$RUN"

RUN_NODE="$ROOT/run_node.sh"
cat > "$RUN_NODE" <<EOF
#!/usr/bin/env bash
set -uo pipefail
export PATH="$ROOT/bin:\$PATH"
export RATHOLENODE_LIB_ONLY=1
export RATHOLE_TEST_MODE=1
export RTH_TEST_DIR="$ROOT"
export UP_DIR="$ROOT/etc/rathole/upstreams"
export UP_TOML_DIR="$ROOT/etc/rathole"
export SYSTEMD_SYSTEM_DIR="$ROOT/etc/systemd/system"
export ENV_FILE="$ROOT/etc/rathole/node.env"
export SVC_FILE="$ROOT/etc/rathole/services.conf"
export CLIENT_TOML="$ROOT/etc/rathole/client.toml"
mkdir -p "$ROOT/etc/rathole/upstreams" "$ROOT/etc/systemd/system"
source "$ROOT/ratholenode.lib"
need_root(){ :; }
systemctl(){
  if [ "\${SYSTEMCTL_NOT_FOUND:-0}" = "1" ]; then
    return 127
  fi
  if [ "\${FAIL_SYSTEMCTL_RELOAD:-0}" = "1" ]; then
    if [ "\${1:-}" = "reload" ] || [ "\${1:-}" = "restart" ]; then
      return 1
    fi
  fi
  if [ "\${FAIL_SYSTEMCTL_START:-0}" = "1" ]; then
    if [ "\${1:-}" = "start" ]; then
      return 1
    fi
  fi
  if [ "\${FAIL_SYSTEMCTL_IS_ACTIVE:-0}" = "1" ]; then
    if [ "\${1:-}" = "is-active" ]; then
      return 1
    fi
  fi
  return 0
}
"\$@"
EOF
chmod +x "$RUN_NODE"

line(){ echo "=============================================="; echo "$*"; echo "=============================================="; }

line "tst 1: init gheyre-taamoli"
bash "$RUN" cmd_init --domain btli.ir --fullchain /tmp/fc.pem --key /tmp/key.pem
assert_ok $? "cmd_init ejra shod"

line "tst 2: afzoodan se node (usa01 ba api)"
bash "$RUN" cmd_add trk01 2087
bash "$RUN" cmd_add nld01 2087
bash "$RUN" cmd_add usa01 2087 62050
assert_eq "$(jq '.nodes | length' "$ROOT/etc/rathole-manager/state.json")" "3" "se node ezafe shodand"

line "tst 3: server.toml tvlidshdh"
[ -f "$ROOT/etc/rathole/server.toml" ]
assert_ok $? "server.toml vojood darad"

line "tst 4: config nginx tvlidshdh"
[ -f "$ROOT/etc/nginx/conf.d/rathole.conf" ]
assert_ok $? "rathole.conf vojood darad"

line "tst 5: hazf node nld01 va baztolid"
bash "$RUN" cmd_rm nld01
assert_eq "$(jq '.nodes | length' "$ROOT/etc/rathole-manager/state.json")" "2" "nld01 hazf shod"

line "tst 6: tkhsis port azad (bayad 1002 azadshdh ra bgird)"
bash "$RUN" cmd_add pol01 2087
GOT_P="$(jq -r '.nodes[]|select(.name=="pol01")|.port' "$ROOT/etc/rathole-manager/state.json")"
assert_eq "$GOT_P" "1002" "port 1002 azadshode be pol01 dade shod"

line "tst 7: jlvgiri az name tekrari"
if bash "$RUN" cmd_add trk01 9999 2>/dev/null; then
  assert_ok 1 "name tekrari bayad rad mishod"
else
  assert_ok 0 "name tekrari rad shod"
fi

line "tst 8: direct_port dar set-e rezerv (node nabayad port-e direct ra begirad)"
bash "$RUN" cmd_add probe01 2087
NEXT="$(jq -r '.nodes[]|select(.name=="probe01")|.port' "$ROOT/etc/rathole-manager/state.json")"
bash "$RUN" cmd_rm probe01
jq --argjson p "$NEXT" '.direct_port=$p' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" cmd_add rez01 2087
GOT="$(jq -r '.nodes[]|select(.name=="rez01")|.port' "$ROOT/etc/rathole-manager/state.json")"
[ "$GOT" != "$NEXT" ]
assert_ok $? "node port ($GOT) ba direct_port ($NEXT) tadakhol nadarad"

line "tst 9: direct on (halat standalone) — map va server block"
jq 'del(.direct_port,.direct_header,.plain_port)' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
jq '.direct_port=8081 | .direct_header="X-Cdn-Id"' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" regenerate
CONF="$ROOT/etc/nginx/conf.d/rathole.conf"
grep -q 'map \$http_x_cdn_id \$direct_node' "$CONF"
assert_ok $? "map 1 (\$http var) hast"
grep -q 'map \$direct_node \$direct_backend' "$CONF"
assert_ok $? "map 2 hast"
grep -qE '^\s*listen 8081;' "$CONF"
assert_ok $? "listen 8081 hast"
grep -q 'proxy_pass http://127.0.0.1:\$direct_backend;' "$CONF"
assert_ok $? "proxy_pass direct_backend hast"
grep -qE '"trk01"\s+[0-9]+;' "$CONF"
assert_ok $? "trk01 dar map direct hast"

line "tst 10: header-e delkhah -> motaghayer-e \$http dorost"
jq '.direct_header="X-My-Route"' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" regenerate
grep -q 'map \$http_x_my_route \$direct_node' "$CONF"
assert_ok $? "X-My-Route -> \$http_x_my_route"
jq '.direct_header="X-Cdn-Id"' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"

line "tst 11: node-e SNI dar map-e direct nabashad"
bash "$RUN" cmd_add gm01 2087 2>/dev/null
jq '(.nodes[]|select(.name=="gm01")|.sni)="ex.com"' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" regenerate
if sed -n '/map \$http_x_cdn_id \$direct_node/,/}/p' "$CONF" | grep -q '"gm01"'; then
  assert_ok 1 "node SNI nabayad dar map bashad"
else
  assert_ok 0 "node SNI az map-e direct hazf shod"
fi

line "tst 12: direct_port == plain_port -> yek block (bedoon duplicate listen)"
jq 'del(.direct_port,.direct_header) | .plain_port=9000 | .direct_port=9000 | .direct_header="X-Cdn-Id"' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" regenerate
CNT="$(grep -cE '^\s*listen 9000;' "$CONF")"
assert_eq "$CNT" "1" "faghat yek listen 9000 dar conf ast"
sed -n '/map \$direct_node \$direct_backend/,/}/p' "$CONF" | grep -qE '""\s+\$backend_port;'
assert_ok $? "fallback = backend_port (fall-through)"
awk '/listen 9000;/{f=1} f&&/proxy_pass http:\/\/127.0.0.1:\$direct_backend;/{print "found"; exit}' "$CONF" | grep -q found
assert_ok $? "plain location -> direct_backend"

line "tst 13: regression — plain-only (bedoon direct) hanooz backend_port"
jq 'del(.direct_port,.direct_header) | .plain_port=8880' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" regenerate
awk '/listen 8880;/{f=1} f&&/proxy_pass http:\/\/127.0.0.1:\$backend_port;/{print "found"; exit}' "$CONF" | grep -q found
assert_ok $? "plain-only -> backend_port"
if grep -q 'map .* \$direct_node' "$CONF"; then
  assert_ok 1 "bedoon direct nabayad map direct sakhte shavad"
else
  assert_ok 0 "bedoon direct, map direct sakhte nashod"
fi

line "tst 14: cmd_direct on/status/off"
jq 'del(.direct_port,.direct_header,.plain_port)' "$ROOT/etc/rathole-manager/state.json" > "$ROOT/s.tmp" && mv "$ROOT/s.tmp" "$ROOT/etc/rathole-manager/state.json"
bash "$RUN" cmd_direct on --port 8081 --header X-Cdn-Id >/dev/null
GP="$(jq -r '.direct_port' "$ROOT/etc/rathole-manager/state.json")"; GH="$(jq -r '.direct_header' "$ROOT/etc/rathole-manager/state.json")"
assert_eq "$GP" "8081" "direct_port set shod"
assert_eq "$GH" "X-Cdn-Id" "direct_header set shod"
DST="$(bash "$RUN" cmd_direct status)"
echo "$DST" | grep -q 'roshan'
assert_ok $? "status roshan ast"
echo "$DST" | grep -q 'trk01 -> "X-Cdn-Id: trk01"'
assert_ok $? "per-node header dar status hast"
if bash "$RUN" cmd_direct on --port 443 2>/dev/null; then
  assert_ok 1 "port 443 nabayad ghabool shavad"
else
  assert_ok 0 "port 443 rad shod"
fi
if bash "$RUN" cmd_direct on --header 'bad;header' 2>/dev/null; then
  assert_ok 1 "header ghalat nabayad ghabool shavad"
else
  assert_ok 0 "header ghalat rad shod"
fi
bash "$RUN" cmd_direct off >/dev/null
jq -e '.direct_port // empty' "$ROOT/etc/rathole-manager/state.json" >/dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "direct off direct_port ra pak kard"

line "tst 15: rth_probe — probe-e WS bayad ROOYE 101 ham BARGARDAD (regression-e v1.6.2)"
if command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  cat > "$ROOT/ws101.py" <<'PYEOF'
import socket, threading, time
CRLF = chr(13) + chr(10)
RESP = (("HTTP/1.1 101 Switching Protocols" + CRLF +
         "Upgrade: websocket" + CRLF +
         "Connection: Upgrade" + CRLF +
         "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" + CRLF + CRLF).encode())
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 8791)); s.listen(8)
def serve():
    held = []
    while True:
        c, _ = s.accept(); c.recv(4096); c.sendall(RESP)
        held.append(c)
threading.Thread(target=serve, daemon=True).start()
time.sleep(60)
PYEOF
  python3 "$ROOT/ws101.py" >"$ROOT/ws101.err" 2>&1 & WSPID=$!
  WSUP=0
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    if (exec 3<>/dev/tcp/127.0.0.1/8791) 2>/dev/null; then WSUP=1; break; fi
    sleep 1
  done
  if [ "$WSUP" != 1 ]; then
    echo "SKIP: fixture-e 8791 bala nayamad — $(head -3 "$ROOT/ws101.err" 2>/dev/null | tr '\n' ' ')"
  else
    WSH=(-H 'Connection: Upgrade' -H 'Upgrade: websocket'
         -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==')
    T0=$SECONDS
    CODE="$(bash "$RUN" rth_probe "http://127.0.0.1:8791/" "dummy.invalid" "${WSH[@]}")"
    EL=$((SECONDS-T0))
    assert_eq "$CODE" "101" "101 rooye channel-e salem tashkhis dade shod"
    [ "$EL" -le 8 ]
    assert_ok $? "probe mahdood ast (${EL}s) — hang nemikonad"
    [ "$CODE" != 101000 ]
    assert_ok $? "bedoon-e concatenation-e '000'"
    CODE2="$(bash "$RUN" rth_probe "http://127.0.0.1:9/" "dummy.invalid" "${WSH[@]}")"
    assert_eq "$CODE2" "000" "port-e baste -> 000"
  fi
else
  echo "SKIP: python3/curl nist"
fi

line "tst 16: cmd_init bedoon --fresh rooye state mojood bayad rad shavad (P1-01)"
PRE_NODES="$(jq -r '.nodes | length' "$ROOT/etc/rathole-manager/state.json")"
if bash "$RUN" cmd_init --domain newdomain.invalid 2>/dev/null; then
  assert_ok 1 "cmd_init rooye state mojood bayad shekast bokhord"
else
  assert_ok 0 "cmd_init rooye state mojood ba movafaghiat rad shod"
fi
POST_NODES="$(jq -r '.nodes | length' "$ROOT/etc/rathole-manager/state.json")"
assert_eq "$POST_NODES" "$PRE_NODES" "state.json dast-nakhorde va truncate-nashode mand"

line "tst 17: etebarsanji-ye port (1..65535) (P1-09)"
if bash "$RUN" cmd_add bad0 0 2>/dev/null; then
  assert_ok 1 "port 0 bayad rad shavad"
else
  assert_ok 0 "port 0 rad shod"
fi
if bash "$RUN" cmd_add bad65536 65536 2>/dev/null; then
  assert_ok 1 "port 65536 bayad rad shavad"
else
  assert_ok 0 "port 65536 rad shod"
fi
if bash "$RUN" cmd_add goodnode 8444 2>/dev/null; then
  assert_ok 0 "port 8444 ghabool shod"
  bash "$RUN" cmd_rm goodnode >/dev/null 2>&1
else
  assert_ok 1 "port 8444 bayad ghabool mishod"
fi

line "tst 18: barresi-ye fail-closed dar lock timeout (P1-03)"
export RTH_LOCK="$ROOT/ratholectl.lock"
export RTH_LOCK_TIMEOUT=1
touch "$RTH_LOCK"
PRE_LOCK_NODES="$(jq -r '.nodes | length' "$ROOT/etc/rathole-manager/state.json" 2>/dev/null || echo 0)"

if command -v flock >/dev/null 2>&1; then
  ( exec 8>"$RTH_LOCK"; flock -x 8; sleep 3 ) &
  BG_PID=$!
  sleep 0.2
  if bash "$RUN" rth_with_lock cmd_add lockfail 2087 2>/dev/null; then
    assert_ok 1 "hangam-e vojood-e flock mutation bayad fail-closed shavad"
  else
    assert_ok 0 "hangam-e vojood-e flock mutation fail-closed kard"
  fi
  wait $BG_PID 2>/dev/null || true
  POST_LOCK_NODES="$(jq -r '.nodes | length' "$ROOT/etc/rathole-manager/state.json" 2>/dev/null || echo 0)"
  assert_eq "$POST_LOCK_NODES" "$PRE_LOCK_NODES" "state dast-nakhorde mand pas az timeout-e flock"

  mkdir -p "$ROOT/unopenable.lock"
  if RTH_LOCK="$ROOT/unopenable.lock" bash "$RUN" rth_with_lock cmd_add lockopenfail 2088 2>/dev/null; then
    assert_ok 1 "hangam-e baz-nashodan-e file-e lock bayad fail-closed shavad"
  else
    assert_ok 0 "hangam-e baz-nashodan-e file-e lock fail-closed kard"
  fi
  POST_LOCK_NODES2="$(jq -r '.nodes | length' "$ROOT/etc/rathole-manager/state.json" 2>/dev/null || echo 0)"
  assert_eq "$POST_LOCK_NODES2" "$PRE_LOCK_NODES" "state dast-nakhorde mand pas az shekaste baz kardan-e lock"
else
  LOCK_DIR="${RTH_LOCK}.d"
  mkdir -p "$LOCK_DIR"
  if bash "$RUN" rth_with_lock cmd_add lockfail_mkdir 2087 2>/dev/null; then
    assert_ok 1 "hangam-e vojood-e ghofl-e mkdir mutation bayad fail-closed shavad"
  else
    assert_ok 0 "hangam-e vojood-e ghofl-e mkdir mutation fail-closed kard"
  fi
  rmdir "$LOCK_DIR" 2>/dev/null || true
  POST_LOCK_NODES="$(jq -r '.nodes | length' "$ROOT/etc/rathole-manager/state.json" 2>/dev/null || echo 0)"
  assert_eq "$POST_LOCK_NODES" "$PRE_LOCK_NODES" "state dast-nakhorde mand pas az timeout-e mkdir"
fi

line "tst 19: adaptive Python probe rooye connection-e baz (P2-02)"
if [ "${WSUP:-0}" = 1 ]; then
  PY_PROBE='
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
s = socket.create_connection((host, port), timeout=4)
req = f"GET / HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
s.sendall(req.encode("ascii"))
buf = b""
while b"\r\n\r\n" not in buf:
    chunk = s.recv(4096)
    if not chunk: break
    buf += chunk
s.close()
status = int(buf.split(b" ")[1]) if b" " in buf else 0
print(status)
'
  PY_RES="$(python3 -c "$PY_PROBE" 127.0.0.1 8791 2>/dev/null || echo 0)"
  assert_eq "$PY_RES" "101" "Python adaptive probe 101 ra daryaft kard va hang nakard"
  [ -n "${WSPID:-}" ] && kill $WSPID 2>/dev/null || true
fi

line "tst 20: ensure_stream_include bedoon stream block mojood"
cat > "$ROOT/etc/nginx/nginx.conf" <<'EOF'
events { worker_connections 1024; }
http { include /etc/nginx/conf.d/*.conf; }
EOF
bash "$RUN" ensure_stream_include
grep -q 'include.*stream\.d/\*\.conf;' "$ROOT/etc/nginx/nginx.conf"
assert_ok $? "stream block ba include be nginx.conf ezafe shod"
[ -f "$ROOT/etc/nginx/nginx.conf.l4.bak" ]
assert_ok $? "backup .l4.bak sakhte shod"

line "tst 21: ensure_stream_include ba stream block mojood"
cat > "$ROOT/etc/nginx/nginx.conf" <<'EOF'
events { worker_connections 1024; }
http { include /etc/nginx/conf.d/*.conf; }
stream {
    # existing custom stream config
    include /custom/stream.conf;
}
EOF
bash "$RUN" ensure_stream_include
grep -q 'include.*stream\.d/\*\.conf;' "$ROOT/etc/nginx/nginx.conf"
assert_ok $? "include dakhel-e stream block-e mojood inject shod"

line "tst 22: ensure_stream_include idempotency"
PRE_SHA="$(sha256sum "$ROOT/etc/nginx/nginx.conf" | cut -d' ' -f1)"
bash "$RUN" ensure_stream_include
POST_SHA="$(sha256sum "$ROOT/etc/nginx/nginx.conf" | cut -d' ' -f1)"
assert_eq "$POST_SHA" "$PRE_SHA" "ensure_stream_include idempotent ast va file ra taghir nadad"

line "tst 23: host isolation — /etc/nginx/nginx.conf nabayad dast khorde bashad"
if [ -f /etc/nginx/nginx.conf ]; then
  if grep -q "$ROOT" /etc/nginx/nginx.conf 2>/dev/null; then
    assert_ok 1 "host /etc/nginx/nginx.conf dast khorde ast!"
  else
    assert_ok 0 "host /etc/nginx/nginx.conf dast-nakhorde mand"
  fi
else
  assert_ok 0 "host /etc/nginx/nginx.conf vojood nadarad (safe)"
fi

line "tst 24: transactional state mutation baraye Game (add & rm)"
bash "$RUN" cmd_game_add testgame 20001 game.example.com >/dev/null 2>&1
GAME_SNI="$(jq -r '.nodes[]|select(.name=="testgame")|.sni' "$ROOT/etc/rathole-manager/state.json" 2>/dev/null || echo '')"
assert_eq "$GAME_SNI" "game.example.com" "game testgame ba transactional state ezafe shod"
bash "$RUN" cmd_game_rm testgame >/dev/null 2>&1
HAS_GAME="$(jq -r '.nodes[]|select(.name=="testgame")' "$ROOT/etc/rathole-manager/state.json" 2>/dev/null || echo '')"
assert_eq "$HAS_GAME" "" "game testgame ba transactional state hazf shod"

line "tst 25: safe_kv_set and safe_svc_del (special characters & exact matching)"
cat > "$ROOT/test.env" <<'EOF'
FOO=bar
BAZ=qux
EOF
# Source node functions into a subshell to test
(
  export ENV_FILE="$ROOT/test.env"
  err(){ printf '%s\n' "$*" >&2; }
  eval "$(sed -n '/^safe_kv_set(){/,/^}/p;/^safe_kv_del(){/,/^}/p;/^safe_svc_del(){/,/^}/p' "$BASE/ratholenode")"
  safe_kv_set "$ROOT/test.env" TEST_SPECIAL "val&with#hash/slash\\backslash and spaces" || exit 1
  READ_VAL="$(grep '^TEST_SPECIAL=' "$ROOT/test.env" | cut -d= -f2-)"
  [ "$READ_VAL" = "val&with#hash/slash\\backslash and spaces" ] || exit 2
  safe_kv_del "$ROOT/test.env" TEST_SPECIAL || exit 3
  grep -q '^TEST_SPECIAL=' "$ROOT/test.env" && exit 4
  exit 0
)
assert_ok $? "safe_kv_set va safe_kv_del ba carakterhaye khas movafagh bood"

line "tst 26: upstream .env command injection rejection (Finding 2)"
MARKER_26="$ROOT/injected_marker_26"
rm -f "$MARKER_26"
mkdir -p "$ROOT/etc/rathole/upstreams"
cat > "$ROOT/etc/rathole/upstreams/inj01.env" <<EOF
SERVER=1.2.3.4:1234
HOST=evil.com; touch $MARKER_26
TUNNEL=ws; touch $MARKER_26
EOF
bash "$RUN_NODE" gen_up_client inj01 >/dev/null 2>&1 || true
[ ! -f "$MARKER_26" ]
assert_ok $? "gen_up_client command injection ra ejra nakard (marker sakhte nashod)"
grep -q 'remote_addr = "1.2.3.4:1234"' "$ROOT/etc/rathole/client-inj01.toml"
assert_ok $? "client-inj01.toml ba maghadir-e safe tolid shod"

cat > "$ROOT/etc/rathole/upstreams/inj02.env" <<EOF
SERVER=\$(touch $MARKER_26)
HOST=example.com
TUNNEL=ws
EOF
bash "$RUN_NODE" gen_up_client inj02 >/dev/null 2>&1 || true
[ ! -f "$MARKER_26" ]
assert_ok $? "subshell substitution \$(...) dar .env ejra nashod"

line "tst 27: strict upstream ID validation across all subcommands (Finding 2)"
subcmds=("add" "add-svc" "rm-svc" "rm" "apply" "restart" "kcp" "plain" "noise" "ws" "status" "logs")
all_rejected=1
for sc in "${subcmds[@]}"; do
  for bad_id in "../../bad" "." ".." "main" "a/b" "bad id"; do
    if bash "$RUN_NODE" cmd_upstream "$sc" "$bad_id" >/dev/null 2>&1; then
      all_rejected=0
      echo "FAIL: cmd_upstream $sc accepted invalid ID '$bad_id'"
    fi
  done
done
[ "$all_rejected" -eq 1 ]
assert_ok $? "tamam-e 12 subcommand-e upstream ID-haye namotabar ra rad kardand"

bash "$RUN_NODE" cmd_upstream add valid01 1.2.3.4:443 valid01.com >/dev/null 2>&1
assert_ok $? "cmd_upstream add ba ID-e motabar (valid01) movafagh shod"

line "tst 28: KCP unit generator injection rejection (Finding 3)"
INJ_REMOTE=$'1.2.3.4:29900\nExecStartPre=/bin/sh -c "touch evil"'
INJ_KEY=$'secret\nInjectedDirective=true'

if bash "$RUN_NODE" gen_kcp_client_unit "$INJ_REMOTE" "127.0.0.1:29900" "validkey" 10 3 fast 1024 1024 >/dev/null 2>&1; then
  assert_ok 1 "gen_kcp_client_unit bayad CRLF injection dar remote ra rad mikard"
else
  assert_ok 0 "gen_kcp_client_unit CRLF injection dar remote ra rad kard"
fi

if bash "$RUN_NODE" gen_kcp_client_unit "1.2.3.4:29900" "127.0.0.1:29900" "$INJ_KEY" 10 3 fast 1024 1024 >/dev/null 2>&1; then
  assert_ok 1 "gen_kcp_client_unit bayad CRLF injection dar key ra rad mikard"
else
  assert_ok 0 "gen_kcp_client_unit CRLF injection dar key ra rad kard"
fi

if bash "$RUN_NODE" gen_up_kcp_unit "valid01" "$INJ_REMOTE" "127.0.0.1:29901" "validkey" 10 3 fast 1024 1024 >/dev/null 2>&1; then
  assert_ok 1 "gen_up_kcp_unit bayad CRLF injection dar remote ra rad mikard"
else
  assert_ok 0 "gen_up_kcp_unit CRLF injection dar remote ra rad kard"
fi

if bash "$RUN_NODE" gen_up_kcp_unit "valid01" "1.2.3.4:29900" "127.0.0.1:29901" "$INJ_KEY" 10 3 fast 1024 1024 >/dev/null 2>&1; then
  assert_ok 1 "gen_up_kcp_unit bayad CRLF injection dar key ra rad mikard"
else
  assert_ok 0 "gen_up_kcp_unit CRLF injection dar key ra rad kard"
fi

line "tst 29: RTH_LOCK environment override protection va symlink rejection (Finding 4)"
TARGET_FILE="$ROOT/do_not_touch.txt"
echo "PROTECTED_CONTENT" > "$TARGET_FILE"
(
  export RATHOLE_TEST_MODE=0
  export RTH_LOCK="$TARGET_FILE"
  export RATHOLENODE_LIB_ONLY=1
  source "$BASE/ratholenode"
  rth_with_lock true >/dev/null 2>&1
)
rc=$?
assert_eq "$rc" "1" "RTH_LOCK override dar halat-e ghyr-e test bayad fail-closed shavad"
[ "$(cat "$TARGET_FILE")" = "PROTECTED_CONTENT" ]
assert_ok $? "target file truncate ya dastkhorde nashod (exec 9>> amniat)"

SYMLINK_LOCK="$ROOT/symlink.lock"
ln -s "$TARGET_FILE" "$SYMLINK_LOCK" 2>/dev/null || true
if [ -L "$SYMLINK_LOCK" ]; then
  (
    export RATHOLE_TEST_MODE=1
    export RTH_TEST_DIR="$ROOT"
    export RATHOLENODE_LIB_ONLY=1
    source "$BASE/ratholenode"
    RTH_LOCK="$SYMLINK_LOCK"
    rth_with_lock true >/dev/null 2>&1
  )
  rc=$?
  assert_eq "$rc" "1" "symlink lock bayad rad shavad"
  [ "$(cat "$TARGET_FILE")" = "PROTECTED_CONTENT" ]
  assert_ok $? "target file az tarigh-e symlink dastkhorde nashod"
else
  assert_ok 0 "symlink lock check (symlinks unsupported on current filesystem)"
  assert_ok 0 "target file dast-nakhorde mand"
fi

line "tst 30: Nginx regeneration rollback on nginx -t failure (Finding 8)"
bash "$RUN" regenerate >/dev/null 2>&1
CONF="$ROOT/etc/nginx/conf.d/rathole.conf"
STREAM="$ROOT/etc/nginx/stream.d/rathole-stream.conf"
MAIN_CONF="$ROOT/etc/nginx/nginx.conf"
TOML="$ROOT/etc/rathole/server.toml"

PRE_CONF_SHA="$(sha256sum "$CONF" | cut -d' ' -f1)"
PRE_MAIN_SHA="$(sha256sum "$MAIN_CONF" | cut -d' ' -f1)"
PRE_TOML_SHA="$(sha256sum "$TOML" | cut -d' ' -f1)"

FAIL_NGINX_T_ONCE=1 bash "$RUN" regenerate >/dev/null 2>&1
RC=$?
[ "$RC" -ne 0 ]
assert_ok $? "regenerate ba FAIL_NGINX_T_ONCE=1 khata dad"

POST_CONF_SHA="$(sha256sum "$CONF" | cut -d' ' -f1)"
POST_MAIN_SHA="$(sha256sum "$MAIN_CONF" | cut -d' ' -f1)"
POST_TOML_SHA="$(sha256sum "$TOML" | cut -d' ' -f1)"

assert_eq "$POST_CONF_SHA" "$PRE_CONF_SHA" "rathole.conf pas az khata-ye nginx -t rollback shod"
assert_eq "$POST_MAIN_SHA" "$PRE_MAIN_SHA" "nginx.conf pas az khata-ye nginx -t rollback shod"
assert_eq "$POST_TOML_SHA" "$PRE_TOML_SHA" "server.toml pas az khata-ye nginx -t rollback shod"

line "tst 31: Nginx regeneration rollback when nginx -t passes but reload/restart fails (Finding 8)"
FAIL_SYSTEMCTL_RELOAD=1 bash "$RUN" regenerate >/dev/null 2>&1
RC=$?
[ "$RC" -ne 0 ]
assert_ok $? "regenerate ba FAIL_SYSTEMCTL_RELOAD=1 khata dad"

POST_CONF_SHA2="$(sha256sum "$CONF" | cut -d' ' -f1)"
POST_MAIN_SHA2="$(sha256sum "$MAIN_CONF" | cut -d' ' -f1)"
POST_TOML_SHA2="$(sha256sum "$TOML" | cut -d' ' -f1)"

assert_eq "$POST_CONF_SHA2" "$PRE_CONF_SHA" "rathole.conf pas az khata-ye reload rollback shod"
assert_eq "$POST_MAIN_SHA2" "$PRE_MAIN_SHA" "nginx.conf pas az khata-ye reload rollback shod"
assert_eq "$POST_TOML_SHA2" "$PRE_TOML_SHA" "server.toml pas az khata-ye reload rollback shod"

line "tst 32: honest service helpers (restart_svc va reload_svc) (Finding 9)"
(
  export SYSTEMCTL_NOT_FOUND=1
  bash "$RUN_NODE" restart_svc >/dev/null 2>&1
)
rc=$?
assert_eq "$rc" "1" "restart_svc vaghti systemctl peyda nashod return 1 dad"

(
  export SYSTEMCTL_NOT_FOUND=1
  bash "$RUN_NODE" reload_svc >/dev/null 2>&1
)
rc=$?
assert_eq "$rc" "1" "reload_svc vaghti systemctl peyda nashod return 1 dad"

(
  export FAIL_SYSTEMCTL_RELOAD=1
  bash "$RUN_NODE" restart_svc >/dev/null 2>&1
)
rc=$?
assert_eq "$rc" "1" "restart_svc vaghti restart shekast khord return 1 dad"

(
  export FAIL_SYSTEMCTL_RELOAD=1
  export FAIL_SYSTEMCTL_START=1
  export FAIL_SYSTEMCTL_IS_ACTIVE=1
  bash "$RUN_NODE" reload_svc >/dev/null 2>&1
)
rc=$?
assert_eq "$rc" "1" "reload_svc vaghti start/reload shekast khord return 1 dad"

echo "=============================================="
echo "Harness Summary: PASS=$PASS_COUNT  FAIL=$FAIL_COUNT"
echo "=============================================="
[ "$FAIL_COUNT" -eq 0 ] || exit 1
