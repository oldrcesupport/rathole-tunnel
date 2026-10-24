#!/usr/bin/env bash
# common.sh — tavabe eshteraki beyn ratholectl, ratholenode va nsabha
# in file tvst source frakhvani mishvd; be tnhaii ejra nemishavad.

# amniat-e sarasari-ye file-ha: pishfarz-e umask 077 ta hich secret/state/config-i world-readable nashavad.
umask 077

# noskhe-ye rathole-manager (panel/node/hub). moqe-e release in adad ba tag hamahang mishavad.
# package.sh/CI mitavanad in ra be tag-e vaghei stamp konad; agar dast taghir dadi، bedoon 'v' bezar.
MANAGER_VERSION="1.9.4"

c_g(){ printf '\033[1;32m%s\033[0m' "$*"; }
c_r(){ printf '\033[1;31m%s\033[0m' "$*"; }
c_y(){ printf '\033[1;33m%s\033[0m' "$*"; }
log(){ printf '%s %s\n' "$(c_g '[+]')" "$*"; }
warn(){ printf '%s %s\n' "$(c_y '[*]')" "$*"; }
err(){ printf '%s %s\n' "$(c_r '[!]')" "$*" >&2; }
die(){ err "$*"; exit 1; }
need_root(){ [ "$(id -u)" -eq 0 ] || die "bayad ba root ejra shavad (sudo)."; }

# etebarsanji-ye motahed-e port (1 ta 65535)
is_valid_port(){
  local p="${1:-}"
  [[ "$p" =~ ^[0-9]{1,5}$ ]] || return 1
  [ "$p" -ge 1 ] 2>/dev/null && [ "$p" -le 65535 ] 2>/dev/null
}

# ---------- porsesh-e taamoli-ye amn (tty-safe + bounded) ----------
# CHERA (bug-e «nasb dar marhale-ye tanzimat-e avalie saat-ha motevaghef mishavad»):
#   1) `read -rp` rooye stdin-e GHEYR-terminal (curl|bash vaghti producer hanooz pipe ra
#      nabaste — link-e kond/filter-shode az Iran —، kanal-e SSH، hub) TA ABAD montazer
#      mimanad. bad-tar: bash prompt-e `read -p` ra FAGHAT vaghti minevisad ke vorodi
#      terminal bashad، pas karbar hich payami nemibinad va nasb bi-seda mimirad.
#   2) `[ -r /dev/tty ]` DOROGH migoyad: node-e device hamishe readable ast hatta vaghti
#      process controlling terminal NADARAD — pas shakhes-e «tty darim» nist.
# tanha rah-e motmaen BAZ KARDAN-e /dev/tty ast (haman elgo-ye dorost-e bootstrap.sh).
# agar hich tty-ye vaghei nabashad HARGEZ montazer nemimanim (meghdar-e khali barmigardad).
RTH_TTY=""
if [ ! -t 0 ] && { : < /dev/tty; } 2>/dev/null; then RTH_TTY="/dev/tty"; fi
has_tty(){ [ -t 0 ] || [ -n "$RTH_TTY" ]; }

# backstop-e zamani: hatta ba tty-ye VAGHEI (masalan screen/tmux-e detach-shode ya terminal-i
# ke kasi payash nist) nabayad ta abad gir konim. sanie — ba RTH_READ_TIMEOUT ghabl-e taghir.
# ghofl-e state (fd 9) nabayad hengam-e entezar baraye TAYP-e karbar negah dashte shavad:
# `menu` yek halghe-ye taamoli-ye bi-payan ast va `init` montazer-e javab mimanad. dar in
# modat HAR ratholectl-e digar (masalan action-e hub az SSH) 30 sanie gir mikard va baad
# BI-GHOFL edame midad — yaani haman mohafezat-e lost-update dor mizad. pas ghabl az read
# ghofl ra AZAD mikonim va baad az javab DOBARE migirim; read-modify-write-e mutator-ha
# hamchenan kamel zir-e ghofl ejra mishavad (next_port/jq baad az porsesh-ha miayad).
# RTH_LOCK_HELD tanha dar masir-e flock set mishavad; fallback-e mkdir (sistem-haye bedoon-e
# flock) hamchenan ghofl ra negah midarad — nadir ast va sadegi mohem-tar.
RTH_LOCK_HELD=0
rth_lock_pause(){ if [ "${RTH_LOCK_HELD:-0}" = 1 ]; then flock -u 9 2>/dev/null || true; fi; }
rth_lock_resume(){
  if [ "${RTH_LOCK_HELD:-0}" = 1 ]; then
    flock -w 30 9 2>/dev/null || die "ghofl-e state pas az javab azad nashod (30s timeout); baraye jelogiri az corruption motavaghef mishavam."
  fi
}

rth_read(){   # estefade: rth_read VAR "prompt"
  local __v="$1" __p="${2:-}" __a="" __t="${RTH_READ_TIMEOUT:-300}"
  rth_lock_pause
  if [ -t 0 ]; then read -rt "$__t" -p "$__p" __a
  elif [ -n "$RTH_TTY" ]; then read -rt "$__t" -p "$__p" __a < "$RTH_TTY"
  else __a=""; fi
  rth_lock_resume
  printf -v "$__v" '%s' "$__a"
}
# bedoon-e tty (ya baad az timeout) javab HAMISHE «na» ast — pishfarz-e amn baraye
# porsesh-haye makhrab (hazf/bazneveshtan).
ask_yn(){ local a; rth_read a "$1 [y/N]: "; [[ "$a" =~ ^[Yy]$ ]]; }

# mirror-haye ghproxy baraye dor-zadan-e filtering-e Iran (hamsan-e install.sh/install-panel.sh).
RTH_MIRRORS=("" "https://ghproxy.net/" "https://gh-proxy.com/" "https://mirror.ghproxy.com/")

# akharin tag-e pre-release (beta/rc/alpha) ra peyda mikonad. $1 = slug-e owner/repo.
# CHERA atom va na API: masir-e `releases/latest/download` dar GitHub pre-release ha ra
# NADIDE migirad, pas baraye beta bayad tag-e daghigh ra bedanim. api.github.com az mirror-haye
# ghproxy obur nemikonad vali github.com/<slug>/releases.atom mikonad — va atom ham be jq niaz
# nadarad (dar node-e taze-nasb momken ast jq nabashad). tartib-e atom: jadidtarin aval.
resolve_beta_tag(){
  local gh="$1" m out tag
  for m in "${RTH_MIRRORS[@]}"; do
    out="$(curl -fsSL --connect-timeout 15 --retry 1 "${m}https://github.com/${gh}/releases.atom" 2>/dev/null)" || continue
    tag="$(printf '%s' "$out" \
      | grep -oE 'releases/tag/v[0-9A-Za-z._-]+' \
      | sed 's#.*releases/tag/##' \
      | grep -E -- '-(beta|rc|alpha)' \
      | head -n1)"
    [ -n "$tag" ] && { printf '%s\n' "$tag"; return 0; }
  done
  return 1
}

# neveshtan-e amn-e atomic ba lock va staging dar haman filesystem (jelogiri az khandane config-e nim-kare).
# $1 = file-e movaqqat (generated); $2 = file-e live (masir-e vaghei config).
# agar src khali bashad (0 byte) rad mikonad ta rathole config-e naghes nabinad.
_RTH_HAS_FLOCK=""
_rth_has_flock(){
  [ -n "$_RTH_HAS_FLOCK" ] || { command -v flock >/dev/null 2>&1 && _RTH_HAS_FLOCK=1 || _RTH_HAS_FLOCK=0; }
  [ "$_RTH_HAS_FLOCK" = 1 ]
}

rth_commit_config(){
  local src="$1" dst="$2" lock="${2}.lock"
  [ -s "$src" ] || { err "config-e jadid khali ast: $src"; return 1; }
  [ -L "$dst" ] && { err "masir-e maghsad symlink ast: $dst"; return 1; }
  [ -L "$lock" ] && { err "masir-e ghofl symlink ast: $lock"; return 1; }
  local dir; dir="$(dirname "$dst")"
  [ -L "$dir" ] && { err "directory-e maghsad symlink ast: $dir"; return 1; }
  mkdir -p "$dir" || { err "nemitoonam directory-e config ra besazam: $dir"; return 1; }
  case "$dir" in
    */rathole|*/rathole/*|*/rathole-manager|*/rathole-manager/*)
      chmod 700 "$dir" 2>/dev/null || true
      ;;
  esac
  local tmp
  if ! tmp="$(mktemp "${dir}/.$(basename "$dst").tmp.XXXXXX" 2>/dev/null)"; then
    err "sakht-e config-e staging dar directory-e maghsad shekast khord: $dir"
    return 1
  fi
  if ! chmod 600 "$tmp" 2>/dev/null; then
    err "tanzim-e dastresi (chmod 600) rooye config-e staging shekast khord: $tmp"
    rm -f "$tmp"
    return 1
  fi
  if ! cp -f "$src" "$tmp" 2>/dev/null; then
    err "kopi be config-e staging shekast khord: $tmp"
    rm -f "$tmp"
    return 1
  fi

  if _rth_has_flock; then
    local lock_rc=0
    (
      flock -x -w 30 9 || exit 2
      mv -f "$tmp" "$dst" || exit 3
    ) 9>>"$lock" || lock_rc=$?
    if [ "$lock_rc" -eq 2 ]; then
      err "ghofl-e config azad nashod (flock timeout 30s): $dst"
      rm -f "$tmp"
      return 1
    elif [ "$lock_rc" -eq 3 ]; then
      err "jaye gozini-e config shekast khord (mv error): $dst"
      rm -f "$tmp"
      return 1
    elif [ "$lock_rc" -ne 0 ]; then
      err "baz kardan ya amaliat-e ghofl-e config shekast khord ($lock_rc): $lock"
      rm -f "$tmp"
      return 1
    fi
  else
    local d="${dst}.lockd" i=0 held=0 rc=0
    [ -L "$d" ] && { rm -f "$tmp"; err "lock directory symlink ast: $d"; return 1; }
    while [ "$i" -lt 50 ]; do
      if mkdir "$d" 2>/dev/null; then held=1; break; fi
      i=$((i+1)); sleep 0.1 2>/dev/null || sleep 1
    done
    if [ "$held" -ne 1 ]; then
      err "ghofl-e '$dst' azad nashod (mkdir timeout); baraye jelogiri az corruption motavaghef mishavam."
      rm -f "$tmp"
      return 1
    fi
    if ! mv -f "$tmp" "$dst"; then
      rmdir "$d" 2>/dev/null || true
      rm -f "$tmp"
      err "jaye gozini-e config shekast khord (mv error): $dst"
      return 1
    fi
    rmdir "$d" 2>/dev/null || true
  fi
  chmod 600 "$dst" 2>/dev/null || true
  rm -f "$src" "$tmp"
}


# chap-e noskhe — ham baraye ensan ham machine-parseable (hub 'manager_version=' ra migirad).
# $1=role (panel|node|hub) faghat baraye namayesh; rathole-version az binari khande mishavad.
print_version(){
  local role="${1:-?}" rv
  rv="$(rathole --version 2>/dev/null | head -n1 | awk '{print $NF}')"
  [ -n "$rv" ] || rv="-"
  echo "manager_version=${MANAGER_VERSION}"
  echo "role=${role}"
  echo "rathole_version=${rv}"
}

# profile FEC → "datashard parityshard mode sndwnd rcvwnd"
kcp_profile(){
  case "${1:-balanced}" in
    balanced)   echo "10 3 fast2 2048 2048" ;;
    lossy)      echo "10 5 fast2 2048 2048" ;;
    aggressive) echo "10 4 fast3 4096 4096" ;;
    *) return 1 ;;
  esac
}

# nasb kcptun (server|client)
install_kcptun(){
  local role="$1" bin="/usr/local/bin/kcptun-$1" ver="${KCPTUN_VER:-v20260129}" base="${KCPTUN_BASE:-https://github.com/ossfork/kcptun/releases/download}" arch tmp url ok=0 m
  [ -x "$bin" ] && return 0
  case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; armv7l) arch=armv7 ;; *) die "memari poshtibani nemishavad." ;; esac
  command -v curl >/dev/null 2>&1 || die "curl lazem ast."
  log "download kcptun ${ver} ($role)..."
  tmp="$(mktemp -d)"
  url="${base}/${ver}/kcptun_linux_${arch}.tar.gz"
  # gard-e transfer-e raked ba fallback-e chand mirror baraye dor-zadan filtering
  for m in "${RTH_MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 20 --speed-limit 1024 --speed-time 30 --retry 2 \
         "${m}${url}" -o "$tmp/k.tgz" 2>/dev/null; then
      ok=1; break
    fi
    warn "in mnba javab nadad, mnba-ye badi..."
  done
  [ "$ok" -eq 1 ] || { rm -rf "$tmp"; die "download kcptun az hame-ye mnaba shekast khord."; }
  tar -xzf "$tmp/k.tgz" -C "$tmp" || { rm -rf "$tmp"; die "baz kardan arshiv kcptun shekast khord."; }
  install -m755 "$tmp/${role}_linux_${arch}" "$bin" || { rm -rf "$tmp"; die "nasb bainri kcptun shekast khord."; }
  rm -rf "$tmp"
  log "kcptun-$role nasb shod: $bin"
}

# profile mux-e backhaul (SMUX) → "mux_con mux_version mux_framesize mux_recievebuffer mux_streambuffer connection_pool"
# HAR DO taraf (server/client) bayad haman profile ra dashte bashand ta parametrhaye SMUX yeksan bemanad.
# nokte: 'mux_con' faghat samt-e server mani darad va 'connection_pool' faghat samt-e client —
# har taraf field-e marbut be khodash ra minevisad va baghi ra dor mirizad.
backhaul_mux_profile(){
  case "${1:-balanced}" in
    balanced)   echo "8 1 32768 4194304 65536 8" ;;
    lossy)      echo "4 1 32768 4194304 65536 6" ;;
    aggressive) echo "16 2 65536 8388608 131072 12" ;;
    *) return 1 ;;
  esac
}

# transport-e client az roo-ye transport-e server: TLS FAGHAT ru-ye nginx terminate mishavad,
# pas server hamishe variant-e bedoon-e TLS ast (ws/wsmux) va client variant-e TLS-dar (wss/wssmux)
# ra be nginx:443 mizanad — daghighan haman invariant-e rathole (server tls=false, client tls=true).
backhaul_client_transport(){
  case "${1:-wsmux}" in
    ws)    echo "wss" ;;
    wsmux) echo "wssmux" ;;
    *) return 1 ;;
  esac
}

# nasb backhaul (server|client). binary-e Go tak-fail ast; role faghat dar esm-e khoruji tafavot darad.
# ba halqe-ye mirror ta az dakhel Iran (filtr/thrim github) ham javab begirad — haman elgo-ye install-panel.
# binary-e patch-shode-ye ma (uTLS ClientHello-ye Chrome) agar kenar-e script-ha bashad.
# masir hamsan-e core-e rathole: <SHARE>/core-backhaul/<target>/backhaul + SHA256SUMS.
# idempotent: agar binary-e nasb-shode HAMIN core bashad، dast nemizanad (rc=0).
# bargasht: 0 agar core-e dorost sar-e jash bashad. RATHOLE_NO_CORE_BACKHAUL=1 in masir ra rad mikonad.
install_backhaul_core(){
  # RATHOLE_BIN_DIR faghat baraye test ast (masir-e vaghei /usr/local/bin).
  local role="$1" bin="${RATHOLE_BIN_DIR:-/usr/local/bin}/backhaul-$1" d target want have
  [ "${RATHOLE_NO_CORE_BACKHAUL:-0}" = 1 ] && return 1
  case "$(uname -m)" in x86_64) target=linux-amd64 ;; aarch64) target=linux-arm64 ;; *) return 1 ;; esac
  for d in "${RATHOLE_CORE_BACKHAUL_DIR:-}" /usr/local/share/rathole/core-backhaul \
           "${BASH_SOURCE[0]%/*}/core-backhaul"; do
    [ -n "$d" ] && [ -f "$d/$target/backhaul" ] && [ -f "$d/SHA256SUMS" ] || continue
    ( cd "$d" && sha256sum -c SHA256SUMS --ignore-missing --quiet ) 2>/dev/null || {
      err "checksum-e core-e backhaul motabar nist ($d) — rad shod."; continue; }
    want="$(sha256sum "$d/$target/backhaul" 2>/dev/null | cut -d' ' -f1)"
    have=""; [ -x "$bin" ] && have="$(sha256sum "$bin" 2>/dev/null | cut -d' ' -f1)"
    [ -n "$want" ] && [ "$want" = "$have" ] && return 0   # az ghabl haman core ast
    install -m755 "$d/$target/backhaul" "$bin" || continue
    log "backhaul-$role az core-e patch-shode nasb/berooz shod (uTLS): $bin"
    return 0
  done
  return 1
}

install_backhaul(){
  local role="$1" bin="${RATHOLE_BIN_DIR:-/usr/local/bin}/backhaul-$1" ver="${BACKHAUL_VER:-v0.6.5}" arch tmp ok=0 m
  # MOHEM: core AVVAL check mishavad، na baad az `[ -x $bin ]`. vagarna har node-i ke az ghabl
  # binary-e ghadimi darad (yaani HAMEYE node-haye mojood) HARGEZ noskhe-ye uTLS ra nemigirad —
  # hatta baad az update — va bi-seda rooye asar-angosht-e Go mimanad.
  install_backhaul_core "$role" && return 0
  [ -x "$bin" ] && return 0
  case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; *) die "memari poshtibani nemishavad." ;; esac
  command -v curl >/dev/null 2>&1 || die "curl lazem ast."
  warn "core-e patch-shode peyda nashod؛ backhaul-e upstream download mishavad (bedoon-e uTLS)."
  log "download backhaul ${ver} ($role)..."
  tmp="$(mktemp -d)"
  for m in "" "https://ghproxy.net/" "https://gh-proxy.com/" "https://mirror.ghproxy.com/"; do
    if curl -fsSL --connect-timeout 20 --retry 2 "${m}https://github.com/Musixal/Backhaul/releases/download/${ver}/backhaul_linux_${arch}.tar.gz" -o "$tmp/bh.tgz" 2>/dev/null; then ok=1; break; fi
    warn "in mnba javab nadad, mnba-ye badi..."
  done
  [ "$ok" -eq 1 ] || { rm -rf "$tmp"; die "download backhaul az hame-ye mnaba shekast khord."; }
  tar -xzf "$tmp/bh.tgz" -C "$tmp" || { rm -rf "$tmp"; die "baz kardan arshiv backhaul shekast khord."; }
  local src; src="$(find "$tmp" -maxdepth 2 -type f -name 'backhaul*' ! -name '*.tar.gz' | head -n1)"
  [ -n "$src" ] || { rm -rf "$tmp"; die "binary-e backhaul dar arshiv peyda nashod."; }
  install -m755 "$src" "$bin" || { rm -rf "$tmp"; die "nasb binary backhaul shekast khord."; }
  rm -rf "$tmp"
  log "backhaul-$role nasb shod: $bin"
}

# tanzimat sysctl (BBR + file limits + conntrack)
apply_sysctl_tuning(){
  modprobe nf_conntrack 2>/dev/null || true
  cat >/etc/sysctl.d/99-rathole-tune.conf <<'TUNE'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_fastopen=3
fs.file-max=2097152
net.core.somaxconn=65535
net.core.netdev_max_backlog=16384
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.ip_local_port_range=1024 65535
net.netfilter.nf_conntrack_max=1048576
net.core.rmem_max=26214400
net.core.wmem_max=26214400
net.core.rmem_default=1048576
net.core.wmem_default=1048576
TUNE
  sysctl --system >/dev/null 2>&1 || true
  log "BBR=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)  conntrack_max=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo n/a)"
}

# sakht safhe-ye web fik ba mohtavaye kamel va herfei (jelogiri az tashkhis ba probe-e faal)
rth_write_fakeweb_html(){
  local dir="${1:-/var/www/rathole-fake}"
  mkdir -p "$dir"
  local target="$dir/index.html"
  if [ -f "$target" ] && ! grep -q "It works!" "$target" 2>/dev/null; then
    return 0 # file kastom karbar dast نخورد
  fi
  cat > "$target" <<'HTML'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>شرکت پیشگامان ارتباطات و داده‌های ابری | ارائه خدمات فناوری اطلاعات</title>
  <meta name="description" content="ارائه‌دهنده راهکارهای جامع پردازش ابری، مدیریت مراکز داده، یکپارچه‌سازی سامانه‌ها و مشاوره زیرساخت شبکه.">
  <style>
    :root { --primary: #1e3a8a; --secondary: #0284c7; --accent: #0ea5e9; --dark: #0f172a; --light: #f8fafc; --gray: #64748b; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; background: var(--light); color: var(--dark); line-height: 1.6; direction: rtl; }
    header { background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1); position: sticky; top: 0; z-index: 50; }
    .nav-container { max-width: 1200px; margin: 0 auto; padding: 1rem 1.5rem; display: flex; justify-content: space-between; align-items: center; }
    .logo { font-size: 1.25rem; font-weight: 700; color: var(--primary); }
    .nav-links { display: flex; gap: 1.5rem; list-style: none; }
    .nav-links a { text-decoration: none; color: var(--gray); font-weight: 500; }
    .nav-links a:hover { color: var(--secondary); }
    .hero { background: linear-gradient(135deg, #1e3a8a 0%, #0369a1 100%); color: white; padding: 4.5rem 1.5rem; text-align: center; }
    .hero-container { max-width: 800px; margin: 0 auto; }
    .hero h1 { font-size: 2.1rem; margin-bottom: 1rem; font-weight: 800; line-height: 1.3; }
    .hero p { font-size: 1.05rem; opacity: 0.9; margin-bottom: 1.5rem; }
    .btn { display: inline-block; background: var(--accent); color: white; padding: 0.75rem 1.75rem; border-radius: 0.5rem; text-decoration: none; font-weight: 600; }
    .features { max-width: 1200px; margin: -2.5rem auto 3.5rem; padding: 0 1.5rem; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; }
    .card { background: white; padding: 1.75rem; border-radius: 0.75rem; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); border: 1px solid #e2e8f0; }
    .card h3 { color: var(--primary); margin-bottom: 0.75rem; font-size: 1.2rem; }
    .card p { color: var(--gray); font-size: 0.95rem; }
    .stats { background: white; padding: 3rem 1.5rem; border-top: 1px solid #e2e8f0; border-bottom: 1px solid #e2e8f0; text-align: center; }
    .stats-container { max-width: 1200px; margin: 0 auto; display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1.5rem; }
    .stat-item h4 { font-size: 1.9rem; color: var(--secondary); margin-bottom: 0.25rem; }
    .stat-item p { color: var(--gray); font-size: 0.85rem; }
    footer { background: var(--dark); color: #94a3b8; padding: 2.5rem 1.5rem 1.5rem; font-size: 0.85rem; }
    .footer-container { max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; flex-wrap: wrap; gap: 1.5rem; padding-bottom: 1.5rem; border-bottom: 1px solid #334155; }
    .footer-col h5 { color: white; margin-bottom: 0.75rem; font-size: 0.95rem; }
    .copyright { text-align: center; margin-top: 1.25rem; }
  </style>
</head>
<body>
  <header>
    <div class="nav-container">
      <div class="logo">پیشگامان ارتباطات ابری پارس</div>
      <ul class="nav-links">
        <li><a href="#services">خدمات سازمانی</a></li>
        <li><a href="#solutions">زیرساخت ابری</a></li>
        <li><a href="#contact">ارتباط با ما</a></li>
      </ul>
    </div>
  </header>
  <section class="hero">
    <div class="hero-container">
      <h1>راهکارهای نوین زیرساخت شبکه و محاسبات ابری</h1>
      <p>طراحی، پیاده‌سازی و نگهداری سرویس‌های سازمانی با تضمین دسترسی‌پذیری ۹۹.۹٪، امنیت پیشرفته و مقیاس‌پذیری آنی.</p>
      <a href="#contact" class="btn">مشاوره تخصصی</a>
    </div>
  </section>
  <section class="features" id="services">
    <div class="grid">
      <div class="card">
        <h3>شبکه و میزبانی اختصاصی</h3>
        <p>ارائه پهنای باند اختصاصی متقارن، اتصال مستقیم به مراکز تبادل داده داخلی و مسیریابی بهینه کم‌تاخیر.</p>
      </div>
      <div class="card">
        <h3>مدیریت سرورهای ابری</h3>
        <p>استقرار ماشین‌های ابری مدرن با دیسک‌های پرسرعت NVMe و مانیتورینگ ۲۴ ساعته منابع.</p>
      </div>
      <div class="card">
        <h3>امنیت و حفاظت لایه‌ای</h3>
        <p>دیواره آتشین پیشرفته، پایش ترافیک، مقابله با حملات توزیع‌شده و پشتیبان‌گیری منظم برون‌سازمانی.</p>
      </div>
    </div>
  </section>
  <section class="stats" id="solutions">
    <div class="stats-container">
      <div class="stat-item"><h4>۹۹.۹۸٪</h4><p>تضمین پایداری سالانه</p></div>
      <div class="stat-item"><h4>۲۴/۷</h4><p>پشتیبانی فنی NOC</p></div>
      <div class="stat-item"><h4>۵۰۰+</h4><p>پروژه زیرساختی موفق</p></div>
      <div class="stat-item"><h4>< ۵ ms</h4><p>میانگین زمان پاسخ شبکه</p></div>
    </div>
  </section>
  <footer id="contact">
    <div class="footer-container">
      <div class="footer-col">
        <h5>شرکت پیشگامان ارتباطات ابری پارس (سهامی خاص)</h5>
        <p>مرکز عملیات شبکه (NOC): تهران، خیابان مطهری، برج فناوری</p>
      </div>
      <div class="footer-col">
        <h5>ارتباط و پشتیبانی</h5>
        <p>تلفن مرکزی: ۰۲۱-۸۸۹۴۰۰۰۰ | ایمیل: noc@cloud-systems.ir</p>
      </div>
    </div>
    <div class="copyright"><p>© کلیه حقوق متعلق به شرکت پیشگامان ارتباطات ابری پارس می‌باشد.</p></div>
  </footer>
</body>
</html>
HTML
}

# service systemd fakeweb (web fik ba python3)
fakeweb_service(){
  local svc="$1" port="${2:-8081}" action="${3:-start}"
  rth_write_fakeweb_html /var/www/rathole-fake
  cat > /var/www/rathole-fake/server.py <<'PYEOF'
import http.server, socketserver, sys, os
port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
os.chdir('/var/www/rathole-fake')
class H(http.server.SimpleHTTPRequestHandler):
    def _resolve(self):
        f = self.translate_path(self.path)
        if not os.path.exists(f) or os.path.isdir(f):
            self.path = '/index.html'
    def do_GET(self):
        self._resolve()
        return super().do_GET()
    def do_HEAD(self):
        self._resolve()
        return super().do_HEAD()
    # anti-fingerprint: sayt-e vaghei POST/OPTIONS/... ra mipazirad; 501-e SimpleHTTPRequestHandler
    # yek eshgarh-e vahih ast (scanner-e methode-ha ra miskanad). hame method-ha sayt-e fik ra midahand.
    def do_POST(self):
        self._resolve()
        return super().do_GET()
    do_PUT = do_POST
    do_PATCH = do_POST
    do_DELETE = do_POST
    do_OPTIONS = do_POST
    def log_message(self, format, *args):
        pass
with socketserver.TCPServer(('127.0.0.1', port), H) as httpd:
    httpd.serve_forever()
PYEOF
  case "$action" in
    start)
      cat > "/etc/systemd/system/${svc}.service" <<UNIT
[Unit]
Description=rathole fake web ($svc)
After=network.target
[Service]
ExecStart=/usr/bin/python3 /var/www/rathole-fake/server.py ${port}
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT
      systemctl daemon-reload
      systemctl enable "$svc" >/dev/null 2>&1 || true
      # restart (na faghat enable --now): agar ghablan dasht ejra mishavad, bayad ba
      # server.py-e jadid bargardad — gheyr-in soorat handler-e ghadimi zende mimanad.
      systemctl restart "$svc" >/dev/null 2>&1 || true
      if systemctl is-active --quiet "$svc"; then
        log "web fik ($svc) rooye 127.0.0.1:${port} bala amad."
      else
        err "web fik ($svc) bala niamad; journalctl -u $svc -n 30 --no-pager"
        return 1
      fi ;;
    stop)   systemctl stop "$svc" 2>/dev/null && log "motevaghef shod." || warn "ejra naboodan." ;;
    rm)     systemctl disable --now "$svc" 2>/dev/null || true; rm -f "/etc/systemd/system/${svc}.service"; systemctl daemon-reload; log "hazf shod." ;;
    status) systemctl --no-pager status "$svc" | sed -n '1,8p' || true ;;
  esac
}
# ---------------------------------------------------------------------------
# jam-avari-ye log baraye eshkal-zodai (`ratholectl logs` / `ratholenode logs`)
# ---------------------------------------------------------------------------
# HOSHDAR-E AMNIATI: khorooji-ye in tavabe maamoolan dar chat/issue paste mishavad.
# har chizi ke token/kelid/ramz ast BAYAD az inja rad shavad. rth_redact tanha
# darvaze-ye khorooj ast — har file-e jadidi ke ezafe mikoni HATMAN az an rad kon.
rth_redact(){
  sed -E \
    -e 's/("(token|api_token|bh_token|backhaul_token|admin_password_sha256|admin_password_hash|password|secret|private_key|privkey|noise_privkey|noise_private_key|local_private_key|remote_public_key|noise_public_key|key|trusted_root)"[[:space:]]*:[[:space:]]*")[^"]*"/\1***REDACTED***"/g' \
    -e 's/^([[:space:]]*(token|default_token|password|secret|private_key|privkey|noise_privkey|local_private_key|remote_public_key|key)[[:space:]]*=[[:space:]]*")[^"]*"/\1***REDACTED***"/' \
    -e 's/^([[:space:]]*(TOKEN|BH_TOKEN|NOISE_KEY|NOISE_PRIVKEY|KCP_KEY|PASSWORD|API_TOKEN)=).*/\1***REDACTED***/' \
    -e 's#(/_rh/)[A-Fa-f0-9]{8,}#\1***REDACTED***#g' \
    -e 's/([?&](token|password|secret)=)[^&"[:space:]]*/\1***REDACTED***/g'
}

# yek bakhsh-e onvan-dar dar khorooji-ye log
rth_sec(){ printf '\n===== %s =====\n' "$*"; }

# log-e yek unit-e systemd (agar vojood dashte bashad)
rth_unit_log(){ # $1=unit  $2=tedad khat
  local u="$1" n="${2:-80}"
  systemctl list-unit-files "$u.service" >/dev/null 2>&1 || return 0
  [ -f "/etc/systemd/system/$u.service" ] || [ -f "/lib/systemd/system/$u.service" ] || return 0
  rth_sec "unit: $u  (halat: $(systemctl is-active "$u" 2>/dev/null || echo unknown)/$(systemctl is-enabled "$u" 2>/dev/null || echo n/a))"
  journalctl -u "$u" -n "$n" --no-pager 2>/dev/null | rth_redact || true
}

# mohtava-ye yek file-e config (redact-shode)
rth_file_dump(){ # $1=barchasb  $2=masir  [$3=hadaksar khat]
  local label="$1" p="$2" n="${3:-200}"
  [ -f "$p" ] || { rth_sec "$label ($p) — NIST"; return 0; }
  rth_sec "$label ($p)"
  head -n "$n" "$p" 2>/dev/null | rth_redact || true
}
