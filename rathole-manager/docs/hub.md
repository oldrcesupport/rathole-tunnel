# ratholehub — پنل وب متمرکز (REST API + UI)

`ratholehub` پنل مدیریت چند-سروری است که با SSH (بدون agent روی سرورها) کار می‌کند — تک‌فایل Python 3 استاندارد، بدون pip. همه‌ی قابلیت‌های این سند روی جفت سرور واقعی تست شده‌اند (نسخه 1.8.9).

## نصب

```bash
sudo ratholectl hub on 2087
```

* اولین اجرا: `install-hub.sh` را اجرا می‌کند — کلید SSH هاب در `/etc/ratholehub/id_ed25519` ساخته می‌شود، رمز ادمین را **تعاملی از tty** می‌پرسد (بدون tty خطا می‌دهد)، config با **PBKDF2-HMAC-SHA256** نوشته می‌شود، سرویس `ratholehub` روی `127.0.0.1:2087` بالا می‌آید و بلوک nginx `/hub/` ساخته می‌شود.
* آدرس: `https://<دامنه>/hub/` — هاب هرگز مستقیم روی اینترنت گوش نمی‌دهد.
* اجرای مجدد نصب‌کننده، config موجود را دست نمی‌زند (توکن/رمز حفظ می‌شود).
* دسترسی بدون باز کردن پورت: `ssh -L 2087:127.0.0.1:2087 root@<panel>` → `http://localhost:2087`

## امنیت (رفتار واقعی)

| مورد | رفتار |
| :--- | :--- |
| رمز | PBKDF2-HMAC-SHA256، ۱۰۰k iteration + salt؛ هش‌های قدیمی sha256 در اولین ورود خودکار ارتقا می‌یابند |
| نشست | کوکی `rhsession` با `HttpOnly; SameSite=Strict` + `Secure` پشت TLS (نیازمند `X-Forwarded-Proto` — در بلوک nginx خودکار هست)؛ **تغییر رمز همه نشست‌ها را فوراً بی‌اعتبار می‌کند** |
| توکن API | `Authorization: Bearer <api_token>` — بدون انقضا؛ فقط با rotate باطل می‌شود |
| محدودیت ورود | ۵ تلاش در ۳۰۰ ثانیه per-IP، اتمیک (مقاوم به درخواست‌های همزمان) → 429 |
| هدرها | `X-Frame-Options: DENY` + `CSP frame-ancestors 'none'` + `nosniff` |
| لاگ ممیزی | `/etc/ratholehub/audit.log` (0600) — همه‌ی عملیات نوشتاری + add/delete سرور؛ دستورها redact می‌شوند |
| اتصال به سرورها | فقط با کلید SSH هاب (بدون رمز)؛ `ssh_opts` با whitelist اعتبارسنجی می‌شود (ProxyCommand/LocalCommand/... ممنوع) |

> توکن API از `/api/login` هم برگردانده می‌شود و UI آن را در localStorage نگه می‌دارد — در مرورگر اشتراکی بعد از کار Logout کنید و در صورت تردید rotate بزنید.

## استفاده از UI

* **Servers:** افزودن دستی (`role: iran/node`)، ویرایش، حذف — همه با audit.
* **Provision (نصب خودکار):** `host` + `ssh_user` + `ssh_port` + رمز SSH → هاب با sshpass کلید خودش را نصب می‌کند، اسکریپت‌ها را deploy می‌کند (دانلود از ریلیز با تأیید checksum) و سرور را ثبت می‌کند. برای نود، ابتدا یک سرور با `role=iran` باید ثبت باشد.
* **صفحه سرور:** overview زنده (نسخه manager/rathole، سرویس‌ها، doctor)، اکشن‌ها: show/status/restart/logs/update(deploy)/regen + سوییچ kcp/plain/noise/backhaul + watchdog/adaptive/fakeweb/proxy/game + upstream.
* **Routing:** نمای گرافیکی مسیرها؛ **Audit:** لاگ عملیات؛ **Settings:** تغییر رمز (نشست‌ها را می‌بندد)، rotate توکن، ssh_opts، مسیر کلید.

## REST API

همه‌ی مسیرها با `/hub/api/...` (پشت nginx) یا بدون پیشوند روی loopback. احراز: کوکی نشست یا `Authorization: Bearer`.

| متد و مسیر | کار |
| :--- | :--- |
| `POST /api/login` `{password}` | ورود → توکن + کوکی (429 بعد از ۵ خطا) |
| `GET /api/health` | سلامت (بدون احراز) |
| `GET /api/servers` | فهرست inventory |
| `POST /api/servers` `{name,role,host,ssh_user,ssh_port}` | افزودن (409 نام تکراری، 400 ورودی نامعتبر) |
| `PUT /api/servers/<name>` | ویرایش host/user/port |
| `DELETE /api/servers/<name>` | حذف (404 اگر نباشد) — همه با audit |
| `POST /api/provision` `{name,role,host,ssh_user,ssh_port,ssh_password}` | نصب خودکار کامل |
| `GET /api/servers/<n>/overview` / `/details` | وضعیت زنده (نسخه، سرویس‌ها، doctor) |
| `POST /api/servers/<n>/action` `{action,args}` | اجرای اکشن whitelist-شده |
| `GET /api/audit?limit=N` | لاگ ممیزی |
| `GET /api/config` / `POST /api/config` | نمایش امن / تغییر رمز (`current_password`,`new_password`) و `rotate_token` |
| `GET /api/hubstatus` | نسخه هاب و آخرین ریلیز |

اکشن‌های مجاز (نمونه): `show, ls, status, restart, logs, doctor(پنل), regen_full, backup, paths, add_node, rm_node, edit_node, rename_node, rotate_node, set_config, kcp_on/off/status, plain_on/off, noise_on/off/node_on/node_off, backhaul_on/off/node_on/node_off/show, direct_on/off, proxy_add/ls/rm, game_add/ls/rm, fakeweb_*, watchdog_*, adaptive_*, upstream_*, deploy, tune, migrate`. اکشن نامعتبر یا نام موجود نیست → خطای صریح؛ خروجی هر اکشن `rc` دارد و UI آن را نشان می‌دهد.

## نکات عملی (تست‌شده)

* **نصب روی سروری که پورت 22 آن از بیرون فیلتر است:** هاب از داخل سرور به `127.0.0.1` هم می‌تواند SSH بزند — host سرور خودِ پنل را در inventory با `PUT /api/servers/<n> {"host":"127.0.0.1"}` تغییر دهید تا اکشن‌ها از مسیر loopback اجرا شوند.
* `deploy` (update از گیت‌هاب) ممکن است چند دقیقه طول بکشد (mirrorها) — پاسخ را با `overview` دنبال کنید.
* تغییر مسیر هاب: `sudo ratholectl set hub-path <seg>` + `hub on <port>`.
* خاموش کردن: `sudo ratholectl hub off` (سرویس و credentialها حفظ می‌شوند؛ حذف کامل با `bootstrap.sh --purge`).
