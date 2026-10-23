#!/usr/bin/env bash
# bootstrap.sh — amade-sazi mhit, thih baste (mahalli ya download), baz kardan va ejra-ye nasab
#
# agar baste (rathole-manager.zip / .tar.gz) knar askript ya dar masir jari bashd, download nemishavad.
# agar etelaat kafi ndhi, bhsvrt taamoli miporsad.
#
# nemoonehaye gheyre-taamoli:
#   sudo bash bootstrap.sh --panel --domain panel.example.ir \
#        --fullchain /root/cert/panel.example.ir/fullchain.pem --key /root/cert/panel.example.ir/privkey.pem
#   sudo bash bootstrap.sh --node -- --server panel.example.ir:443 --name trk01 --token <T> --inbound-port 2087
#   sudo bash bootstrap.sh --url https://host/rathole-manager.zip --panel ...
#   sudo bash bootstrap.sh --local ./rathole-manager.zip --no-run
#   sudo bash bootstrap.sh --local ./rathole-manager.zip --update   # update kamel (khodkar panel/node/hub)
#   sudo bash bootstrap.sh --uninstall            # hazf kamel (panel/node/hub) ba taid
#   sudo bash bootstrap.sh --purge --yes          # hazf kamel + binary rathole/config hub، bedoon porsesh
#
# taamoli: fght `sudo bash bootstrap.sh` va baghie ra miporsad (menu shamel gozine update ham hast).

set -euo pipefail

# amniat-e sarasari: umask 077
umask 077

BUNDLE_URL="${BUNDLE_URL:-}"
LOCAL=""
INSTALL_DIR="${INSTALL_DIR:-/opt/rathole-manager}"
MODE=""
RUN=1
ASSUME_YES=0
ROLLBACK_TS=""
PURGE=0
PASS_ARGS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$PWD")"

c_g(){ printf '\033[1;32m%s\033[0m' "$*"; }
c_r(){ printf '\033[1;31m%s\033[0m' "$*"; }
c_y(){ printf '\033[1;33m%s\033[0m' "$*"; }
log(){ printf '%s %s\n' "$(c_g '[+]')" "$*"; }
warn(){ printf '%s %s\n' "$(c_y '[*]')" "$*"; }
err(){ printf '%s %s\n' "$(c_r '[!]')" "$*" >&2; }
die(){ err "$*"; exit 1; }
# zir-e `curl ... | sudo bash` stdin pipe ast na terminal؛ agar /dev/tty baz shavad
# hanooz mitavanim taamoli beporsim (rdp/ask_yn az /dev/tty mikhanand).
TTY_DEV=""
if [ ! -t 0 ] && { : < /dev/tty; } 2>/dev/null; then TTY_DEV="/dev/tty"; fi
is_tty(){ [ -t 0 ] || [ -n "$TTY_DEV" ]; }
rdp(){ # read -rp ke ba stdin-e pipe ham kar mikonad: $1=prompt $2=nam-e motghayer
  # MOHEM: agar NA stdin terminal bashad va NA /dev/tty baz shavad, HARGEZ az stdin nakhan —
  # `read` rooye pipe-e baz ta abad montazer mimanad va prompt ham chap nemishavad (nasb bi-seda
  # gir mikonad). timeout ham backstop-e terminal-e bi-morajea (screen-e detach-shode) ast.
  local t="${RTH_READ_TIMEOUT:-300}"
  if   [ -n "$TTY_DEV" ]; then IFS= read -rt "$t" -p "$1" "$2" < "$TTY_DEV"
  elif [ -t 0 ];         then IFS= read -rt "$t" -p "$1" "$2"
  else printf -v "$2" '%s' ""; fi
}
ask_yn(){ [ "$ASSUME_YES" -eq 1 ] && return 0; local a; rdp "$1 [Y/n]: " a; [[ -z "$a" || "$a" =~ ^[Yy]$ ]]; }

# ---------- pars argvmanha ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --url)     BUNDLE_URL="$2"; shift 2;;
    --local)   LOCAL="$2"; shift 2;;
    --dir)     INSTALL_DIR="$2"; shift 2;;
    --panel)   MODE="panel"; shift;;
    --node)    MODE="node"; shift;;
    --update)  MODE="update"; shift;;
    --rollback) MODE="rollback"; shift
                if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then ROLLBACK_TS="$1"; shift; fi ;;
    --list-backups) MODE="listbackups"; shift;;
    --uninstall|--remove) MODE="uninstall"; shift;;
    --purge)   MODE="uninstall"; PURGE=1; shift;;
    --no-run)  RUN=0; shift;;

    --sha256)  EXPECTED_SHA256="$2"; shift 2;;
    --sha256=*) EXPECTED_SHA256="${1#*=}"; shift;;
    --sha256sums-file) SHA256SUMS_FILE="$2"; shift 2;;
    --sha256sums-file=*) SHA256SUMS_FILE="${1#*=}"; shift;;
    --yes|-y)  ASSUME_YES=1; shift;;
    --)        shift; PASS_ARGS+=("$@"); break;;
    *)         PASS_ARGS+=("$1"); shift;;
  esac
done

if [ "${BOOTSTRAP_LIB_ONLY:-0}" != 1 ]; then
  [ "$(id -u)" -eq 0 ] || die "bayad ba root ejra shavad (sudo)."
fi

# ---------- nasb pishniazhai paih ----------
install_prereqs(){
  local pkgs="curl unzip tar ca-certificates"
  log "amade-sazi mohit va nasb pish-niazha ($pkgs)..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive; apt-get update -y && apt-get install -y $pkgs || warn "apt-get install ba khata movajeh shod."
  elif command -v dnf >/dev/null 2>&1; then dnf install -y $pkgs || warn "dnf install ba khata movajeh shod."
  elif command -v yum >/dev/null 2>&1; then yum install -y $pkgs || warn "yum install ba khata movajeh shod."
  elif command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm curl unzip tar ca-certificates || warn "pacman install ba khata movajeh shod."
  elif command -v apk >/dev/null 2>&1; then apk add --no-cache curl unzip tar ca-certificates bash || warn "apk install ba khata movajeh shod."
  else warn "pkijmnijr shnakhth nshd; motmaen shv curl/unzip/tar nasb-and."; fi

  local missing=()
  command -v tar >/dev/null 2>&1 || missing+=("tar")
  command -v unzip >/dev/null 2>&1 || missing+=("unzip")
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    missing+=("curl/wget")
  fi
  if [ "${#missing[@]}" -gt 0 ]; then
    die "abzarhaye lazem nasb nashodand: ${missing[*]}. lotfan anha ra dasti nasb kon."
  fi
}

# ---------- peyda kardan baste-ye mahalli ----------
find_local_bundle(){
  local d f
  for d in "$SCRIPT_DIR" "$PWD"; do
    for f in rathole-manager.zip rathole-manager.tar.gz rathole-manager.tgz; do
      [ -f "$d/$f" ] && { echo "$d/$f"; return 0; }
    done
  done
  return 1
}

# ---------- peyda kardan update.sh-e mahalli (baraye rollback/list-backups bedoon download) ----------
find_update_sh(){
  local c
  for c in "$INSTALL_DIR/update.sh" "$SCRIPT_DIR/rathole-manager/update.sh" "$SCRIPT_DIR/update.sh"; do
    [ -f "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

# ---------- ejra-ye rollback/list-backups az tarigh-e update.sh ----------
exec_update_action(){ # $1 = masir update.sh
  local u="$1"
  case "$MODE" in
    listbackups) exec bash "$u" --list-backups ;;
    rollback)    if [ -n "$ROLLBACK_TS" ]; then exec bash "$u" --rollback "$ROLLBACK_TS"; else exec bash "$u" --rollback; fi ;;
  esac
}

# ---------- tashkhis mnba baste (mahalli ya download) ----------
SRC_FILE=""   # agar pr shvd, iani file mahalli darim va download lazem nist
resolve_source(){
  # 1) --local sarih
  if [ -n "$LOCAL" ]; then
    [ -f "$LOCAL" ] || die "file mahalli peyda nashod: $LOCAL"
    SRC_FILE="$LOCAL"; return
  fi
  # 2) --url ke dar vaghe masir/file mahalli ast
  if [ -n "$BUNDLE_URL" ]; then
    case "$BUNDLE_URL" in
      file://*) local f="${BUNDLE_URL#file://}"; [ -f "$f" ] && SRC_FILE="$f" ;;
      /*|./*|../*) [ -f "$BUNDLE_URL" ] && SRC_FILE="$BUNDLE_URL" ;;
    esac
    return   # agar SRC_FILE khali mand, iani URL rah dvr ast → download
  fi
  # 3) jostojoo-ye khodkar baste-ye mahalli
  local lb
  if lb="$(find_local_bundle)"; then
    log "baste-ye mahalli peyda shod: $(c_y "$lb")"
    if ask_yn "az hamin estefade shavad (bedoon download)?"; then SRC_FILE="$lb"; return; fi
  fi
  # 4) chizi nadarim → agar taamoli ast bprs, vagarna khata
  if is_tty; then
    local ans; rdp "link baste (URL) ya masir file mahalli: " ans
    [ -n "$ans" ] || die "mnba baste dade nashod."
    if [ -f "$ans" ]; then SRC_FILE="$ans"; else BUNDLE_URL="$ans"; fi
  else
    die "baste-i peyda nashod va --url/--local ham dade nashode."
  fi
}

# ---------- download va checksum ----------
download(){
  local url="$1" out="$2"
  log "download baste az: $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 3 --connect-timeout 20 "$url" -o "$out" || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$url" || return 1
  else
    return 1
  fi
  [ -s "$out" ] || { err "file-e download shode khali ast"; return 1; }
  if head -n 5 "$out" 2>/dev/null | grep -qiE '<!DOCTYPE|<html|<head|<error'; then
    err "file-e download shode be nazar HTML/error miad na archive."
    return 1
  fi
  return 0
}

verify_sha256(){
  local file="$1" expected_sum="$2"
  [ -f "$file" ] || return 1
  [ -n "$expected_sum" ] || return 0
  local actual_sum=""
  if command -v sha256sum >/dev/null 2>&1; then
    actual_sum="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual_sum="$(shasum -a 256 "$file" | awk '{print $1}')"
  elif command -v openssl >/dev/null 2>&1; then
    actual_sum="$(openssl dgst -sha256 "$file" | awk '{print $NF}')"
  else
    err "abzar-e mohasebe-ye sha256 peyda nashod."
    return 1
  fi
  if [ "$actual_sum" != "$expected_sum" ]; then
    err "checksum match nashod! entezar: $expected_sum , khorooji: $actual_sum"
    return 1
  fi
  log "checksum-e sha256 ba movafaghiat taiid shod: $actual_sum"
  return 0
}

_rth_validate_archive_python(){
  local archive="$1" type="$2"
  local py=""
  if command -v python3 >/dev/null 2>&1; then py=python3
  elif command -v python >/dev/null 2>&1; then py=python
  fi
  [ -n "$py" ] || return 2
  "$py" - "$archive" "$type" <<'PYEOF'
import sys, os

archive, atype = sys.argv[1], sys.argv[2]
if not os.path.isfile(archive) or os.path.getsize(archive) == 0:
    sys.exit(1)

def is_safe_relpath(p):
    if not p:
        return False
    if p.startswith('/') or (len(p) > 1 and p[1] == ':'):
        return False
    norm = p.replace('\\', '/')
    parts = norm.split('/')
    if '..' in parts:
        return False
    return True

if atype == "zip":
    import zipfile
    try:
        with zipfile.ZipFile(archive, 'r') as zf:
            infolist = zf.infolist()
            if not infolist:
                sys.exit(1)
            for info in infolist:
                if not is_safe_relpath(info.filename):
                    sys.exit(1)
                mode = info.external_attr >> 16
                if (mode & 0o170000) == 0o120000:
                    sys.exit(1)
    except Exception:
        sys.exit(1)
elif atype in ("tar", "tar.gz", "tgz"):
    import tarfile
    try:
        with tarfile.open(archive, 'r:*') as tf:
            members = tf.getmembers()
            if not members:
                sys.exit(1)
            for m in members:
                if not is_safe_relpath(m.name):
                    sys.exit(1)
                if m.isdev() or m.ischr() or m.isblk() or m.isfifo():
                    sys.exit(1)
                if m.issym() or m.islnk():
                    target = m.linkname
                    if target.startswith('/') or (len(target) > 1 and target[1] == ':'):
                        sys.exit(1)
                    if '..' in target.replace('\\', '/').split('/'):
                        sys.exit(1)
    except Exception:
        sys.exit(1)
else:
    sys.exit(1)
sys.exit(0)
PYEOF
}

validate_zip_archive(){
  local archive="$1"
  [ -f "$archive" ] || return 1
  [ -s "$archive" ] || return 1

  local py_rc=0
  _rth_validate_archive_python "$archive" "zip"
  py_rc=$?
  if [ "$py_rc" -eq 0 ]; then return 0; fi
  if [ "$py_rc" -eq 1 ]; then return 1; fi

  command -v unzip >/dev/null 2>&1 || return 1
  local tmp_list; tmp_list="$(mktemp 2>/dev/null || echo "${archive}.list.$$")"

  if ! unzip -tq "$archive" >/dev/null 2>&1; then
    rm -f "$tmp_list" 2>/dev/null
    err "validate_zip_archive: zip archive kharab ya gheyre-ghabel-e khandan ast"
    return 1
  fi

  if ! unzip -Z "$archive" > "$tmp_list" 2>/dev/null || [ ! -s "$tmp_list" ]; then
    rm -f "$tmp_list" 2>/dev/null
    err "validate_zip_archive: baz kardan-e fehrest-e zip shekast khord"
    return 1
  fi

  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      l*|"lrwx"*)
        err "validate_zip_archive: symlink dar zip mojaz nist: $line"
        rm -f "$tmp_list" 2>/dev/null
        return 1
        ;;
    esac
  done < "$tmp_list"

  if ! unzip -Z1 "$archive" > "$tmp_list" 2>/dev/null || [ ! -s "$tmp_list" ]; then
    rm -f "$tmp_list" 2>/dev/null
    err "validate_zip_archive: baz kardan-e asami-ye zip shekast khord"
    return 1
  fi

  local entry
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in
      /*|[A-Za-z]:*)
        err "validate_zip_archive: masir-e motlagh dar zip mojaz nist: $entry"
        rm -f "$tmp_list" 2>/dev/null
        return 1
        ;;
    esac
    if echo "$entry" | grep -qE '(^|/|\\)\.\.(/|\\|$)'; then
      err "validate_zip_archive: path traversal (..) dar zip mojaz nist: $entry"
      rm -f "$tmp_list" 2>/dev/null
      return 1
    fi
  done < "$tmp_list"

  rm -f "$tmp_list" 2>/dev/null
  return 0
}

validate_tar_archive(){
  local archive="$1"
  [ -f "$archive" ] || return 1
  [ -s "$archive" ] || return 1

  local py_rc=0
  _rth_validate_archive_python "$archive" "tar"
  py_rc=$?
  if [ "$py_rc" -eq 0 ]; then return 0; fi
  if [ "$py_rc" -eq 1 ]; then return 1; fi

  command -v tar >/dev/null 2>&1 || return 1
  local tmp_list; tmp_list="$(mktemp 2>/dev/null || echo "${archive}.list.$$")"

  if ! tar -tvf "$archive" > "$tmp_list" 2>/dev/null || [ ! -s "$tmp_list" ]; then
    rm -f "$tmp_list" 2>/dev/null
    err "validate_tar_archive: tar archive kharab ya gheyre-ghabel-e baz kardan ast"
    return 1
  fi

  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      l*|c*|b*|p*)
        err "validate_tar_archive: special file/symlink dar tar mojaz nist: $line"
        rm -f "$tmp_list" 2>/dev/null
        return 1
        ;;
      *" -> "*)
        err "validate_tar_archive: symlink/hardlink target dar tar mojaz nist: $line"
        rm -f "$tmp_list" 2>/dev/null
        return 1
        ;;
      *" link to "*)
        err "validate_tar_archive: hardlink dar tar mojaz nist: $line"
        rm -f "$tmp_list" 2>/dev/null
        return 1
        ;;
    esac
  done < "$tmp_list"

  if ! tar -tf "$archive" > "$tmp_list" 2>/dev/null || [ ! -s "$tmp_list" ]; then
    rm -f "$tmp_list" 2>/dev/null
    err "validate_tar_archive: tar -tf shekast khord"
    return 1
  fi

  local entry
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in
      /*|[A-Za-z]:*)
        err "validate_tar_archive: masir-e motlagh dar tar mojaz nist: $entry"
        rm -f "$tmp_list" 2>/dev/null
        return 1
        ;;
    esac
    if echo "$entry" | grep -qE '(^|/|\\)\.\.(/|\\|$)'; then
      err "validate_tar_archive: path traversal (..) dar tar mojaz nist: $entry"
      rm -f "$tmp_list" 2>/dev/null
      return 1
    fi
  done < "$tmp_list"

  rm -f "$tmp_list" 2>/dev/null
  return 0
}

# ---------- baz kardan ----------
extract(){
  local file="$1" dest="$2"
  mkdir -p "$dest"
  chmod 700 "$dest" 2>/dev/null || true
  case "$file" in
    *.zip)
      command -v unzip >/dev/null 2>&1 || die "unzip nasb nist."
      validate_zip_archive "$file" || die "arshiv zip shamel masir-e mashkook/traversal ast."
      unzip -q -o "$file" -d "$dest" >/dev/null || die "estekhraj-e zip shekast khord."
      fix_backslash_names "$dest"
      ;;
    *.tar.gz|*.tgz)
      validate_tar_archive "$file" || die "arshiv tar.gz shamel masir-e mashkook/traversal ast."
      tar --no-same-owner -xzf "$file" -C "$dest" || die "estekhraj-e tar.gz shekast khord."
      ;;
    *.tar)
      validate_tar_archive "$file" || die "arshiv tar shamel masir-e mashkook/traversal ast."
      tar --no-same-owner -xf "$file" -C "$dest" || die "estekhraj-e tar shekast khord."
      ;;
    *)
      if head -c 2 "$file" 2>/dev/null | grep -q "PK"; then
        command -v unzip >/dev/null 2>&1 || die "unzip nasb nist."
        validate_zip_archive "$file" || die "arshiv zip shamel masir-e mashkook/traversal ast."
        unzip -q -o "$file" -d "$dest" >/dev/null || die "estekhraj-e zip shekast khord."
        fix_backslash_names "$dest"
      else
        validate_tar_archive "$file" || die "arshiv shamel masir-e mashkook/traversal ast."
        tar --no-same-owner -xzf "$file" -C "$dest" 2>/dev/null || die "frmt file nashenakhte ast."
      fi
      ;;
  esac
}

# aslah namhaii ke ba backslash zkhirh shdhand (zip sakhthshdh ba Windows Compress-Archive)
fix_backslash_names(){
  local dest="$1" f rel fixed
  while IFS= read -r -d '' f; do
    rel="${f#"$dest"/}"
    fixed="${rel//\\//}"
    [ "$rel" = "$fixed" ] && continue
    mkdir -p "$dest/$(dirname "$fixed")"
    mv -f "$f" "$dest/$fixed"
  done < <(find "$dest" -type f -name '*\\*' -print0 2>/dev/null)
}

find_root(){
  local base="$1" f
  f="$(find "$base" -maxdepth 3 -name 'install-panel.sh' -print -quit 2>/dev/null)"
  [ -n "$f" ] && { dirname "$f"; return 0; }
  return 1
}

# ---------- tashkhis nasb-e mojood (baraye update-e khodkar) ----------
detect_installed(){ # rc=0 agar panel/node/hub ghablan nasb shode bashad
  [ -d /etc/rathole-manager ] || [ -f /etc/systemd/system/rathole-server.service ] || \
  [ -f /etc/rathole/node.env ] || [ -f /etc/systemd/system/rathole-client.service ] || \
  [ -f /opt/ratholehub/hub.py ] || [ -f /etc/systemd/system/ratholehub.service ]
}
installed_roles(){ # esm-e naghsh-haye nasb-shode baraye namayesh
  local r=()
  { [ -d /etc/rathole-manager ] || [ -f /etc/systemd/system/rathole-server.service ]; } && r+=(panel)
  { [ -f /etc/rathole/node.env ] || [ -f /etc/systemd/system/rathole-client.service ]; } && r+=(node)
  { [ -f /opt/ratholehub/hub.py ] || [ -f /etc/systemd/system/ratholehub.service ]; } && r+=(hub)
  echo "${r[*]:-}"
}

# ---------- hazf kamel (uninstall) ----------
# har naghsh-e nasb-shode ra ba uninstaller-e khodesh hazf mikonad (panel/node),
# va hub ra inja mostaghim (chون uninstaller-e joda nadarad). --purge/-y forward mishavad.
uninstall_hub(){
  log "hazf hub (ratholehub)..."
  systemctl disable --now ratholehub 2>/dev/null || true
  rm -f /etc/systemd/system/ratholehub.service
  systemctl daemon-reload 2>/dev/null || true
  rm -rf /opt/ratholehub
  if [ "$PURGE" -eq 1 ]; then
    warn "purge: pooshe-ye config-e hub (/etc/ratholehub — shamel token/ramz) ham hazf mishavad."
    rm -rf /etc/ratholehub
  else
    warn "config-e hub (/etc/ratholehub) baghi mand (baraye hazf-e kamel: --purge)."
  fi
  # location-e /hub/ dar nginx (agar ratholectl hub on sakhte bood)
  command -v ratholectl >/dev/null 2>&1 && ratholectl hub off 2>/dev/null || true
  log "hub hazf shod."
}

run_uninstall(){
  local dir="$1" roles f rc=0
  roles="$(installed_roles)"
  if [ -z "$roles" ]; then
    warn "hich nasb-e rathole-ei (panel/node/hub) peyda nashod؛ chizi baraye hazf nist."
    exit 0
  fi
  echo; warn "$(c_r 'HAZF-E KAMEL') — naghsh-haye nasb-shode: $(c_y "$roles")"
  warn "in kar service-ha، config-ha va state ra hazf mikonad. (gvahi/TLS dast nemikhorad.)"
  [ "$PURGE" -eq 1 ] && warn "purge faal ast: binary-e rathole va config-e hub ham hazf mishavand."
  ask_yn "motmaen hasti hazf shavad?" || { log "lghv shod."; exit 0; }

  local flags=(--yes); [ "$PURGE" -eq 1 ] && flags+=(--purge)

  case " $roles " in *" panel "*)
    f="$dir/uninstall-panel.sh"
    [ -f "$f" ] || f="$(find "$dir" -maxdepth 3 -name 'uninstall-panel.sh' -print -quit 2>/dev/null)"
    if [ -n "$f" ] && [ -f "$f" ]; then log "ejra-ye uninstall-panel.sh..."; bash "$f" "${flags[@]}" || rc=1
    else err "uninstall-panel.sh peyda nashod."; rc=1; fi ;;
  esac
  case " $roles " in *" node "*)
    f="$dir/uninstall-node.sh"
    [ -f "$f" ] || f="$(find "$dir" -maxdepth 3 -name 'uninstall-node.sh' -print -quit 2>/dev/null)"
    if [ -n "$f" ] && [ -f "$f" ]; then log "ejra-ye uninstall-node.sh..."; bash "$f" "${flags[@]}" || rc=1
    else err "uninstall-node.sh peyda nashod."; rc=1; fi ;;
  esac
  case " $roles " in *" hub "*) uninstall_hub || rc=1 ;; esac

  echo
  if [ "$rc" -eq 0 ]; then log "hazf-e kamel anjam shod."
  else err "hazf ba chand khata tamam shod؛ balaha ra barresi kon."; fi
  exit "$rc"
}

# ---------- entekhab halat va grftn etelaat (taamoli) ----------
choose_mode(){
  echo; echo "$(c_g 'halat nasb ra entekhab kon:')"
  echo "  1) panel (server Iran)"
  echo "  2) node (server kharej)"
  echo "  3) update (beroozresani kamel ba snapshot + rollback-e khodkar)"
  echo "  4) fght amade-sazi (bedoon ejra-ye nasab)"
  echo "  5) rollback (bazgasht be akharin snapshot-e ghabl az update)"
  echo "  6) list-e backup-ha (snapshot-haye mojood)"
  echo "  7) $(c_r 'hazf kamel') (uninstall — panel/node/hub + config/state)"
  local m def=""
  if detect_installed; then
    def="3"
    echo; warn "nasb-e mojood tashkhis dade shod: $(c_y "$(installed_roles)") → pishfarz: update"
  fi
  rdp "entekhab [1/2/3/4/5/6/7]${def:+ (pishfarz: $def)}: " m
  m="${m:-$def}"
  case "$m" in
    1) MODE="panel" ;;
    2) MODE="node" ;;
    3) MODE="update" ;;
    4) RUN=0 ;;
    5) MODE="rollback" ;;
    6) MODE="listbackups" ;;
    7) MODE="uninstall" ;;
    *) die "entekhab namotabar." ;;
  esac
}


prompt_node_args(){
  echo; log "etelaat node ra vared kon (az khorooji 'ratholectl add' rooye panel):"
  local server name token inbound atoken aib
  rdp "adres server Iran (masalan panel.example.ir:443): " server
  rdp "name node (masalan trk01): " name
  rdp "token service: " token
  rdp "port inbound 3x-ui / Xray rooye node [10001]: " inbound; inbound="${inbound:-10001}"
  rdp "token API (akhtiari, khali=rad): " atoken
  PASS_ARGS=(--server "$server" --name "$name" --token "$token" --inbound-port "$inbound")
  if [ -n "$atoken" ]; then
    rdp "port inbound API node [62050]: " aib; aib="${aib:-62050}"
    PASS_ARGS+=(--api-token "$atoken" --api-inbound-port "$aib")
  fi
}

main(){
  # rollback/list-backups: agar update.sh-e mahalli hast, bedoon download ejra kon
  if [ "$MODE" = "rollback" ] || [ "$MODE" = "listbackups" ]; then
    local u; if u="$(find_update_sh)"; then exec_update_action "$u"; fi
    warn "update.sh-e mahalli peyda nashod؛ baste ra amade mikonam..."
  fi

  # uninstall: uninstaller-ha maamoolan az nasb-e ghabli mojood-and → bedoon download hazf kon.
  # agar peyda nashodand (masalan nasb-e nimeh-kareh)، be amade-sazi-ye baste edame midahim.
  if [ "$MODE" = "uninstall" ]; then
    local d
    for d in "$INSTALL_DIR" "$SCRIPT_DIR" "$SCRIPT_DIR/rathole-manager"; do
      if [ -f "$d/uninstall-panel.sh" ] || [ -f "$d/uninstall-node.sh" ]; then
        run_uninstall "$d"   # exit mikonad
      fi
    done
    warn "uninstaller-e mahalli peyda nashod؛ baste ra amade mikonam..."
  fi

  install_prereqs
  resolve_source

  local tmp; tmp="$(mktemp -d)"
  local bundle
  local pickname="${SRC_FILE:-$BUNDLE_URL}"
  case "$pickname" in
    *.tar.gz|*.tgz) bundle="$tmp/bundle.tar.gz" ;;
    *.tar)          bundle="$tmp/bundle.tar" ;;
    *)              bundle="$tmp/bundle.zip" ;;
  esac

  if [ -n "$SRC_FILE" ]; then
    log "estefade az baste-ye mahalli (bedoon download): $SRC_FILE"
    cp "$SRC_FILE" "$bundle"
  else
    download "$BUNDLE_URL" "$bundle" || die "download shekast khord (link/shbkh/filtr ra barresi kon)."
  fi
  [ -s "$bundle" ] || die "baste khali ast (0 byte)."
  local sums_file="${SHA256SUMS_FILE:-}"
  if [ -z "$sums_file" ] && [ -n "$SRC_FILE" ] && [ -f "$(dirname "$SRC_FILE")/SHA256SUMS" ]; then
    sums_file="$(dirname "$SRC_FILE")/SHA256SUMS"
  fi
  if [ -z "${EXPECTED_SHA256:-}" ] && [ -n "$sums_file" ] && [ -f "$sums_file" ]; then
    local orig_name; orig_name="$(basename "$pickname")"
    EXPECTED_SHA256="$(grep -E "[[:space:]](\./)?(${orig_name}|rathole-manager\.zip|rathole-manager\.tar\.gz)$" "$sums_file" 2>/dev/null | awk '{print $1}' | head -n1 || true)"
  fi
  if [ -n "${EXPECTED_SHA256:-}" ]; then
    verify_sha256 "$bundle" "$EXPECTED_SHA256" || die "taiid-e checksum shekast khord (fail-closed)."
  fi
  log "hajm baste: $(du -h "$bundle" | cut -f1)"

  log "baz kardan baste..."
  extract "$bundle" "$tmp/x"
  local src; src="$(find_root "$tmp/x")" || die "askripthai nasb dar baste peyda nshdnd."
  log "mohtava-ye baste dar: $src"

  log "copy be $INSTALL_DIR ..."
  mkdir -p "$INSTALL_DIR"; cp -rf "$src/." "$INSTALL_DIR/"

  log "normal-sazi khate-payan va mojavez ejra..."
  find "$INSTALL_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "ratholectl" -o -name "ratholenode" \) -exec sed -i 's/\r$//' {} + 2>/dev/null || true
  find "$INSTALL_DIR" -type f \( -name "*.sh" -o -name "ratholectl" -o -name "ratholenode" \) -exec chmod +x {} + 2>/dev/null || true
  rm -rf "$tmp"
  log "baste amade shod dar: $INSTALL_DIR"

  # entekhab halat agar moshakhas nashode
  if [ -z "$MODE" ] && [ "$RUN" -eq 1 ]; then
    if is_tty; then choose_mode
    elif detect_installed; then
      # bedoon terminal (masalan curl | bash az cron/hub): nasb-e mojood → update-e khodkar
      warn "nasb-e mojood tashkhis dade shod ($(installed_roles)) va terminal nist → update-e khodkar."
      MODE="update"
    else RUN=0; fi
  fi

  if [ "$RUN" -eq 0 ] || [ -z "$MODE" ]; then
    echo; log "amade-sazi kamel shod (bedoon ejra-ye nasab)."
    echo "  panel:  $(c_y "sudo bash $INSTALL_DIR/install-panel.sh --domain <d> --fullchain <fc> --key <key>")"
    echo "  node:  $(c_y "sudo bash $INSTALL_DIR/install-node.sh --server <d>:443 --name <n> --token <t> --inbound-port <p>")"
    exit 0
  fi

  case "$MODE" in
    rollback|listbackups)
      # baste amade shod (chون update.sh-e mahalli naboud); hala action ra ejra kon
      exec_update_action "$INSTALL_DIR/update.sh" ;;
    uninstall)
      run_uninstall "$INSTALL_DIR" ;;
    update)
      # update kamel: update.sh khodesh panel/node/hub ra tashkhis mide va hameye ejza ra berooz mikonad
      log "ejra-ye update kamel ba snapshot + rollback-e khodkar..."
      exec bash "$INSTALL_DIR/update.sh" "${PASS_ARGS[@]}" ;;
    panel)
      log "ejra-ye nasab panel (agar argument ndhi, khodesh bhsvrt taamoli miporsad)..."
      exec bash "$INSTALL_DIR/install-panel.sh" "${PASS_ARGS[@]}" ;;

    node)
      # agar argument node dade nashode va taamoli hstim, bprs
      if [ "${#PASS_ARGS[@]}" -eq 0 ] && is_tty; then prompt_node_args; fi
      [ "${#PASS_ARGS[@]}" -gt 0 ] || die "etelaat node lazem ast (--server --name --token --inbound-port)."
      log "ejra-ye nasab node..."
      exec bash "$INSTALL_DIR/install-node.sh" "${PASS_ARGS[@]}" ;;
  esac
}

if [ "${BOOTSTRAP_LIB_ONLY:-0}" != 1 ]; then
  main
fi
