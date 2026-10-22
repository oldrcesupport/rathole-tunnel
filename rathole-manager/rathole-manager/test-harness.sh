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
mkdir -p "$ROOT/bin" "$ROOT/etc/rathole" "$ROOT/etc/rathole-manager" "$ROOT/etc/nginx/conf.d" "$ROOT/etc/nginx/stream.d"

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

# nskhh tst az ratholectl ba msirhai sandbox.
sed \
  -e "s#^STATE=.*#STATE=\"$ROOT/etc/rathole-manager/state.json\"#" \
  -e "s#^SERVER_TOML=.*#SERVER_TOML=\"$ROOT/etc/rathole/server.toml\"#" \
  -e "s#^NGINX_CONF=.*#NGINX_CONF=\"$ROOT/etc/nginx/conf.d/rathole.conf\"#" \
  -e "s#^STREAM_CONF=.*#STREAM_CONF=\"$ROOT/etc/nginx/stream.d/rathole-stream.conf\"#" \
  -e 's/\r$//' \
  "$BASE/ratholectl" > "$ROOT/ratholectl.lib"

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
source "$ROOT/ratholectl.lib"
# khnsisazi tavabe niazmnd system vaghai
need_root(){ :; }
nginx(){ return 0; }
systemctl(){ return 0; }
"\$@"
EOF
chmod +x "$RUN"

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
LOCK_DIR="${RTH_LOCK}.d"
mkdir -p "$LOCK_DIR"
if bash "$RUN" rth_with_lock cmd_add lockfail 2087 2>/dev/null; then
  assert_ok 1 "hangam-e vojood-e ghofl mutation bayad fail-closed shavad"
else
  assert_ok 0 "hangam-e vojood-e ghofl mutation fail-closed kard"
fi
rmdir "$LOCK_DIR" 2>/dev/null || true

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

echo "=============================================="
echo "Harness Summary: PASS=$PASS_COUNT  FAIL=$FAIL_COUNT"
echo "=============================================="
[ "$FAIL_COUNT" -eq 0 ] || exit 1
