<div align="center">

<img src="assets/logo.svg" alt="rathole-tunnel" width="110" height="110" />

# نصب کامل — rathole-tunnel

**پنل ایران + نودهای خارج + هاب مرکزی** — نسخه 1.8.9

_همه‌ی دستورها و سناریوها روی جفت سرور واقعی (Ubuntu 24.04) اجرا و تأیید شده‌اند._

[**English**](install-manual.md) · [مرجع CLI](wiki/CLI-Reference.md) · [پنل وب هاب](hub.md)

</div>

<div dir="rtl">

## ۱. پیش‌نیازها

| نیاز | مقدار |
| :--- | :--- |
| سیستم‌عامل | Ubuntu 20.04+ / Debian 11+ — معماری x86_64 یا arm64 |
| دسترسی | root |
| پنل ایران | پورت‌های آزاد: `443/tcp` (+ `443/udp` برای KCP، `2334/tcp` برای Noise، پورت plain/direct در صورت استفاده) |
| نود خارج | inbound لوکال برای هر سرویس (مثلاً `2087`) + خروجی HTTPS به پنل |
| دامنه (اختیاری) | رکورد A به IP پنل + گواهی fullchain/privkey، یا certbot |

بسته‌ها (`nginx jq curl unzip openssl python3 certbot sshpass`) خودکار نصب می‌شوند. باینری rathole از خود بسته با تأیید `core/SHA256SUMS` نصب می‌شود.

### جدول پورت‌ها

| سرور | پورت | دسترسی | کاربرد |
| :--- | :--- | :--- | :--- |
| ایران | 443/tcp | عمومی | nginx TLS — کانترول (مسیر مخفی `/_rh/…`)، مسیر نودها `/<name>`، هاب `/hub/`، proxy |
| ایران | 443/udp | عمومی | فقط حالت KCP |
| ایران | 2334/tcp | عمومی | فقط حالت Noise |
| ایران | 8880/8090… | عمومی | فقط حالت plain/direct |
| ایران | 2333 / 8080 / 2096 / 1001+ / 8088 | فقط 127.0.0.1 | کنترل / سایت فیک / subscription / داده / هاب (عمداً لوکال) |
| خارج | 2087+ | فقط 127.0.0.1 | inbound سرویس‌ها (Xray/3x-ui) |

## ۲. نصب پنل (سرور ایران)

**تک‌خطی دامنه‌دار:**

```bash
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel \
  --domain panel.example.ir \
  --fullchain /root/cert/panel.example.ir/fullchain.pem \
  --key /root/cert/panel.example.ir/privkey.pem
```

**تعاملی:** `... | sudo bash -s -- --panel` (دامنه/گواهی/پورت‌ها پرسیده می‌شود؛ بدون tty از حالت تعاملی خارج و راهنما می‌دهد).

**فقط IP:** نصب با IP به‌جای دامنه، سپس:

```bash
sudo ratholectl ip-cert <IPv4>     # گواهی self-signed با SAN=IP + سوییچ vhost
sudo ratholectl ip-cert-show       # public cert برای trust روی نود
```

**گواهی با certbot:** `sudo ratholectl cert panel.example.ir admin@example.ir`
**گواهی از جای دیگر:** `sudo ratholectl set fullchain <fc>` / `set key <k>` / `set domain <d>`

نصب به‌ترتیب: پیش‌نیازها → باینری rathole (checksum) → ratholectl/common.sh → واحد systemd → nginx + map websocket → init (state، server.toml، rathole.conf) → reload nginx → start/enable سرویس → سایت فیک. **هر شکست (مثل nginx -t یا bind پورت) rollback می‌شود**؛ از v1.8.9 bind واقعی listenerها هم با `ss` راستی‌آزمایی می‌شود.

## ۳. نصب نود (سرور خارج)

```bash
# روی پنل:
sudo ratholectl add trk01 2087 && sudo ratholectl token trk01

# روی نود — دامنه‌دار (تأیید گواهی با CA سیستم):
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --node -- \
  --server panel.example.ir:443 --name trk01 --token <TOKEN> --inbound-port 2087

# حالت IP (self-signed پنل):
#   --server 213.0.113.10:443 --tls-hostname 213.0.113.10 --tls-trusted-root /root/panel-ip.pem
```

قواعد: نام `[A-Za-z0-9_-]`، توکن `[A-Za-z0-9._=+/-]`، پورت 1-65535. اجرای مجدد، قبل از بازنویسی backup می‌گیرد و تونل را به ws برمی‌گرداند (هشدار چاپ می‌شود).

سپس inbound واقعی (VLESS+WS در 3x-ui): `listen=127.0.0.1`، `port=2087`، `path=/trk01`، TLS خاموش.

بررسی: `ratholenode status` (نود) و `sudo ratholectl doctor` (پنل) — «node … amade ast» یعنی اتصال برقرار است.

سرویس بیشتر روی همان تونل: پنل `sudo ratholectl add trk02 2088` → نود `ratholenode add-svc trk02 <TOKEN> 2088`.

## ۴. به‌روزرسانی / Rollback / حذف

```bash
sudo ratholectl update stable        # پنل (یا beta / vX.Y.Z)
ratholenode update stable            # نود — دانلود install.sh با SHA256SUMS ریلیز تأیید می‌شود
sudo bash /opt/rathole-manager/update.sh --list-backups
sudo bash /opt/rathole-manager/update.sh --rollback [timestamp]
sudo bash /opt/rathole-manager/bootstrap.sh --uninstall     # حذف کامل (با تأیید)
sudo bash /opt/rathole-manager/bootstrap.sh --purge --yes   # + باینری/کانفیگ هاب
```

قبل از هر update، snapshot کامل از CLI + config + unitها گرفته می‌شود؛ شکست health-check → rollback خودکار. گارد downgrade جلوی برگشت ناخواسته از beta را می‌گیرد (`--allow-downgrade` برای اجبار).

## ۵. هاب (پنل وب) — خلاصه

```bash
sudo ratholectl hub on 2087     # نصب خودکار در اولین اجرا → https://<دامنه>/hub/
```

ورود با رمز ادمین (PBKDF2)، مدیریت سرورها + audit، provision خودکار با رمز SSH، اکشن‌ها، rotate توکن. مستند کامل: [`hub.md`](hub.md)

## ۶. عیب‌یابی سریع

| نشانه | علت / راه‌حل |
| :--- | :--- |
| doctor: node port listen نمی‌شود | نود قطع است یا توکن عوض شده — بعد از rotate: `ratholenode add-svc <name> <TOKEN> <port>` |
| `Service not exist` در journal نود | نام سرویس نود باید **دقیقاً** برابر نام نود در پنل باشد |
| `bind() failed` | تداخل پورت — پورت دیگر؛ از v1.8.9 تغییرات rollback می‌شوند |
| قفل 30 ثانیه‌ای | عملیات همزمان — کمی بعد تکرار کنید |
| بسته لاگ برای پشتیبانی | `sudo ratholectl logs 200 --bundle` (توکن‌ها redact شده‌اند) |

بیشتر: [`wiki/Troubleshooting.md`](wiki/Troubleshooting.md)

</div>
