# 🚀 Rathole Tunnel Manager (سامانه تانل معکوس ضدتحریم و گیمینگ)

مدیریت جامع و ماژولار تانل معکوس پایدار بین **سرور ایران (Panel)** و **سرور خارج (Node)** با هسته [rathole](https://github.com/rapiz1/rathole)، nginx با دفاع فعال ضدپروب، و پنل وب **RatholeHub**. تمام دستورها و سناریوهای این مستند روی جفت سرور واقعی (Ubuntu 24.04) تست شده‌اند.

**نسخه فعلی:** v1.8.9 — [دانلود آخرین ریلیز](https://github.com/oldrcesupport/rathole-tunnel/releases/latest)

---

## 📚 فهرست مستندات

| راهنما | فایل | محتوا |
| :--- | :--- | :--- |
| 📖 **راهنمای نصب کامل (دستی + گیت‌هاب)** | [`docs/install-manual.fa.md`](rathole-manager/docs/install-manual.fa.md) | نصب گام‌به‌گام، جریان دامنه و IP، جدول پورت‌ها |
| 🌐 **راهنمای هاب (پنل وب)** | [`docs/hub.md`](rathole-manager/docs/hub.md) | نصب، API، provision خودکار، امنیت |
| 🖥️ **ویکی** | [`docs/wiki/Home.md`](rathole-manager/docs/wiki/Home.md) | مرجع CLI، عیب‌یابی، گردش‌کارها |
| 🏗️ **معماری و ترانزیت** | [`docs/architecture.md`](rathole-manager/docs/architecture.md) | دیاگرام، جریان ترافیک، حالت‌های ترنسپورت |

---

## ⚡ نصب سریع تک‌خطی

### ۱) سرور ایران (Panel)

```bash
# با دامنه و گواهی موجود:
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel \
  --domain panel.example.ir \
  --fullchain /root/cert/panel.example.ir/fullchain.pem \
  --key /root/cert/panel.example.ir/privkey.pem

# یا تعاملی (بدون آرگومان — دامنه/گواهی را می‌پرسد):
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel
```

**سرور بدون دامنه (فقط IP):** نصب را با همان IP به‌جای دامنه انجام دهید و بعد از نصب گواهی self-signed اختصاصی بسازید:

```bash
sudo ratholectl ip-cert 213.0.113.10        # گواهی IP-SAN می‌سازد و vhost را سوییچ می‌کند
sudo ratholectl ip-cert-show               # مسیر public cert برای trust روی نود
```

**گواهی با certbot (دامنه → این سرور):**

```bash
sudo ratholectl cert panel.example.ir admin@example.ir
```

پنل وب (اختیاری، روی همان دامنه زیر `/hub/`):

```bash
sudo ratholectl hub on 2087      # ← https://panel.example.ir/hub/
sudo ratholectl tune             # BBR + محدودیت‌های سیستم (رفع 502 زیر burst)
```

### ۲) سرور خارج (Node)

روی پنل یک نود بسازید و دستور نصب نود را بگیرید:

```bash
sudo ratholectl add trk01 2087        # 2087 = پورت inbound (مثلاً Xray/3x-ui روی نود)
sudo ratholectl token trk01           # دستور آماده‌ی نصب + توکن
```

روی سرور خارج دستور چاپ‌شده را اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --node -- \
  --server panel.example.ir:443 --name trk01 --token <TOKEN> --inbound-port 2087
```

* نود با `--tls-hostname <دامنه>` گواهی پنل را با CA سیستم تأیید می‌کند (مسیر استاندارد دامنه‌دار).
* در حالت IP: `--tls-hostname <IP-پنل> --tls-trusted-root /path/to/ip-cert.pem`
* سپس روی نود، inbound واقعی (مثلاً VLESS-WS در 3x-ui) را روی `127.0.0.1:2087` با `path=/trk01` بسازید.

### ۳) بررسی سلامت

```bash
sudo ratholectl doctor     # سرویس‌ها، پورت‌ها، اتصال نود، پروب کنترل — در شکست exit غیرصفر
sudo ratholectl status     # داشبورد کامل
ratholenode status         # وضعیت تونل از سمت نود
```

---

## 🛠️ دستورات پرکاربرد

```bash
# ── پنل (ratholectl) ──
sudo ratholectl ls                          # فهرست نودها
sudo ratholectl add node2 10002             # نود جدید (پورت داده به‌صورت خودکار)
sudo ratholectl token node2                 # دستور نصب نود + توکن
sudo ratholectl rotate node2                # چرخش توکن (بعدش توکن سمت نود را به‌روز کنید)
sudo ratholectl rename trk01 trk99          # تغییر نام/مسیر
sudo ratholectl regen                       # بازتولید کانفیگ‌ها + reload
sudo ratholectl logs 200 --bundle           # بسته لاگ کامل با redact توکن‌ها (امن برای پشتیبانی)

# ── حالت‌های ترنسپورت (روی پنل + معادل روی نود) ──
sudo ratholectl kcp on 443 balanced         # UDP+FEC شبیه QUIC — نود: ratholenode kcp on <iran-ip>:443 <KEY>
sudo ratholectl noise on                    # Noise رمزنگاری‌شده بدون TLS/cert — نود: ratholenode noise on <ip>:2334 <pubkey>
sudo ratholectl backhaul on                 # هسته Backhaul/SMUX پشت nginx/443 — نود: ratholenode backhaul on <domain> <TOKEN>
sudo ratholectl plain on 8880               # WebSocket بدون TLS روی پورت جدا — نود: ratholenode plain on <ip>:8880
sudo ratholectl direct on --port 8090 --header X-Cdn-Id   # مسیریابی هدر (بدون TLS)

# هر سوییچ، snapshot می‌گیرد؛ در شکست خودکار rollback می‌شود.

# ── نود (ratholenode) ──
ratholenode ls                              # سرویس‌های همین تونل
ratholenode add-svc trk01 <TOKEN> 2087      # سرویس جدید روی همان تونل
ratholenode set-main <host:443> [tls_hostname] [trusted_root]
ratholenode upstream add up2 <host:443> [tls_hostname]   # سرور ایران دوم/سوم
ratholenode logs all 200 --bundle           # بسته لاگ نود (redact شده)
ratholenode backup / restore                # پشتیبان‌گیری/بازیابی تنظیمات نود
```

---

## 🌐 پنل وب RatholeHub

```bash
sudo ratholectl hub on 2087
```

* آدرس: `https://<دامنه>/hub/` — فقط روی `127.0.0.1` گوش می‌دهد و پشت nginx با TLS قرار می‌گیرد.
* ورود با رمز ادمین (PBKDF2-HMAC-SHA256)؛ کوکی `HttpOnly; SameSite=Strict` و پشت TLS با `Secure`.
* مدیریت سرورها (افزودن/ویرایش/حذف + audit)، **provision خودکار** با رمز SSH (نصب کلید هاب + دیپلوی)، اکشن‌ها (show/restart/regen/logs/سوییچ ترنسپورت/...)، چرخش توکن، تغییر رمز (نشست‌های قبلی را بی‌اعتبار می‌کند).
* جزئیات کامل: [`docs/hub.md`](rathole-manager/docs/hub.md)

---

## 🔄 به‌روزرسانی و Rollback

```bash
# پنل یا نود — از هر نسخه‌ای:
sudo ratholectl update stable          # یا: ratholenode update stable
sudo ratholectl update v1.8.9          # نسخه مشخص
sudo ratholectl update beta            # آخرین pre-release

# قبل از هر به‌روزرسانی snapshot کامل گرفته می‌شود؛ اگر health-check شکست بخورد
# خودکار rollback می‌شود. بازگردانی دستی:
sudo bash /opt/rathole-manager/update.sh --list-backups
sudo bash /opt/rathole-manager/update.sh --rollback [timestamp]
```

حذف کامل: `sudo bash /opt/rathole-manager/bootstrap.sh --uninstall` (و `--purge` برای حذف باینری/کانفیگ هاب).

---

## 📋 پورت‌ها و پیش‌نیازها

| سرور | پورت | جهت | کاربرد |
| :--- | :--- | :--- | :--- |
| ایران | 443/tcp | عمومی | nginx TLS (کنترل + داده ws + هاب `/hub/` + proxy) |
| ایران | 443/udp | عمومی | فقط در حالت KCP (kcptun) |
| ایران | 2334/tcp | عمومی | فقط در حالت Noise |
| ایران | 8880, 8090... | عمومی | فقط در حالت plain/direct |
| ایران | 2333, 8080, 2096, 1001+، 8088 | فقط 127.0.0.1 | کنترل/فیک/ساب/داده/هاب — عمداً لوکال است |
| خارج | 2087+ | فقط 127.0.0.1 | inbound های سرویس‌ها (Xray/3x-ui) |
| خارج | خروجی HTTPS | — | اتصال به پنل (+ دانلود آپدیت) |

پیش‌نیاز: Ubuntu 20.04+ / Debian 11+ (x86_64 یا arm64)، دسترسی root. بسته‌های nginx/jq/certbot به‌صورت خودکار نصب می‌شوند؛ باینری rathole از بسته (با تأیید checksum) نصب می‌شود.

---

## 🛡️ ویژگی‌های امنیتی (تست‌شده)

* رمزهای عبور با **PBKDF2-HMAC-SHA256** (۱۰۰k iteration + salt) — ارتقای خودکار از هش‌های قدیمی در اولین ورود.
* کوکی نشست: `HttpOnly; SameSite=Strict` + `Secure` پشت TLS؛ HMAC نشست به رمز گره خورده — **تغییر رمز همه نشست‌ها را بی‌اعتبار می‌کند**.
* محدودیت ورود: ۵ تلاش ناموفق در ۳۰۰ ثانیه per-IP (اتمیک، مقاوم به race) → 429.
* `umask 077` + فایل‌های state/token با `0600`؛ نوشتن اتمیک کانفیگ‌ها با قفل + rollback.
* اعتبارسنجی سخت‌گیرانه ورودی‌ها (نام، توکن hex، پورت 1-65535، دامنه/مسیر بدون متاکاراکتر nginx) و آرشیوهای tar/zip ضد path-traversal/symlink.
* redaction کامل توکن/کلید در `logs` و `logs --bundle` (شامل کلید خصوصی Noise و کلید kcptun).
* دفاع ضدپروب: بازدیدکننده عادی و اسکنر به‌جای 502، صفحه‌ی شرکتی `200 OK` می‌بینند.

## ⚠️ محدودیت‌های شناخته‌شده

* listener اصلی 443 فقط IPv4 است (plain/direct دو-استک‌اند).
* `control-path rotate` دوره گذار ندارد — بعد از rotate باید نودها را به‌روز کنید.
* توکن API هاب (Bearer) تاریخ انقضا ندارد؛ فقط با rotate باطل می‌شود. کوکی نشست ۲۴ ساعته است.
* پورت‌های داده روی پنل فقط `127.0.0.1` هستند (عمدی) — مصرف بیرونی فقط از مسیر nginx/443.
* دانلود از mirrorهای ghproxy (برای دورزدن فیلترینگ) same-origin است؛ checksum ریلیز در مسیر آپدیت راستی‌آزمایی می‌شود ولی امضای PGP وجود ندارد.

## 🧾 مجوزها

هسته rathole و kcptun/backhaul مجوزهای پروژه‌های خود را دارند؛ کد مدیریت تحت مجوز پروژه — [`rathole-manager/LICENSE`](rathole-manager/LICENSE) و [`rathole-manager/NOTICE`](rathole-manager/NOTICE).
