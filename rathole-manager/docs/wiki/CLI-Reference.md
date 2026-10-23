# مرجع کامل دستورات CLI (نسخه 1.8.9)

هر دو ابزار با `set -uo pipefail` اجرا می‌شوند، عملیات تغییردهنده قفل (`flock`) و snapshot دارند و در شکست fail-closed هستند.

## ratholectl (روی پنل ایران)

### نصب و پایه

| دستور | کار |
| :--- | :--- |
| `init --domain D --fullchain F --key K [گزینه‌ها]` | ساخت state اولیه (تعاملی بدون آرگومان) |
| `regen` | بازتولید server.toml + nginx conf + reload (بعد از هر تغییر دستی state) |
| `status [--json]` | داشبورد پورت‌ها/حالت‌ها/سرویس‌ها/نودها |
| `info` · `paths` | خلاصه دامنه/گواهی · مسیر همه فایل‌ها |
| `doctor` | ۶ چک سلامت؛ **شکست → exit غیرصفر** (مناسب cron) |
| `restart` · `enable` | ری‌استارت/فعال‌سازی rathole-server (لحظه‌ای تونل‌ها قطع می‌شوند) |
| `version` | نسخه manager + rathole |
| `menu` | منوی تعاملی |

### نودها

| دستور | کار |
| :--- | :--- |
| `add <name> <inbound> [--api-port N]` | نود جدید (پورت داده خودکار از استخر) |
| `rm <name>` · `show <name>` · `ls` | حذف / جزئیات+دستور نصب / فهرست |
| `edit <name> [--inbound N] [--api-port N\|off]` | ویرایش |
| `rename <old> <new>` | تغییر نام و مسیر |
| `rotate <name>` | چرخش توکن — **بعدش سمت نود: `ratholenode add-svc <name> <TOKEN> <port>`** |
| `token <name>` | چاپ دستور نصب curl + install-node.sh |

### دامنه و گواهی

| دستور | کار |
| :--- | :--- |
| `cert <domain> [email]` | گواهی Let's Encrypt (standalone) + تغییر دامنه اصلی |
| `ip-cert <IPv4> [days]` | گواهی self-signed با SAN=IP برای نصب‌های بدون دامنه |
| `ip-cert-show` / `ip-cert-off` | نمایش public cert / خاموش‌کردن vhost IP |
| `domain add <d> [--certbot --email E] [--fullchain F --key K]` · `domain primary` · `domain rm` · `domain ls` | دامنه‌های اضافه (SNI) |
| `set <key> <value>` | کلیدها: `domain, fullchain, key, nginx-conf, fake-port, sub-port, control-port, control-path, sub-path, hub-path` — هر تغییر regen + rollback در شکست |

### حالت‌های ترنسپورت (هر کدام روی نود معادل دارد — پایین را ببینید)

| دستور | کار |
| :--- | :--- |
| `kcp on [port] [balanced\|lossy\|aggressive]` / `off` / `status` / `show` | kcptun UDP+FEC (پورت 443/udp) — KEY چاپ می‌شود |
| `plain on [port]` / `off` / `status` / `show` | WebSocket بدون TLS روی پورت جدا (پیش‌فرض 8880) |
| `noise on [port]` / `off` / `node <name> on\|off` / `status` / `show` | Noise NK روی instans جدا (پیش‌فرض 2334) |
| `backhaul on [port] [transport] [profile] [mode]` / `off` / `node <name> on\|off` / `status` / `show` | هسته Backhaul SMUX؛ `mode=nginx_tls` (پیش‌فرض، پشت nginx/443) یا `direct_ip` |
| `direct on --port P --header H` / `off` / `status` | مسیریابی با هدر HTTP بدون TLS |
| `game add <name> <inbound> <sni>` / `rm` / `ls` / `show` / `cert <sni>` | سرویس گیم با SNI passthrough روی 443 (استریم L4) |

> تداخل پورت‌ها از ابتدا رد می‌شود (443، fake/sub/hub، و بین حالت‌ها)؛ bind ناموفق → rollback خودکار.

### وب و ابزار

| دستور | کار |
| :--- | :--- |
| `hub on [port]` / `off` / `status` | نصب/مدیریت RatholeHub (`/hub/`) — جزئیات: [Hub-Management](Hub-Management) |
| `proxy add <name> <http(s)://host:port>` / `rm` / `ls` | reverse-proxy غیرتونل روی همان 443 |
| `tune` | BBR + محدودیت‌های سیستم/nginx (sysctl: `/etc/sysctl.d/99-rathole-tune.conf`، بکاپ nginx.conf یک‌بار نوشته می‌شود) |
| `fakeweb start/stop/rm/status [port]` | سایت فیک ضدپروب |
| `logs [n] [--bundle]` | لاگ کامل با redact توکن/کلیدها؛ `--bundle` فایل .txt.gz |
| `backup [file]` / `restore <file>` | پشتیبان state (نودها/توکن‌ها) + بازگردانی با اعتبارسنجی schema/tar |
| `update [beta\|stable\|vX.Y.Z]` | به‌روزرسانی کامل (snapshot + health-check + rollback خودکار) |
| `control-path rotate` | تغییر مسیر مخفی کنترل — ⚠️ دوره گذار ندارد؛ نودها باید همزمان به‌روز شوند |

## ratholenode (روی نود خارج)

### پایه

| دستور | کار |
| :--- | :--- |
| `apply` | بازتولید client.toml + اعمال (hot-reload؛ شکست → exit غیرصفر) |
| `add-svc <name> <token> <inbound>` / `rm-svc <name>` / `ls` | سرویس‌ها روی تونل اصلی — **نام باید با نام نود در پنل یکی باشد** |
| `set <SERVER\|TLS_HOSTNAME\|TLS_TRUSTED_ROOT\|RATHOLE_VERSION> <v>` | تنظیمات پایه |
| `set-main <host:port> [tls_hostname] [trusted_root]` | تغییر اتمیک dial+SNI+trust (آرگومان خالی = حذف) |
| `check` | بررسی تداخل پورت با nginx نود |
| `tune` | BBR + محدودیت‌ها |
| `status [--json]` · `show` · `version` | وضعیت (حالت ترنسپورت، دیال) |
| `fakeweb start/stop/rm [port]` | وب فیک لوکال |

### ترنسپورت‌ها (قرینه پنل — profile/KEY باید دو طرف یکی باشد)

| دستور | کار |
| :--- | :--- |
| `kcp on <iran_ip:udp_port> <KEY> [profile]` / `off` / `status` | سوییچ به UDP+FEC |
| `plain on <iran_ip:port>` / `off` / `status` | بدون TLS |
| `noise on <iran_ip:port> <pubkey> [pattern]` / `off` / `status` | Noise NK |
| `backhaul on <domain\|host:port> <token> [wss\|wssmux\|ws\|wsmux] [profile]` / `off` / `status` | SMUX (دامنه → wss/wssmux؛ IP → هشدار عدم verify) |

### چند-سرور و نگهداری

| دستور | کار |
| :--- | :--- |
| `upstream add <id> <host:port> [tls_hostname]` / `add-svc <id> <name> <token> <inbound>` / `rm-svc` / `rm` / `apply` / `restart` / `ls` / `logs` / `status` | سرور ایران دوم/سوم با واحد `rathole-client@<id>` |
| `upstream kcp/plain/noise/ws <id> ...` | ترنسپورت مستقل برای هر upstream |
| `watchdog on [interval]` / `off` / `status` | ری‌استارت خودکار تونل گیرکرده (تایمر systemd) |
| `adaptive on [--interval N]` / `off` / `status` / `test` / `run` | سوییچ خودکار ws↔kcp بر اساس پروب (در حالت backhaul فقط مانیتور می‌کند) |
| `backup [file]` / `restore <file>` | پشتیبان node.env + services + upstreams (restore با اعتبارسنجی tar) |
| `migrate` | نقشه مهاجرت همه تونل‌ها به KCP |
| `logs [n]` / `logs all [n] [--bundle]` | لاگ کامل (توکن‌ها redact) |
| `update [beta\|stable\|vX]` | به‌روزرسانی از گیت‌هاب (install.sh با SHA256SUMS تأیید می‌شود) |

## قواعد ورودی (هر دو ابزار)

* نام نود/سرویس: `[A-Za-z0-9_-]` (۱-۴۰ کاراکتر) · توکن: `[A-Za-z0-9._=+/-]` · کلید kcp/backhaul: hex یا `[A-Za-z0-9._=+/ ]` (نام profile به‌عنوان کلید رد می‌شود)
* پورت: 1-65535 · دامنه/مسیر nginx: بدون متاکاراکتر · endpoint: `host:port` (host بدون اسلش/فاصله)
* بدون tty، همه پرامپت‌ها پیش‌فرض امن («نه») می‌گیرند و هرگز بی‌نهایت منتظر نمی‌مانند.
