# پرامپت Agent برای رفع باگ‌های Rathole Tunnel Manager

تو روی مخزن زیر کار می‌کنی:

`https://github.com/oldrcesupport/rathole-tunnel`

ابتدا گزارش ممیزی `rathole-tunnel-audit.md` را کامل بخوان و کد را از روی commit فعلی بررسی کن. هدف، رفع ریشه‌ای باگ‌ها، مخصوصاً silent failure، corruption، افشای secret، race condition و false-positive health checks است؛ نه صرفاً ساکت کردن خطاها یا تغییر پیام‌ها.

## قواعد اجرا

1. ابتدا وضعیت git، شاخه، commit پایه، فایل‌های تغییرکرده و تست‌های فعلی را ثبت کن. به تغییرات موجود کاربر دست نزن.
2. روی شاخه جدید کار کن؛ مستقیم روی `main` commit/push/merge نکن. به هیچ سرور واقعی کاربر SSH نزن و هیچ systemd/Nginx/فایروال واقعی را تغییر نده.
3. تغییرات را مرحله‌ای و کوچک انجام بده؛ برای هر باگ یک تست رگرسیون بنویس که قبل از fix fail و بعد از fix pass شود.
4. backward compatibility با state/configهای قدیمی را حفظ کن. اگر migration لازم است، backup امن و rollback تعریف کن.
5. هیچ secret واقعی را به تست، fixture، stdout، CI log یا audit log اضافه نکن. از tokenهای آزمایشی واضح استفاده کن.
6. خطا را با `|| true`، catch-all بدون گزارش، warning به‌جای شکست، یا تستی که همیشه pass شود پنهان نکن.
7. هیچ باینری root-level را از منبع غیرقابل‌اعتبار بدون integrity verification نصب/اجرا نکن.
8. اگر چیزی از طریق runner قابل اجرا نیست، صریح گزارش کن و ادعای تست اجراشده نکن.

## فاز 1: اولویت بحرانی امنیت و نصب

- تمام فایل‌های حاوی token، key، password، state و snapshot را پیدا کن. `umask 077` و mode صریح متناسب (`0600` فایل و `0700` دایرکتوری) را در همه مسیرهای ساخت/جایگزینی enforce کن؛ فایل موقت هم باید از لحظه ایجاد private باشد. موارد حداقل شامل `state.json`, TOMLها، hub config، audit log، KCP/systemd configuration و update/fresh-reset backupها هستند.
- از ذخیره raw command یا secret در audit log جلوگیری کن. redaction باید متناسب با schema و همه actionهای token-bearing باشد. تست کن که secret تستی پس از درخواست در فایل audit، پاسخ API و logهای CI وجود ندارد.
- `ssh_opts` را به یک allowlist امن تبدیل کن یا حذفش کن. گزینه‌های اجرای فرمان محلی نظیر `ProxyCommand`, `LocalCommand`, `PermitLocalCommand`, `-F` و گزینه‌های غیرقابل‌اعتماد را رد کن. یک تست منفی برای هر گزینه خطرناک بنویس.
- در `ensure_hub_key()` نبودن `config.json` را به credentialهای `changeme/admin` تبدیل نکن؛ در production fail closed شود. `ssh_key_path` باید زیر مسیر اختصاصی allowlist شده باشد؛ هیچ مسیر دلخواهی را remove/overwrite نکن و برای `.pub` گم‌شده، فایل private موجود را خودکار حذف نکن.
- از عبور دادن پسورد SSH با `sshpass -p <password>` پرهیز کن؛ از روش امن‌تر استفاده و خروجی/logها را از credential پاک نگه دار.
- `install.sh`, `bootstrap.sh`, `deploy_to_server` و نصب باینری‌ها را طوری اصلاح کن که Release/assetها پیش‌بررسی شوند و integrity به روش cryptographically trusted تأیید شود. checksumی که فقط داخل همان archive دانلودشده قرار دارد، تأیید اصالت محسوب نشود.
- از آنجا که هنگام ممیزی Release asset وجود نداشت، pipeline Release بساز یا download strategy را یکپارچه و pin کن. فایل‌های مورد انتظار باید دقیقاً و تست‌پذیر تولید شوند. اگر asset موجود نیست، عملیات باید قبل از هر تغییر روی سرور متوقف شود.

## فاز 2: جلوگیری از از دست رفتن state و race condition

- `ratholectl init` باید اگر state وجود دارد پیش‌فرض آن را overwrite نکند. تمام ورودی‌ها را قبل از نوشتن اعتبارسنجی کن؛ temp را کنار مقصد بساز، JSON/schema را validate کن و بعد atomic rename انجام بده. روی خطا state قبلی باید byte-for-byte باقی بماند.
- mutationهای `cmd_rm`, `cmd_edit`, `cmd_rename`, `cmd_rotate` و تمام writerهای `ratholenode` را بررسی کن. خطای `jq`, `mv`, `systemctl`, file write یا regenerate باید درست propagate شود. چندفیلدی‌ها transaction باشند: یا همه اعمال شوند یا هیچ‌کدام.
- هر مسیر `flock` و fallback `mkdir` را fail-closed کن. اگر lock به دست نیامد، mutation اجرا نشود. در مسیر read-modify-write lock تا پایان commit نگه داشته شود؛ حین prompt تعاملی، lock pause/resume با شکست قابل تشخیص کار کند.
- `rth_commit_config` را اصلاح کن تا مصرف‌کننده config فایل نیمه‌نوشته نبیند. اگر رفتار hot-reload به inode ثابت وابسته است، با integration test اثباتش کن و مکانیزم staging/reload امن انتخاب کن.
- یک validator مشترک برای port و endpoint بساز و در UI action builder، hub API، CLI، installer و config migration استفاده کن. Port باید 1..65535 باشد؛ host بدون port باید رد یا با default مشخص و مستند normalize شود.

## فاز 3: false success و سلامت واقعی

- در `install-panel.sh` و `install-node.sh` شکست هر component ضروری، config validation، `nginx -t`، restart/start یا health check باید exit code غیرصفر بدهد. optional features باید واضح `degraded/optional failed` گزارش شوند.
- در `ratholenode` و `ratholectl`، هر فرمانی که در شکست `warn` می‌دهد و سپس return code صفر می‌سازد اصلاح شود. به‌ویژه `restart_svc`, `reload_svc`, KCP/plain/noise/backhaul toggleها، watchdog و adaptive timer.
- `hub.py:provision_server()` باید failure مرحله deploy یا set SERVER را با `partial/failed` مشخص کند و HTTP/UI موفقیت کامل گزارش نکند.
- بعد از update فقط `systemctl is-active` کافی نیست: config validate و smoke test مسیر واقعی تونل انجام شود، با timeout مشخص و rollback در صورت شکست.
- adaptive را به state machine واقعی تبدیل کن. recovery threshold، cooldown و dwell time باید واقعاً استفاده شوند. KCP probe صرفاً به بازبودن local TCP listener تکیه نکند.
- `adaptive_probe_ws_tls()` را با fixtureای تست کن که پاسخ 101 می‌دهد و اتصال را باز نگه می‌دارد. اگر timeout باعث kill بعد از دریافت 101 می‌شود، آن را false positive/negative نکند؛ parse handshake از lifetime کانکشن مستقل شود. تست‌های 101، 401، TLS invalid، timeout پیش از header، پاسخ ناقص و WS-long-lived الزامی‌اند.

## فاز 4: کیفیت تست و CI

- harness فعلی را fail-fast کن: هر `FAIL` باید شمارنده را زیاد کند و انتهای اجرا `exit 1` بدهد. `SKIP`ها دلیل مشخص داشته باشند. تست نباید با mockهایی که همه فرمان‌ها را success برمی‌گردانند، خطای واقعی را بپوشاند.
- workflow CI اضافه کن که دست‌کم این‌ها را اجرا کند:
  - `bash -n` روی تمام اسکریپت‌ها
  - ShellCheck روی Bash و رفع یا توجیه inline هر disable
  - `python -m py_compile` برای `hub.py` و `hubcmds.py`
  - unit tests برای route/schema/auth/permission/redaction/command builder
  - تست‌های concurrency برای add/edit/rename و lock timeout
  - تست حفظ state بعد از `jq` failure/disk/write simulation
  - permission tests با umask متداول `022`
  - update/rollback/provision با fake `ssh`, `systemctl`, `nginx`, `curl` در sandbox
  - تست ساخت Release و verify نام، checksum/signature و وجود assetها
- در تست‌های configuration از parser/binary validation واقعی در sandbox استفاده کن؛ فقط string matching در TOML/nginx کافی نیست.

## فاز 5: ایمنی عملیات و مستندات

- `install-panel.sh:handle_conflicts()` نباید همه فایل‌های Nginx دارای `listen 443` را دسته‌جمعی از مسیر فعال خارج کند. conflict واقعی را گزارش بده و فایل نامرتبط را تغییر نده.
- archive restore را پیش از استخراج بررسی کن: absolute path، `..`, symlink، hardlink و file typeهای غیرمنتظره رد شوند. restore فقط از archive معتبر انجام شود.
- مطمئن شو assetهای UI و `hub.py`/`hubcmds.py` نسخه سازگار دارند و update از ترکیب فایل‌های قدیمی/جدید جلوگیری می‌کند.
- مستندات `README.md`, `GITHUB_INSTALL_GUIDE.fa.md`, `MANUAL_INSTALL_GUIDE.fa.md` و دستورهای CLI را با رفتار واقعی install/update هماهنگ کن.

## خروجی‌های الزامی

1. یک issue/جدول در گزارش تغییرات که برای هر مورد شامل severity، فایل/تابع، ریشه مشکل، تغییر انجام‌شده، تست رگرسیون و نتیجه تست باشد.
2. تغییرات کد و تست‌ها در شاخه کاری، با commitهای کوچک و پیام‌های روشن.
3. خروجی کامل تست‌ها و نسخه ابزارها. تست اجرا نشده را «passed» اعلام نکن.
4. فهرست riskهای باقی‌مانده و migration لازم برای نصب‌های قبلی، به‌خصوص chmod امن فایل‌های موجود و مهاجرت hash پسورد.
5. خلاصه نهایی شامل فایل‌های تغییرکرده، رفتار قبل/بعد، commands اجراشده و نتیجه هر command.

## معیار موفقیت

کار تمام نیست مگر اینکه خطاهای مخرب دیگر به success code تبدیل نشوند، state در شکست حفظ شود، secretها در فایل/log قابل‌خواندن عمومی نباشند، lock timeout باعث mutation بدون قفل نشود، update integrity را verify کند، تست‌ها شکست را واقعاً fail کنند و همه مسیرهای مهم تحت regression test پوشش داده شده باشند.
