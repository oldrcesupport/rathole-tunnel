#!/usr/bin/env bash
# uninstall-node.sh — hazf kamel samt node kharej (klaint rathole)
# ejra: sudo bash uninstall-node.sh [--purge] [--yes]
#   --purge : bainri rathole ham hazf shavad
#   --yes   : bedoon prssh
set -uo pipefail

PURGE=0; YES=0

c_g(){ printf '\033[1;32m%s\033[0m' "$*"; }
c_r(){ printf '\033[1;31m%s\033[0m' "$*"; }
c_y(){ printf '\033[1;33m%s\033[0m' "$*"; }
log(){ printf '%s %s\n' "$(c_g '[+]')" "$*"; }
warn(){ printf '%s %s\n' "$(c_y '[*]')" "$*"; }
err(){ printf '%s %s\n' "$(c_r '[!]')" "$*" >&2; }
die(){ err "$*"; exit 1; }
# tty-safe + bounded: `read -rp` rooye stdin-e gheyr-terminal (curl|bash، SSH) ta abad montazer
# mimanad va prompt ham chap nemishavad. bedoon-e tty javab «na» ast (pishfarz-e amn baraye hazf).
ask_yn(){
  [ "$YES" -eq 1 ] && return 0
  local a="" t="${RTH_READ_TIMEOUT:-300}"
  if [ -t 0 ]; then read -rt "$t" -p "$1 [y/N]: " a
  elif { : < /dev/tty; } 2>/dev/null; then read -rt "$t" -p "$1 [y/N]: " a < /dev/tty
  fi
  [[ "$a" =~ ^[Yy]$ ]]
}

while [ $# -gt 0 ]; do case "$1" in
  --purge) PURGE=1; shift;;
  --yes|-y) YES=1; shift;;
  *) shift;;
esac; done

[ "$(id -u)" -eq 0 ] || die "bayad ba root ejra shavad (sudo)."

warn "in askript service rathole-client va config node ra hazf mikonad."
warn "rooye nginx ya Xray node dst nmiznd (anha mstghland)."
ask_yn "adamh?" || { log "lghv shod."; exit 0; }

# ---------- tavaghof va hazf service ----------
log "tavaghof va ghirfaalsazi rathole-client va servicehaye وابسته..."
systemctl disable --now rathole-client 2>/dev/null || true
rm -f /etc/systemd/system/rathole-client.service
# kcp-client
systemctl disable --now rathole-kcp-client 2>/dev/null || true
rm -f /etc/systemd/system/rathole-kcp-client.service
# watchdog
systemctl disable --now rathole-watchdog.timer rathole-watchdog.service 2>/dev/null || true
rm -f /etc/systemd/system/rathole-watchdog.timer /etc/systemd/system/rathole-watchdog.service
# adaptive
systemctl disable --now rathole-adaptive.timer rathole-adaptive.service 2>/dev/null || true
rm -f /etc/systemd/system/rathole-adaptive.timer /etc/systemd/system/rathole-adaptive.service
# upstreams
for s in /etc/systemd/system/rathole-client@*.service; do
  [ -f "$s" ] || continue
  u="$(basename "$s")"
  systemctl disable --now "$u" 2>/dev/null || true
  rm -f "$s"
done
# instans-haye kcp-e upstream-ha (rathole-kcp-up-<id>): ghablan HAZF NEMISHODAND va ba'd az
# «uninstall» kcptun-e faal (UDP tunnel-e faal be Iran) mimmnd va ba boot ham barmigasht.
for s in /etc/systemd/system/rathole-kcp-up-*.service; do
  [ -f "$s" ] || continue
  u="$(basename "$s")"
  systemctl disable --now "$u" 2>/dev/null || true
  rm -f "$s"
done
# fakeweb ( Restart=always darad; bedoon-e in python3-e faal mimmnd)
systemctl disable --now rathole-fakeweb 2>/dev/null || true
rm -f /etc/systemd/system/rathole-fakeweb.service
# client-e backhaul (agar roshan shode bood)
systemctl disable --now rathole-backhaul-client 2>/dev/null || true
rm -f /etc/systemd/system/rathole-backhaul-client.service
rm -f /usr/local/bin/backhaul-client
systemctl daemon-reload 2>/dev/null || true

# ---------- hazf config va state ----------
log "hazf config va state-haye node dar /etc/rathole..."
# adaptive-state.json / failover.state: esm-haye VAGHEI (ghablan adaptive.state hazf mishod ke
# esm-e eshtebah bood va file-e vaziat baqi mimand).
rm -f /etc/rathole/client.toml /etc/rathole/node.env /etc/rathole/services.conf \
      /etc/rathole/backhaul-client.toml /etc/rathole/adaptive.env /etc/rathole/adaptive-state.json \
      /etc/rathole/failover.state /etc/rathole/adaptive.state \
      /etc/rathole/watchdog.env
rm -rf /etc/rathole/upstreams
if [ -d /etc/rathole ] && [ -z "$(ls -A /etc/rathole 2>/dev/null)" ]; then rmdir /etc/rathole; fi

# ---------- hazf abzar ----------
rm -f /usr/local/bin/ratholenode
log "ratholenode hazf shod."
# common.sh-e eshteraki (agar panel/hub-e digari rooye hamin server nist, hazf kon)
if [ -f /usr/local/share/rathole/common.sh ] \
   && [ ! -f /etc/systemd/system/rathole-server.service ] \
   && [ ! -f /opt/ratholehub/hub.py ]; then
  rm -f /usr/local/share/rathole/common.sh
  rmdir /usr/local/share/rathole 2>/dev/null || true
  log "common.sh hazf shod."
fi

# ---------- purge ekhtiari ----------
if [ "$PURGE" -eq 1 ]; then
  if ask_yn "bainri /usr/local/bin/rathole hazf shvd?"; then rm -f /usr/local/bin/rathole; fi
  # kcptun + web-fak + gozaresh-haye mvaqet-e tst: dar purge hazf mishavand.
  rm -f /usr/local/bin/kcptun-client /usr/local/bin/kcptun-server
  systemctl disable --now rathole-panel-fakeweb 2>/dev/null || true
  rm -f /etc/systemd/system/rathole-panel-fakeweb.service /etc/systemd/system/rathole-fakeweb.service
  systemctl daemon-reload 2>/dev/null || true
  rm -rf /var/www/rathole-fake
  rm -f /run/kcptest-*.pid /var/log/kcptest-*.log 2>/dev/null || true
  [ -d /etc/rathole ] && [ -z "$(ls -A /etc/rathole 2>/dev/null)" ] && rmdir /etc/rathole
fi

echo
log "hazf samt node kamel shod."
warn "inbound Xray rooye in node hmchnan faal ast; agar lazem nist, az panel/Xray jdaganh hzfsh kon."
