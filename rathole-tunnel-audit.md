# گزارش ممیزی ایستا و باگ‌یابی Rathole Tunnel Manager

**مخزن:** `oldrcesupport/rathole-tunnel`  
**شاخه بررسی‌شده:** `main`  
**Commit بررسی‌شده:** `50420e86b9b1bfe4ce4636f921449f94f4103f86`  
**تاریخ بررسی:** 2026-10-22  
**نوع بررسی:** بازبینی استاتیک کد و جریان‌های نصب، مدیریت، به‌روزرسانی، پنل و تست‌ها. اجرای integration روی دو سرور واقعی انجام نشده است؛ مواردی که بازتولید runtime می‌خواهند جدا علامت‌گذاری شده‌اند.

## خلاصه مدیریتی

مهم‌ترین خطرها به‌ترتیب اولویت:

1. **افشای اطلاعات محرمانه با مجوز فایل‌های پیش‌فرض:** state، فایل‌های TOML، audit log، فایل‌های systemd مربوط به KCP و snapshotهای update ممکن است با مجوز خواندن عمومی ساخته شوند. این فایل‌ها می‌توانند token و کلید تونل را در خود داشته باشند.
2. **ثبت secret در audit log و گزینه SSH ناامن:** پنل فرمان نهایی را با آرگومان‌هایش ثبت می‌کند و گزینه‌های SSH را بدون allowlist می‌پذیرد. `ProxyCommand` یا گزینه‌های مشابه، با دسترسی API می‌توانند به اجرای فرمان محلی با دسترسی سرویس پنل منجر شوند.
3. **گزارش موفقیت کاذب:** بعضی نصب‌ها و عملیات CLI با وجود fail شدن سرویس یا write/restart، موفقیت اعلام می‌کنند.
4. **خراب‌شدن/از دست رفتن تنظیمات:** `ratholectl init` مستقیماً state را truncate می‌کند و بازنویسی می‌کند؛ چند mutation نیز خطای `jq`/`mv` را بررسی نمی‌کنند.
5. **به‌روزرسانی آنلاین فعلاً مسدود است:** در لحظه بررسی GitHub Releaseای منتشر نشده، اما `install.sh`، deploy پنل و update راه دور از Release assetها دانلود می‌کنند.
6. **race condition:** در چند نقطه بعد از timeout گرفتن lock، عملیات بدون قفل ادامه می‌یابد؛ writerها و restart می‌توانند state/config نیمه‌نوشته ببینند.
7. **adaptive monitoring قابل اتکا نیست:** probe مربوط به KCP فقط listener محلی را بررسی می‌کند؛ پارامترهای recovery/cooldown در منطق تصمیم‌گیری عملاً استفاده نمی‌شوند؛ probe TLS/WebSocket هم به تست رگرسیون نیاز دارد.
8. **تست‌ها و CI برای کشف این موارد کافی نیستند:** harness بیشتر شبیه‌سازی دارد و خروجی FAIL لزوماً به exit code ناموفق تبدیل نمی‌شود؛ workflow آشکار CI/release در مخزن دیده نشد.

---

## یافته‌های P0: امنیت و مسدودکننده‌های اصلی

### P0-01 — فایل‌های state و TOML حاوی token ممکن است world-readable باشند

**شواهد:**
- [`ratholectl`](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholectl): `cmd_init`، حدود خطوط 254 تا 267، فایل `STATE=/etc/rathole-manager/state.json` را با `jq -n ... > "$STATE"` می‌سازد. فایل حاوی node tokenها و API tokenهاست؛ در اسکریپت `umask 077` سراسری یا chmod محدودکننده بعد از این نوشتن مشاهده نشد.
- [`common.sh`](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/common.sh): `rth_commit_config` حدود خطوط 98 تا 124 فایل مقصد را با `cat "$src" > "$dst"` می‌نویسد و mode را محدود نمی‌کند. این مسیر برای `server.toml`، `client.toml` و configهای دیگر استفاده می‌شود که token سرویس‌ها را در خود دارند.
- [`ratholenode`](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholenode): سازنده‌های KCP، کلید را مستقیماً در `ExecStart=... -key ...` فایل unit قرار می‌دهند؛ فایل‌های unit با مجوز پیش‌فرض می‌توانند برای کاربران محلی خواندنی باشند.

**اثر:** روی سیستم‌هایی با umask متداول `022`، فایل تازه‌ساخته‌شده معمولاً `0644` می‌شود. کاربر محلی غیر root می‌تواند tokenها یا کلید KCP را بخواند و از آن‌ها برای دسترسی به سرویس‌های تونل استفاده کند. mode دقیق به umask و وضعیت فایل قبلی بستگی دارد، بنابراین باید در تست نصب اندازه‌گیری شود، نه فرض.

**اصلاح لازم:**
- در همه entrypointهای privileged، `umask 077` را زود تنظیم کنید.
- مجوز فایل‌های محرمانه را صریحاً `0600` و دایرکتوری‌های خصوصی را `0700` کنید؛ فقط به umask محیط تکیه نکنید.
- فایل موقت را هم با مجوز امن ایجاد کنید، نه اینکه ابتدا عمومی بسازید و بعد chmod کنید.
- ترجیحاً کلید KCP را از command line داخل unit خارج کنید و از فایل تنظیمات جداگانه با mode `0600` یا سازوکار امن‌تر استفاده کنید.
- تست نصب fresh باید `stat -c '%a %n'` تمام فایل‌های حساس را بررسی کند.

### P0-02 — audit log هم secret ذخیره می‌کند و هم mode امن تضمین‌شده ندارد

**شواهد:** [`hub.py`](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholehub/hub.py)، حدود خطوط 117 تا 160 و 1150 تا 1165:
- `audit_log()` مقدار `cmd` را بدون redaction به JSON اضافه می‌کند.
- `_action()` مقدار `" ".join(cmd)` را برای عملیات نوشتنی log می‌کند.
- `AUDIT_PATH` پیش‌فرض `/etc/ratholehub/audit.log` است؛ هنگام append نه chmod محدودکننده اعمال می‌شود و نه `UMask=0077` در unit پنل تنظیم شده است.

فرمان‌هایی مثل `ratholenode add-svc`, `backhaul on` یا عملیات KCP می‌توانند token یا key را در آرگومان داشته باشند.

**اثر:** secret ممکن است هم در audit API و هم برای کاربران محلی که بتوانند فایل را بخوانند افشا شود. حتی اگر UI فعلاً ستون `cmd` را نشان ندهد، محتوا در فایل ذخیره شده است.

**اصلاح لازم:** فقط نام action و فیلدهای غیرحساس را log کنید؛ آرگومان‌های secret-bearing را با schema-aware redaction حذف کنید، نه regex عمومی و شکننده. فایل log را هنگام ایجاد `0600` کنید، `UMask=0077` در systemd بگذارید و rotation امن تنظیم کنید. یک تست باید token آزمایشی را در درخواست بفرستد و اثبات کند token نه در فایل و نه در endpoint audit دیده می‌شود. همچنین `audit_log()` اکنون exceptionها را کاملاً با `pass` می‌بلعد؛ خطای audit نباید درخواست اصلی را خراب کند، اما باید در journald/metrics قابل تشخیص باشد.

### P0-03 — تنظیم `ssh_opts` اجازه گزینه‌های قابل اجرای SSH را بدون allowlist می‌دهد

**شواهد:** `hub.py`، تابع `_config_save()` حدود خطوط 1039 تا 1076، ورودی `ssh_opts` را صرفاً به `list[str]` محدود می‌کند؛ سپس `_ssh_base()` همان گزینه‌ها را مستقیماً به subprocess محلی `ssh` می‌دهد (حدود خطوط 252 تا 260). سرویس systemd نصب پنل `User=` محدودکننده ندارد و به‌طور پیش‌فرض با کاربر root اجرا می‌شود.

**اثر:** یک API token معتبر که اجازه تغییر config دارد می‌تواند optionهایی مثل `-o ProxyCommand=...` یا گزینه‌های مشابه را وارد کند. OpenSSH بعضی از این گزینه‌ها را از طریق shell/فرمان محلی اجرا می‌کند؛ در نتیجه نشت/سرقت token می‌تواند ریسک اجرای فرمان روی خود سرور Hub را به وجود آورد، نه فقط سرور راه دور.

**اصلاح لازم:** `ssh_opts` آزاد را حذف کنید یا به allowlist کوچک و typed تبدیل کنید. گزینه‌های `ProxyCommand`, `LocalCommand`, `PermitLocalCommand`, فایل config دلخواه `-F` و گزینه‌های مشابه باید رد شوند. گزینه‌های ثابت و ضروری را در کد تعریف کنید. تا حد امکان سرویس پنل را با یک user اختصاصی و دسترسی محدود اجرا کنید؛ دسترسی SSH به کلیدها و bundle را جداگانه محدود کنید.

### P0-04 — snapshotهای update ممکن است شامل secret با مجوز خواندن عمومی باشند

**شواهد:** [`update.sh`](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/update.sh)، تابع `snapshot_now()` حدود خطوط 188 تا 226:
- دایرکتوری `/var/backups/rathole-manager/pre-update-*` با `mkdir -p` ساخته می‌شود.
- آرشیو شامل `/etc/rathole`، `/etc/rathole-manager`، و `/opt/ratholehub` است.
- `umask 077` و `chmod 600/700` در مسیر ساخت snapshot اعمال نشده‌اند.
- در `hub.py:save_json()` نیز فایل موقت ثابت `path + ".tmp"` با mode پیش‌فرض ساخته و `os.replace()` می‌شود؛ `save_config()` بعد از replace فایل نهایی را chmod می‌کند. بنابراین فایل موقت و حتی بازه کوتاه/حالت crash قبل از chmod، تضمین permission امن ندارد.

**اثر:** در میزبان با umask معمول `022`، archive می‌تواند شامل tokenها، کلیدهای Noise، پیکربندی و اطلاعات حساس باشد و برای کاربران محلی خواندنی شود. فایل موقت config پنل هم ممکن است محتوی token را قبل از اعمال permission محدودکننده در خود داشته باشد.

**اصلاح لازم:** بلافاصله ابتدای `update.sh` از `umask 077` استفاده کنید و پیش از هر نوشتن mode امن را enforce کنید. بعد از ساخت، archive و manifest را با `stat` بررسی کنید. هنگام پیدا شدن snapshot با permission ناامن، هشدار/مهاجرت امن ارائه شود. همین قاعده برای `fresh_reset` backup در `install-panel.sh` هم اعمال شود.

### P0-05 — دانلود و اجرای کد به‌عنوان root بدون اعتبارسنجی cryptographic محتوا

**شواهد:** [`install.sh`](https://github.com/oldrcesupport/rathole-tunnel/blob/main/install.sh) فایل `bootstrap.sh` و bundle را از GitHub Release و mirrorهای ثالث دریافت می‌کند؛ سپس `bootstrap.sh` را با root اجرا می‌کند (حدود خطوط 100 تا 109 و 157 تا 193). `install-panel.sh` و `install-node.sh` نیز باینری upstream را دانلود و نصب می‌کنند؛ بررسی zip/`--version` جای امضای دیجیتال یا checksum مورد اعتماد را نمی‌گیرد. checksum داخلی `core/SHA256SUMS` اگر همراه همان archive باشد، به‌تنهایی اصالت ناشر را اثبات نمی‌کند.

**اثر:** mirror یا artifact دستکاری‌شده می‌تواند به اجرای کد/باینری دستکاری‌شده با دسترسی root منجر شود.

**اصلاح لازم:** برای bundle، bootstrap و باینری‌ها فرایند provenance تعریف کنید: checksum از منبع مستقل و قابل اعتماد یا امضای دیجیتال (مثلاً signing key ثابت و verify روی سرور)، tag/commit pinning و build reproducible در حد امکان. اگر integrity قابل اثبات نیست، installer باید fail closed کند و صریح بگوید چرا؛ صرف `curl -f` یا `unzip -t` کافی نیست.

### P0-06 — Releaseها وجود ندارند، ولی مسیر نصب و update آنلاین به Release asset وابسته است

**وضعیت مشاهده‌شده در 2026-10-22:** GitHub Release API برای این repo آرایه خالی برگرداند. با این حال:
- `install.sh` از `releases/latest/download/bootstrap.sh` و `rathole-manager.zip`/`.tar.gz` استفاده می‌کند (حدود خطوط 154 تا 184).
- `hub.py:deploy_to_server()` Release `install.sh` را دانلود و با `--update` اجرا می‌کند.
- مسیر update در `ratholectl` و node نیز Release/tag را resolve می‌کند.

**اثر:** نصب تک‌خطی و deploy/update از طریق پنل در حالت فعلی نمی‌توانند asset مورد انتظار را دانلود کنند. روش clone دستی README مسیر جداگانه‌ای است و این مشکل را رفع نمی‌کند.

**اصلاح لازم:** یک pipeline واقعی release بسازید که bundleها را با نام دقیق مورد انتظار تولید کند، checksum/signature منتشر کند و آزمون smoke روی assetها انجام دهد؛ یا همه مسیرها را یکپارچه به روش دریافت source/bundle pin‌شده تغییر دهید. پیش از اجرای update، وجود Release و assetهای ضروری را بررسی کنید؛ خطا باید سریع، دقیق و غیرمخرب باشد. مستندات `git pull` را با رفتار واقعی update هماهنگ کنید.


### P0-07 — در نبودن config پنل، credentialهای پیش‌فرض ناامن به‌صورت فعال استفاده می‌شوند

**شواهد:** `hub.py:get_config()` حدود خطوط 70 تا 87 در صورت نبودن `config.json` مقادیر پیش‌فرض `_INSECURE_TOKEN = "changeme"` و hash رمز `admin` را برمی‌گرداند. `_insecure` فقط برای نمایش هشدار تنظیم می‌شود؛ login و auth در حالت غیر-MOCK همچنان کار می‌کنند.

**اثر:** حذف/جابجایی تصادفی config یا نصب ناقص می‌تواند پنل را با credentialهای شناخته‌شده بالا بیاورد؛ اگر reverse proxy مسیر `/hub/` را به آن وصل کند، هشدار UI جلوی ورود با رمز پیش‌فرض را نمی‌گیرد.

**اصلاح لازم:** در production، نبودن config باید باعث fail startup شود و به هیچ‌وجه default token/password فعال نشود. fallback ناامن فقط در تست `MOCK=1` مجاز باشد. اگر config missing شد، unit با خطای واضح متوقف شود و health check degraded/failed برگرداند.

### P0-08 — `ssh_key_path` قابل تنظیم بدون allowlist است و مسیر نامناسب می‌تواند فایل سیستمی را حذف کند

**شواهد:** `hub.py:_config_save()` مقدار `ssh_key_path` را بدون اعتبارسنجی مسیر ذخیره می‌کند. سپس `ensure_hub_key()` اگر مسیر private key و مسیر متناظر `.pub` هر دو موجود نباشند، هر دو مسیر را با `os.remove()` حذف می‌کند و بعد `ssh-keygen -f <path>` را اجرا می‌کند.

**اثر:** با API config معتبر ولی `ssh_key_path` نامناسب، اگر مسیر موجود باشد و فایل `.pub` متناظر وجود نداشته باشد، ممکن است یک فایل موجود روی Hub حذف و با کلید جدید جایگزین شود. این می‌تواند به حذف فایل ناخواسته و از دست رفتن داده منجر شود.

**اصلاح لازم:** مسیر کلید باید زیر دایرکتوری اختصاصی و ثابت مثل `/etc/ratholehub/keys/` باشد؛ مسیر absolute دلخواه را نپذیرید. پیش از هر remove، `lstat`، نوع فایل، owner و مسیر resolved را بررسی کنید؛ هیچ فایل موجودی را صرفاً به‌دلیل فقدان `.pub` حذف نکنید. برای جفت ناقص، خطا بدهید یا backup امن/مسیر جدید بسازید. تست باید ثابت کند هیچ فایل خارج از دایرکتوری مجاز حذف یا تغییر نمی‌کند.

---

## یافته‌های P1: خطاهای عملکردی و از دست رفتن داده
### P1-01 — `ratholectl init` می‌تواند state موجود را از بین ببرد یا truncate کند

**شواهد:** `ratholectl:cmd_init` حدود خطوط 254 تا 267 مستقیماً این الگو را دارد: `jq -n ... '{..., nodes:[]}' > "$STATE"`، بدون نوشتن به temp امن، schema check یا backup اجباری. `ratholectl` از `set -uo pipefail` استفاده می‌کند، نه `set -e`.

**اثر:** اجرای دوباره `ratholectl init` می‌تواند همه nodeهای ثبت‌شده را با `nodes:[]` جایگزین کند. مهم‌تر اینکه shell قبل از اجرای `jq` فایل مقصد را truncate می‌کند؛ اگر `--argjson` نامعتبر باشد یا `jq` fail کند، state قبلی ممکن است از قبل پاک شده باشد و اسکریپت همچنان ادامه دهد.

**اصلاح لازم:** `init` نباید state موجود را بی‌صدا overwrite کند. state را به temp کنار مقصد بنویسید، JSON و schema را validate کنید، mode امن بدهید و سپس atomic rename انجام دهید. اگر فایل قبلی وجود دارد، پیش‌فرض باید fail شود یا با backup و تأیید صریح `--fresh/--reset` جلو برود. تست رگرسیون باید ثابت کند ورودی نامعتبر state قبلی را دست‌نخورده نگه می‌دارد.

### P1-02 — چند mutation در `ratholectl` خطای نوشتن را نادیده می‌گیرند و موفقیت گزارش می‌کنند

**شواهد:** `ratholectl`:
- `cmd_rm()` حدود خطوط 360 تا 375: `jq ... > "$STATE.tmp" && mv ...` بدون بررسی failure؛ پیام حذف و `regenerate` بعدش اجرا می‌شوند.
- `cmd_edit()` حدود خطوط 1290 تا 1340: هر فیلد جداگانه نوشته می‌شود و نتیجه `jq`/`mv` همیشه بررسی نمی‌شود؛ در صورت چند ورودی، ممکن است فیلد اول اعمال شود و اعتبارسنجی فیلد دوم fail شود، قبل از `regenerate`.
- `cmd_rename()` و `cmd_rotate()` حدود خطوط 1340 تا 1380 هم نوشتن را بدون error handling کامل انجام می‌دهند.
- در بعضی مسیرها temp با `mktemp` پیش‌فرض `/tmp` ساخته شده و بعد به `/etc/rathole-manager/state.json` منتقل می‌شود؛ این rename اگر روی filesystem متفاوت باشد لزوماً atomic نیست.

**اثر:** CLI می‌تواند بگوید node حذف/ویرایش/rotate شد، در حالی که state قدیمی مانده یا فقط بخشی از تغییر اعمال شده است. حالت بدتر، state و config رندرشده از هم فاصله می‌گیرند.

**اصلاح لازم:** یک helper تراکنشی مشترک بسازید: lock، temp در همان دایرکتوری مقصد، اجرای `jq`، parse و schema validation، mode امن، atomic rename، سپس regenerate/health-check. هر failure باید پیام خطای مشخص و exit code غیرصفر داشته باشد. تغییر چندفیلدی باید یا کامل اعمال شود یا هیچ تغییری نکند.

### P1-03 — قفل‌گیری در CLI و common helper در timeout به‌صورت fail-open رفتار می‌کند

**شواهد:**
- `ratholectl:rth_with_lock()` حدود خطوط 3170 تا 3225: اگر `flock -w 30` شکست بخورد، هشدار چاپ می‌شود اما دستور همچنان اجرا می‌شود. fallback مبتنی بر `mkdir` نیز پس از timeout با وجود `held=0` ادامه می‌دهد.
- `ratholenode:rth_with_lock()` در انتهای فایل همین الگو را دارد.
- `common.sh:rth_lock_resume()` و fallback قفل `rth_commit_config()` نیز بعد از timeout هشدار می‌دهند و بدون lock به نوشتن ادامه می‌دهند.

**اثر:** قفل، دقیقاً در وضعیت رقابت شدید/lock باقی‌مانده کنار گذاشته می‌شود. دو عملیات هم‌زمان می‌توانند یک state را بازنویسی کنند، port تکراری تخصیص دهند یا تغییر همدیگر را از بین ببرند.

**اصلاح لازم:** در صورت lock timeout، mutation باید fail شود، نه اینکه بدون قفل ادامه یابد. فقط read-only یا عملیات safe و صریح می‌تواند fallback داشته باشد. همه مسیرها باید «قفل واقعاً گرفته شد؟» را بررسی کنند و lock را در همه خروجی‌ها آزاد کنند. تست parallel با چند add/edit هم‌زمان و lock timeout لازم است.

### P1-04 — `rth_commit_config` فایل زنده را درجا truncate/write می‌کند

**شواهد:** `common.sh:rth_commit_config()` حدود خطوط 98 تا 124، با وجود ورودی موقت، از `cat "$src" > "$dst"` استفاده می‌کند. قفل writers را هماهنگ می‌کند اما process مصرف‌کننده config قفل را نمی‌گیرد.

**اثر:** هنگام write، برنامه‌ای که config را reload کند یا سرویس پس از crash/restart آن را بخواند ممکن است فایل خالی یا نیمه‌نوشته ببیند. در مسیر fallback نیز اگر قفل آزاد نشود، write بدون قفل انجام می‌شود.

**اصلاح لازم:** config موقت را قبل از commit کامل validate کنید؛ سپس روش commit امن را انتخاب کنید. اگر Rathole به inode ثابت برای hot reload وابسته است، این رفتار را با integration test ثابت کنید و از روش staging/reload کنترل‌شده استفاده کنید؛ در غیر این صورت atomic rename و بررسی اثر روی watcher ارجح است. صرف حفظ inode دلیل کافی برای نادیده گرفتن احتمال خواندن فایل نیمه‌نوشته نیست.

### P1-05 — نصب پنل حتی پس از شکست Nginx یا سرویس ممکن است موفق اعلام شود

**شواهد:** `install-panel.sh` حدود خطوط 337 تا انتها:
- شکست `nginx -t` صرفاً پیام چاپ می‌کند.
- `systemctl enable/restart/start` در چند جا با `|| true` سرکوب می‌شود.
- اگر `rathole-server` حتی بعد از تلاش دوم بالا نیاید، وضعیت و journal چاپ می‌شود اما اسکریپت به خروجی `nasb kamel shod!` می‌رسد و لزوماً با exit code شکست خارج نمی‌شود.
- راه‌اندازی `fakeweb` نیز با `|| true` نادیده گرفته می‌شود.

**اثر:** automation/agent، اسکریپت نصب را green می‌بیند در حالی که تونل یا Nginx down است.

**اصلاح لازم:** اجزای required و optional را جدا کنید؛ required failure باید exit code غیرصفر بدهد. موفقیت تنها بعد از `nginx -t`, `systemctl is-active`, `is-enabled` و smoke test حداقلی اعلام شود. optional failure باید با وضعیت `degraded` و هشدار مشخص گزارش شود.

### P1-06 — نصب نود ممکن است باینری اشتباه را تشخیص دهد و باینری لازم را نصب نکند

**شواهد:** `install-panel.sh` تابع `install_rathole()` و `install-node.sh` ابتدای نصب، از `command -v rathole` برای تشخیص نصب‌شدن استفاده می‌کنند؛ اما service unitها در هر دو مسیر `ExecStart=/usr/local/bin/rathole ...` هستند.

**اثر:** اگر `rathole` فقط مثلاً در `/usr/bin/rathole` موجود باشد و `/usr/local/bin/rathole` نباشد، installer ممکن است از دانلود/نصب صرف‌نظر کند و یک unit خراب ایجاد کند.

**اصلاح لازم:** وجود و قابل‌اجرابودن دقیقاً `/usr/local/bin/rathole` را بررسی کنید؛ نسخه و معماری همان فایل باید verify شود. اگر از باینری موجود استفاده می‌کنید، یا آن را به مسیر مورد انتظار نصب کنید یا `ExecStart` را بر اساس مسیر تأییدشده تولید کنید.

### P1-07 — نصب node پس از inactive ماندن سرویس لزوماً exit code شکست نمی‌دهد

**شواهد:** `install-node.sh` حدود خطوط 175 تا انتها، اگر `rathole-client` active نباشد فقط warning و journal چاپ می‌کند؛ اسکریپت بعداً به پایان می‌رسد. بخش fallback نصب اولیه نیز بعضی فرمان‌ها را بدون بررسی نتیجه اجرا می‌کند.

**اثر:** deployment pipeline می‌تواند نصب ناقص را موفق ثبت کند.

**اصلاح لازم:** بعد از نصب/restore، نبودن سرویس active یا fail شدن config validation باید exit code غیرصفر بدهد؛ حالت partial فقط زمانی مجاز باشد که صریحاً تعریف شده و در خروجی machine-readable گزارش شود.

### P1-08 — provision پنل شکست deploy یا تنظیم SERVER را همچنان success گزارش می‌کند

**شواهد:** `hub.py:provision_server()` حدود خطوط 365 تا 445: اگر SSH key نصب شود، حتی وقتی `deploy_to_server()` شکست خورده باشد، سرور در inventory ثبت می‌شود و نتیجه نهایی `rc: 0` است. برای node، نتیجه `ratholenode set SERVER ...` نیز بدون بررسی موفقیت نادیده گرفته می‌شود. `_provision()` بر اساس این `rc` پاسخ HTTP 200 می‌دهد.

**اثر:** UI می‌تواند node را آماده/ثبت‌شده نشان دهد درحالی‌که باینری نصب نشده یا endpoint اصلی تنظیم نشده است.

**اصلاح لازم:** وضعیت‌های `success`, `partial`, `failed` را تفکیک کنید و `deploy_rc`/`set_server_rc` را نگه دارید. ثبت موقت server در inventory اشکالی ندارد، اما باید `pending/failed` باشد و هرگز `rc=0` و پیام موفقیت کامل برنگرداند.

### P1-09 — اعتبارسنجی port فقط عددی است، نه بازه واقعی TCP/UDP

**شواهد:** `hubcmds.py`، `RE_PORT = ^[0-9]{1,5}$` و `RE_IPPORT` نیز تنها تعداد رقم‌ها را بررسی می‌کند. `ratholectl` و `ratholenode add-svc` ورودی inbound را با `^[0-9]+$` می‌پذیرند.

**اثر:** مقادیری مثل `0`, `65536` یا `99999` ممکن است از UI/CLI عبور کنند، ولی سرویس در مرحله config/runtime شکست بخورد. برخی پروتکل‌ها و نقش‌ها نیازمند بازه یا محدودیت‌های خاص‌اند.

**اصلاح لازم:** helper واحد برای parse عددی port بسازید و `1 <= port <= 65535` را validate کنید. مواردی مثل port تخصیص‌یافته، port reserved و UDP/TCP را جدا بررسی کنید. regex به‌تنهایی برای این validation کافی نیست.

### P1-10 — `adaptive` معیار recovery/cooldown را واقعاً پیاده‌سازی نمی‌کند

**شواهد:** `ratholenode` در `adaptive on` مقدار `ADAPTIVE_RECOVERIES` و `ADAPTIVE_COOLDOWN` را ذخیره/نمایش می‌دهد (حدود خطوط 1575 تا 1685)، اما `adaptive_should_switch()` عملاً تصمیم را با تعداد failure می‌گیرد و caller مقدار recovery/cooldown را ثابت `0, 0` می‌دهد.

**اثر:** رفتار hysteresis و recovery مطابق تنظیمات کاربر نیست؛ روی packet loss مقطعی احتمال flip-flop و restartهای پی‌درپی وجود دارد.

**اصلاح لازم:** state ماشین adaptive را کامل کنید: تعداد success متوالی، cooldown زمان‌دار، حداقل dwell time، transition فقط بعد از تأیید سلامت مسیر جایگزین، و ثبت reason هر transition. اگر recovery هنوز پیاده‌سازی نشده، option را حذف/غیرفعال و در UI صریح اعلام کنید.


### P1-11 — شکست ساخت snapshot مانع update نمی‌شود، پس auto-rollback ممکن است اصلاً backup قابل‌استفاده نداشته باشد

**شواهد:** `update.sh:snapshot_now()` حدود خطوط 211 تا 220 اگر `tar -czf` شکست بخورد تنها warning چاپ می‌کند؛ بعد از آن باز هم snapshot را log کرده و مسیر دایرکتوری را return می‌کند. update با `SNAP_DIR` غیرخالی ادامه پیدا می‌کند.

**اثر:** اگر health check بعد از update fail شود، `rollback_to()` ممکن است به دلیل نبودن `backup.tar.gz` متوقف شود. در نتیجه مکانیزم «snapshot + auto rollback» با وجود پیام ساخت snapshot، تضمین rollback ندارد.

**اصلاح لازم:** موفقیت snapshot فقط وقتی اعلام شود که archive ساخته، non-empty، قابل‌خواندن و checksum آن verify شده باشد. اگر auto-rollback روشن است و snapshot معتبر ساخته نشد، update باید پیش از تغییر فایل‌های live متوقف شود. تست disk-full، permission-denied و archive ناقص اضافه شود.

### P1-12 — health check بعد از update فقط active بودن service را ارزیابی می‌کند

**شواهد:** `update.sh:health_check()` عمدتاً `systemctl is-active`، `nginx -t` و active بودن nginx را می‌سنجد؛ `restart_services()` چند restart را با `|| true` پنهان می‌کند. ترافیک واقعی tunnel یا end-to-end probe در خود update الزامی نیست.

**اثر:** سرویس می‌تواند active باشد و در journal خطای retry/handshake داشته باشد، اما update «سالم» گزارش شود. این مخصوصاً برای remote endpoint، TLS/SNI، یا tunnelی که listener آن محلی است مهم است.

**اصلاح لازم:** health check باید حداقل config validation، active/enabled state، تازگی log، اتصال control channel و یک smoke test end-to-end محدود و timeoutدار داشته باشد. اگر مسیر end-to-end قابل تست نیست باید وضعیت `degraded/unknown` باشد، نه `healthy` قطعی.

---

## یافته‌های P2: سلامت واقعی، امنیت دفاعی و سازگاری
### P2-01 — probe مربوط به KCP فقط listener محلی را بررسی می‌کند

**شواهد:** `ratholenode:adaptive_probe_kcp()` حدود خطوط 1490 تا 1495، `adaptive_probe_tcp` را روی `KCP_LOCAL` (معمولاً `127.0.0.1:29900`) اجرا می‌کند.

**اثر:** بازبودن listener محلی KCP client به‌تنهایی سالم‌بودن UDP بین نود و سرور ایران یا رسیدن ترافیک به مقصد را ثابت نمی‌کند. ممکن است adaptive تونل را healthy اعلام کند درحالی‌که مسیر بیرونی مرده است.

**اصلاح لازم:** probe چندمرحله‌ای طراحی کنید: listener محلی، UDP/remote reachability در حد امکان و مهم‌تر از همه یک synthetic request از مسیر تونل تا سرویس تست تحت کنترل. در JSON وضعیت، `local_listener`, `remote_path`, `end_to_end` را جدا گزارش کنید.

### P2-02 — probe TLS/WebSocket در adaptive امکان false negative دارد و تست رگرسیون اختصاصی ندارد

**شواهد:** `ratholenode:adaptive_probe_ws_tls()` حدود خطوط 1450 تا 1475 از `timeout 8 openssl s_client ... -quiet` استفاده می‌کند و اگر pipeline با exit code غیرصفر خاتمه یابد، بلافاصله `tls_failed` می‌دهد؛ بررسی متن `HTTP/1.1 101` پس از این شرط انجام می‌شود.

**ریسک قابل بازتولید:** WebSocket 101 معمولاً connection طولانی نگه می‌دارد. اگر `openssl s_client` تا timeout زنده بماند و بعد killed شود، حتی با دریافت 101 ممکن است مسیر به‌اشتباه `tls_failed` ثبت شود. این مورد باید با fixture محلی که بعد از 101 اتصال را باز نگه می‌دارد، تأیید/رد شود. تست موجود `test-harness.sh` روی helper دیگری (`rth_probe`) کار می‌کند و این تابع adaptive را پوشش نمی‌دهد.

**اصلاح لازم:** دریافت پاسخ handshake را از مدت عمر connection جدا کنید؛ پس از دیدن status/header کامل 101 probe را تمام کنید، یا خروجی را حتی در timeout parse کنید و فقط وقتی response معتبر دریافت نشده failure بدهید. تست‌های 101، 401، TLS cert invalid، timeout قبل از header و connection بازمانده لازم‌اند.

### P2-03 — ورودی endpoint بدون port پذیرفته می‌شود، اما برای config/probe احتمالاً ناقص است

**شواهد:** `ratholenode set SERVER` و `install-node.sh` host بدون `:port` را می‌پذیرند؛ برخی builderهای پنل نیز `RE_HOST` را جایگزین `RE_IPPORT` قبول می‌کنند. سپس config `remote_addr` را همان رشته می‌نویسد و adaptive port را از `${SERVER##*:}` استخراج می‌کند.

**اثر:** ورودی مثل `example.com` می‌تواند در config/probe به endpoint ناقص یا port برابر خود hostname تبدیل شود.

**اصلاح لازم:** یا port پیش‌فرض مستند و صریح (مثلاً 443 فقط برای mode مربوطه) را خودکار اضافه کنید، یا endpoint بدون port را رد کنید. یک parser مشترک endpoint باید در CLI، installer و hub استفاده شود.

### P2-04 — پسورد پنل با SHA-256 بدون salt ذخیره می‌شود و session cookie `Secure` ندارد

**شواهد:** `hub.py`، default hash و مسیر login حدود خطوط 28 تا 50 و 929 تا 943؛ پسورد با `hashlib.sha256` مقایسه می‌شود و `Set-Cookie` به `HttpOnly; SameSite=Strict; Path=/` محدود است اما `Secure` ندارد. UI نیز API token را در `localStorage` نگه می‌دارد (`ui/app.js` ابتدای فایل و login/api handlers).

**اثر:** SHA-256 برای نگهداری پسورد در برابر brute-force آفلاین مناسب نیست؛ نبود `Secure` برای cookie در حالت HTTP پیکربندی ناامن است؛ localStorage دسترسی JavaScript را به bearer token می‌دهد و اثر هر XSS آینده را شدیدتر می‌کند.

**اصلاح لازم:** الگوریتم پسورد را به `scrypt` یا `PBKDF2` با salt و پارامترهای ذخیره‌شده مهاجرت دهید؛ cookie در deployment TLS دارای `Secure` باشد؛ ترجیحاً API token از JavaScript خارج شود و session کوتاه‌عمر/قابل‌لغو به کار رود. انتقال از hash قدیمی با migration backward-compatible انجام شود.

### P2-05 — پاسخ JSON با نوع معتبر ولی ساختار اشتباه می‌تواند handler را به exception بکشاند

**شواهد:** `hub.py:_body_json()` می‌تواند هر JSON معتبر، از جمله list/string/number/null را برگرداند، ولی login و چند handler بعدی بلافاصله `data.get(...)` یا `d.get(...)` فراخوانی می‌کنند.

**اثر:** درخواست malformed از نظر schema به exception پاسخ‌دهنده منجر می‌شود؛ server معمولاً process-wide از کار نمی‌افتد، اما درخواست fail غیرکنترل‌شده خواهد داشت و در برابر فشار درخواست آسیب‌پذیرتر می‌شود.

**اصلاح لازم:** در ورودی همه routeها `dict` بودن payload و نوع/محدوده فیلدها بررسی شود؛ malformed JSON یا schema با 400 و پیام عمومی برگردد. برای Content-Length منفی/بسیار بزرگ و body ناتمام هم رفتار مشخص تعریف شود.

### P2-06 — rate limiter ورود به پنل به `X-Real-IP` اعتماد می‌کند و رکوردهای IP پاک‌سازی کامل نمی‌شوند

**شواهد:** `hub.py:login_allowed/login_record_fail` حدود خطوط 31 تا 51 از dict حافظه‌ای `_LOGIN_FAILS` استفاده می‌کند؛ login نیز IP را اول از header `X-Real-IP` می‌گیرد.

**اثر:** در صورت دسترسی مستقیم به endpoint یا reverse-proxy بدپیکربندی‌شده، header قابل جعل است و می‌توان limit را دور زد؛ آدرس‌های تصادفی نیز می‌توانند map را بزرگ کنند.

**اصلاح لازم:** proxyهای مورد اعتماد را صریح تعریف کنید و header فقط وقتی از proxy معتبر آمده باشد پذیرفته شود؛ IP را parse/normalize کنید، keyهای منقضی را به‌صورت دوره‌ای پاک کنید و limit حافظه را محدود کنید. rate limit در nginx/firewall نیز در نظر گرفته شود.

### P2-07 — نصب مجدد پنل می‌تواند کانفیگ‌های نامرتبط Nginx را جابه‌جا و سایت‌ها را از دسترس خارج کند

**شواهد:** `install-panel.sh:handle_conflicts()` حدود خطوط 265 تا 310 همه فایل‌های `conf.d/*.conf` و `sites-enabled/*` را که متنشان `listen 443` دارد جمع می‌کند؛ با تأیید کاربر همه آن‌ها به دایرکتوری backup منتقل می‌شوند.

**اثر:** روی سروری که چند سایت یا reverse proxy دارد، فایل‌هایی که صرفاً پورت 443 دارند ممکن است نامرتبط با Rathole باشند و از config فعال خارج شوند.

**اصلاح لازم:** به‌جای جابه‌جایی دسته‌جمعی، `nginx -T` را تحلیل کنید، فقط conflict واقعی را گزارش کنید، فایل و server block مشخص را نشان دهید و برای تغییر هر مورد تأیید جداگانه بگیرید. هیچ config غیرمرتبطی را خودکار غیرفعال نکنید.

### P2-08 — restore از tar به root path بدون بررسی کامل memberها انجام می‌شود

**شواهد:** در fallback مسیر restore در `install-node.sh`، اگر `ratholenode` در دسترس نباشد، archive با `tar -xzf "$RESTORE" -C /` استخراج می‌شود. `update.sh:rollback_to()` هم archive را مستقیماً در `/` استخراج می‌کند.

**اثر:** archive دستکاری‌شده یا اشتباه می‌تواند فایل‌های خارج از مسیر مورد انتظار را به‌عنوان root بنویسد. اگر backup به‌دست‌آمده از منبع نامطمئن باشد، خطر بالا است.

**اصلاح لازم:** فهرست عضوهای archive، مسیرهای absolute و `..`، نوع file و symlinkها را پیش از استخراج validate کنید؛ restore را از archive مورد اعتماد/دارای checksum انجام دهید و قبل از overwrite از فایل‌های فعلی backup بگیرید.

### P2-09 — inventory خراب/با schema اشتباه می‌تواند بی‌صدا به «بدون سرور» تبدیل شود

**شواهد:** `hub.py:get_inventory()` اگر مقدار JSON فهرست نباشد `[]` برمی‌گرداند.

**اثر:** corruption/schema regression شبیه inventory خالی به UI نشان داده می‌شود؛ اپراتور ممکن است تصور کند همه سرورها حذف شده‌اند.

**اصلاح لازم:** JSON parse error و schema error را جدا کنید؛ تا recovery، API با خطای واضح/health degraded پاسخ دهد و فایل اصلی هرگز خودکار با `[]` جایگزین نشود.

### P2-10 — به‌روزرسانی hub assetها را بدون تضمین سازگاری نسخه‌ای کپی می‌کند

**شواهد:** `update.sh` در بخش `HUB`، `hub.py`, `hubcmds.py` و assetهای UI را به‌صورت شرطی کپی می‌کند و اگر بعضی فایل‌ها در bundle نباشند، ممکن است نسخه جدید Python با asset قدیمی/ناقص اجرا شود؛ سپس restart نیز warning-only است.

**اثر:** API جدید و UI قدیمی یا برعکس می‌توانند از نظر fieldها/actionها ناسازگار شوند، با اینکه update ظاهراً ادامه پیدا کرده است.

**اصلاح لازم:** bundle باید manifest نسخه و فهرست فایل‌های لازم داشته باشد؛ پیش از تغییر، همه assetهای required validate شوند. staging directory، health check واقعی و rollback خودکار در صورت mismatch استفاده شود.


### P2-12 — رمز SSH هنگام provision به‌صورت آرگومان process فرستاده می‌شود

**شواهد:** `hub.py:provision_server()` حدود خطوط 425 تا 450 `subprocess.run(["sshpass", "-p", pw, "ssh", ...])` را اجرا می‌کند.

**اثر:** برای مدتی کوتاه، پسورد در command line پردازش دیده می‌شود؛ بسته به تنظیمات `/proc` و کاربران محلی، می‌تواند در خروجی ابزارهایی مثل `ps` قابل مشاهده باشد.

**اصلاح لازم:** از روش ورودی امن‌تر مثل `SSHPASS` و `sshpass -e` استفاده کنید، متغیر را فقط برای همان child process ست کنید و در لاگ/exception چاپ نکنید. credential پس از عملیات از حافظه/محیط باقی‌مانده پاک شود تا حد امکان.

### P2-11 — گزینه `--fresh` فقط بخشی از اجزای panel را reset می‌کند و می‌تواند سرویس‌های فرعی یتیم باقی بگذارد

**شواهد:** `install-panel.sh:fresh_reset()` حدود خطوط 80 تا 91، تنها بعضی state/configها را backup و حذف می‌کند؛ فقط `rathole-server` را متوقف می‌کند و همه unitهای Noise/Backhaul/KCP یا فایل‌های Nginx stream را به‌طور جامع reconcile نمی‌کند.

**اثر:** نصب از نو ممکن است state اصلی را پاک کند ولی unit یا config فرعی قدیمی همچنان فعال بماند، پورت اشغال کند یا با state جدید ناسازگار شود.

**اصلاح لازم:** reset را به plan صریح تبدیل کنید: inventory از تمام unit/configهای شناخته‌شده، dry-run، backup با permission امن، تأیید کاربر، stop/disable هدفمند و در انتها reconciliation وضعیت. هیچ unit ناشناخته یا Nginx config نامرتبط حذف نشود.

---

## یافته‌های P3: بهبودها و نگهداشت‌پذیری
### P3-01 — `install.sh` احتمالاً دایرکتوری موقت را پس از exec پاک نمی‌کند

`install.sh` trap پاک‌سازی در خط حدود 160 تنظیم می‌کند، ولی در پایان با `exec bash "$tmp/bootstrap.sh" ...` پوسته را جایگزین می‌کند. با موفقیت `exec`، cleanup trap پوسته قبلی اجرا نمی‌شود؛ بنابراین فایل‌های دانلودشده ممکن است در `/tmp` باقی بمانند. به‌جای `exec` اجرای مستقیم و cleanup تضمین‌شده یا انتقال مالکیت cleanup به bootstrap استفاده شود.

### P3-02 — نبود CI و contract test برای Release assetها

در درخت فعلی `.github/workflows` مشاهده نشد. برای پروژه‌ای که چندین مسیر shell و بسته Release دارد، حداقل pipelineهای زیر لازم‌اند: `bash -n`، ShellCheck، `python -m py_compile`، تست unit پایتون، تست harness با exit code درست، بررسی مجوز فایل‌ها، و ساخت/صحت‌سنجی assetهای Release.

### P3-03 — harness فعلی ممکن است نتیجه سبز کاذب بدهد

`test-harness.sh` در بسیاری از تست‌ها متن `FAIL` چاپ می‌کند ولی در پایان تعداد شکست‌ها را به exit code تبدیل نمی‌کند. همچنین `systemctl`/`nginx` اغلب mock هستند و آزمون config runtime/upgrade/rollback/security permission پوشش کافی ندارد.

**اصلاح لازم:** `fail_count`/`pass_count` داشته باشید، در هر failure شمارنده را افزایش دهید و در پایان با `exit 1` شکست بدهید. در CI هیچ test به خاطر نبود dependency نباید بی‌صدا pass شود؛ `SKIP` باید شفاف باشد.

### P3-04 — مستندات نصب/آپدیت با رفتار فعلی هماهنگ نیستند

README و `GITHUB_INSTALL_GUIDE.fa.md` بر `git pull` تأکید می‌کنند؛ درحالی‌که مسیر deploy پنل و `install.sh` به Release assetها وابسته است. راهنمای آنلاین باید دقیقاً توضیح دهد کدام روش برای نصب دستی، نصب Release و update کاربرد دارد و از ترکیب دو مکانیزم متفاوت بدون نسخه‌بندی جلوگیری کند.

### P3-06 — برخی ادعاهای README در sourceهای بررسی‌شده قابل ردیابی یا آزمون نیستند

README ادعای «پشتیبانی کامل XHTTP/SplitHTTP» و «0-RTT Vision» دارد، اما در جست‌وجوی source و راهنماهای بررسی‌شده، implementation/config/test روشن با همین قابلیت‌ها پیدا نشد. این به‌تنهایی اثبات نمی‌کند که سناریوی بیرونی هرگز کار نمی‌کند؛ اما claim محصولی بدون مثال کانفیگ و تست رگرسیون قابل اتکا نیست.

**اصلاح لازم:** برای هر feature ادعاشده، مسیر واقعی packet/config، پیش‌نیاز نسخه Xray/Rathole/Nginx و یک test قابل اجرا مستند کنید؛ در غیر این صورت متن را به «قابل استفاده در سناریوی Xray متناسب، پس از تنظیم دستی» محدود کنید و از قول پشتیبانی کامل خودداری کنید.

### P3-05 — سیاست نسخه و معماری بین نصب باینری‌ها یکپارچه نیست

`install-panel.sh` و `install-node.sh` برای `aarch64` یک artifact upstream با پسوند `musl` انتخاب می‌کنند، درحالی‌که `core-install.sh` مسیر/نام artifact دیگری را فرض می‌کند. ممکن است این تفاوت برای core patched عمدی باشد، اما matrix تست x86_64/aarch64 و glibc/musl لازم است تا fallback ناخواسته به باینری ناسازگار تبدیل نشود.

---

## ترتیب اصلاح پیشنهادی

### مرحله 0: ایمن‌سازی و جلوگیری از آسیب بیشتر

1. enforce کردن permissionهای فایل‌های حساس و snapshotها.
2. حذف secret از audit log و محدودکردن `ssh_opts`.
3. اضافه‌کردن preflight وجود Release و assetها؛ تا قبل از pipeline سالم، update را از اجرای نیمه‌کاره متوقف کنید.
4. اصلاح false success در نصب، deploy، restart و restore.

### مرحله 1: اتمیک‌بودن و حفظ state

1. `init` باید state قبلی را حفظ کند و در ورودی بد، هیچ فایلی را تغییر ندهد.
2. mutationهای CLI به helper تراکنشی واحد منتقل شوند.
3. همه قفل‌ها fail-closed شوند.
4. port/endpoint validation مشترک در همه entrypointها استفاده شود.

### مرحله 2: adaptive و آزمون عملی

1. regression test برای 101 طولانی، TLS fail، 401، KCP listener بدون remote reachability و packet loss.
2. recovery/cooldown واقعی با hysteresis پیاده شود.
3. health check بعد از update باید مسیر واقعی تونل را تست کند، نه فقط active بودن systemd.

### مرحله 3: release/CI و نگهداشت

1. CI قابل تکرار با ShellCheck، syntax checks، unit tests و test harness fail-fast.
2. ساخت Release assetهای نام‌گذاری‌شده و checksum/signature.
3. مستندات، نسخه‌ها و معماری artifactها هماهنگ شوند.

---

## معیارهای پذیرش کلی برای Agent

- در failure هیچ success message یا exit code صفر جعلی تولید نشود.
- هر فایل حاوی token/key/password با permission صریح و تست‌شده محافظت شود.
- failure در تولید JSON/TOML یا validation پیش از commit هیچ تغییری در فایل نهایی ایجاد نکند.
- lock timeout باعث اجرای mutation بدون قفل نشود.
- ورودی port همه جا بین 1 و 65535 بررسی شود و endpoint ناقص پذیرفته نشود.
- هیچ credential در log, audit, exception یا command output ثبت نشود.
- Release/download بدون integrity verification قابل اعتماد اجرا نشود.
- تمام تست‌های شکست exit code غیرصفر بسازند؛ CI روی repo تازه و حداقل دو معماری پشتیبانی‌شده اجرا شود.
- تست runtime destructive فقط در sandbox/container یا staging مجزا اجرا شود؛ به سرورهای واقعی/فعال کاربر وصل نشود.

---

## لینک‌های اصلی کد برای مرور سریع

- [install.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/install.sh)
- [bootstrap.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/bootstrap.sh)
- [common.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/common.sh)
- [ratholectl](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholectl)
- [ratholenode](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholenode)
- [update.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/update.sh)
- [install-panel.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/install-panel.sh)
- [install-node.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/install-node.sh)
- [hub.py](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholehub/hub.py)
- [hubcmds.py](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/ratholehub/hubcmds.py)
- [test-harness.sh](https://github.com/oldrcesupport/rathole-tunnel/blob/main/rathole-manager/rathole-manager/test-harness.sh)
