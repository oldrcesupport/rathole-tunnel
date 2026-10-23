# عیب‌یابی، بک‌آپ و رول‌بک

---

## اولین ابزار: doctor

```bash
sudo ratholectl doctor       # پنل — ۶ چک؛ شکست → exit غیرصفر (مناسب مانیتورینگ)
ratholenode status           # نود — حالت ترنسپورت و دیال
sudo ratholectl logs 200 --bundle    # بسته لاگ کامل با redact توکن‌ها (برای پشتیبانی)
ratholenode logs all 200 --bundle    # معادل سمت نود
```

## خطاهای واقعی و راه‌حل

| نشانه | علت | راه‌حل |
| :--- | :--- | :--- |
| doctor: `node X rooye port N gvsh nmidhd` | نود قطع است، token عوض شده، یا پورت فیلتر است | `ratholenode status` روی نود؛ بعد از rotate: `ratholenode add-svc <name> <TOKEN-جدید> <port>` |
| journal نود: `Service not exist` | نام سرویس نود ≠ نام نود در پنل (rathole با نام match می‌کند) یا توکن قدیمی | نام را دقیقاً برابر نام نود بگذارید؛ توکن را sync کنید |
| journal نود: `Connection refused` به پنل | listener پنل بالا نیست (پورت فیلتر/تداخل) | `sudo ratholectl doctor` + `ss -ltnp` روی پنل؛ پورت مورد نظر را باز کنید |
| `bind() failed (Address already in use)` در nginx error.log | تداخل پورت (مثلاً plain روی fake_port) | از v1.8.9 تغییرات خودکار rollback می‌شوند و پورت متضاد رد می‌شود؛ دستی: پورت دیگر |
| «reload shod» ولی رفتار قدیمی | نسخه‌های قدیمی‌تر — nginx در شکست bind کد ۰ می‌دهد | به v1.8.9+ به‌روز شوید (bind-verification) |
| `ghofl-e state azad nashod (flock timeout 30s)` | عملیات همزمان دیگر | چند ثانیه صبر و تکرار؛ اگر تکرار شد: `ps aux | grep ratholectl` |
| probe → 200 به‌جای 101 | درخواست control بدون هدر Upgrade درست نیست | طبیعی است — doctor خودش با هدرهای WS می‌زند؛ 101 روی مسیر `/_rh/…` = سالم |
| صفحه اصلی 502 | fakeweb پایین است | `sudo ratholectl fakeweb start` |
| `ratholectl noise on` از پنل و `Authentication failed: Service not exist` روی نود | نود هنوز در noise-server ثبت نشده | پنل: `sudo ratholectl noise node <name> on` |
| adaptive تونل سالم را سوییچ می‌کند | پروب به host اشتباه (نسخه‌های قدیمی) | به 1.8.9+ به‌روز شوید (probe از remote درست می‌خواند) |
| نصب hub: «ramz khali» یا رمز ذخیره‌شده کار نمی‌کند | اجرا بدون tty واقعی | `sudo bash /opt/rathole-manager/ratholehub/install-hub.sh` را در یک ترمینال واقعی اجرا کنید |
| update: `DOWNGRADE mahdood` | برگشت از beta/latest | عمدی است؛ اجبار: `--allow-downgrade` |

## بک‌آپ

```bash
# پنل — state (نودها/توکن‌ها/دامنه):
sudo ratholectl backup /root/panel-backup.tar.gz
# نود — node.env + services + upstreams:
ratholenode backup /root/node-backup.tar.gz
# هر update خودش snapshot کامل می‌گیرد: /var/backups/rathole-manager/pre-update-*
```

گواهی‌ها در backup نیستند — مسیرشان در state است؛ خود فایل‌ها را جدا نگه دارید.

## رول‌بک

```bash
sudo bash /opt/rathole-manager/update.sh --list-backups
sudo bash /opt/rathole-manager/update.sh --rollback              # آخرین snapshot
sudo bash /opt/rathole-manager/update.sh --rollback 20261024-103000
```

* rollback فایل‌ها را بازمی‌گرداند، daemon-reload و سرویس‌ها را restart می‌کند و health-check می‌گیرد.
* اگر update خودش health-check را رد کرد، قبل از این‌که ببینید **خودش rollback کرده** — لاگ را بخوانید؛ دوباره دستی rollback نزنید.
* restore هر دو طرف، فایل‌های tar را با بررسی path-traversal/symlink می‌پذیرد (fail-closed).

## ریست کامل (آخرین راه)

```bash
sudo bash /opt/rathole-manager/bootstrap.sh --purge --yes   # حذف همه (با احتیاط!)
# سپس نصب مجدد طبق Getting-Started؛ state را از backup برگردانید:
sudo ratholectl restore /root/panel-backup.tar.gz
```
