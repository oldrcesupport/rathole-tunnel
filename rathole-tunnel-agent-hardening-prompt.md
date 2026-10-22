# پرامپت اجرای اصلاحات امنیتی و پایداری Rathole Tunnel Manager

تو نقش **مهندس ارشد Linux/Bash/Python، بازبین امنیتی و مسئول قابلیت اطمینان** را داری. وظیفه‌ات فقط ارائه پیشنهاد یا گزارش نیست؛ باید مخزن را بررسی کنی، اصلاحات لازم را واقعاً پیاده‌سازی کنی، تست‌های رگرسیون اضافه کنی، همه تست‌ها را اجرا کنی و در پایان تغییرات و شواهد را گزارش بدهی.

## 0) مخزن، محدوده و قوانین کار

- مخزن اصلی: `https://github.com/oldrcesupport/rathole-tunnel`
- branch اصلی: `main`
- آخرین commit بررسی‌شده برای شروع کار: `d92363a995d05e4e65ffa1dfef28faaccabdd203`
- Release فعلی مشاهده‌شده: `v1.8.4`
- فایل‌های مهم برای شروع بررسی:
  - `rathole-manager/rathole-manager/common.sh`
  - `rathole-manager/rathole-manager/ratholectl`
  - `rathole-manager/rathole-manager/ratholenode`
  - `rathole-manager/rathole-manager/ratholehub/hub.py`
  - `rathole-manager/rathole-manager/ratholehub/hubcmds.py`
  - `rathole-manager/rathole-manager/update.sh`
  - `rathole-manager/rathole-manager/test-harness.sh`
  - `bootstrap.sh`
  - `install.sh`
  - `.github/workflows/ci.yml`
  - `.github/workflows/release.yml`
  - `scripts/package.py`
  - تست‌های Python زیر `tests/`

**هدف:** حذف باگ‌های قطعی، مخصوصاً silent failure، از بین بردن مسیرهای ناامن هنگام خطا، حفظ سازگاری نصب و به‌روزرسانی، و جلوگیری از انتشار نسخه‌ای که تست‌هایش شکست خورده است.

قواعد غیرقابل مذاکره:
1. کد را از ابتدا بازبینی کن. فرض نکن مواردی که در این پرامپت نیامده‌اند سالم‌اند.
2. تغییرات را در branch کاری جدا یا pull request انجام بده، اگر محیطت اجازه می‌دهد. تغییرات نامرتبط را وارد نکن.
3. **تگ یا Release موجود `v1.8.4` را جابه‌جا، حذف، force-push یا بازنویسی نکن.** برای اصلاحات، commit جدید بساز. Release جدید را فقط بعد از سبز شدن تمام بررسی‌ها و مطابق سیاست نسخه‌بندی مخزن منتشر کن؛ در غیر این صورت صرفاً فایل‌های لازم و دستور انتشار پیشنهادی را آماده کن.
4. هیچ اسکریپت نصب، حذف، `purge`، تغییر سرویس یا دستور تغییردهنده‌ای را روی سرور production اجرا نکن. آزمایش عملیاتی باید در VM/container ایزوله یا با mock و مسیرهای موقت باشد.
5. هیچ secret واقعی، token، password، private key، فایل `.env` یا backup حساس را در log، تست، diff یا خروجی نهایی نگذار.
6. وقتی عملیاتی شکست خورد، کد خروجی غیرصفر و پیام صریح برگردان. از `|| true` یا `except: pass` برای پنهان کردن خطاهای مهم استفاده نکن. فقط خطاهای واقعاً اختیاری را نادیده بگیر و دلیلش را کامنت کن.
7. هیچ‌وقت برای گذراندن تست، assertion را حذف/ضعیف نکن، تست را skip نکن یا رفتار مورد انتظار را به رفتار معیوب تغییر نده. اگر تست نادرست بود، خود تست و علت نادرستی را اصلاح کن.
8. همهٔ ورودی‌ها و خروجی‌ها باید امن و قابل تکرار باشند. اصلاح باید برای نصب جدید و ارتقای نصب‌های موجود هم کار کند، نه فقط روی ماشین توسعه‌دهنده.

---

## 1) اول خط پایه را تثبیت کن

قبل از ویرایش:

- وضعیت git، commit فعلی، فهرست فایل‌ها و وضعیت فایل‌های تغییریافته را ثبت کن.
- workflowهای CI و Release، log و نام دقیق job و step شکست‌خورده را بخوان.
- کل repository را برای الگوهای زیر جست‌وجو کن و هر مورد را بررسی کن:
  - write مستقیم روی state/config و استفاده از فایل موقت بدون check
  - `|| true`، `2>/dev/null`، `except Exception: pass` در مسیر حساس
  - `log "...shod"` یا پیام موفقیت پس از فرمانی که exit code آن کنترل نشده
  - `sed -i` با مقدار یا الگوی ساخته‌شده از ورودی کاربر
  - عملیات فایل در `/etc`, `/usr/local`, `/opt`, `/run`, `/var/backups` هنگام تست
  - `systemctl`, `nginx`, `apt-get`, `certbot`, `ssh`, `scp`, `tar`, `unzip`, دانلود Release
  - تمام مسیرهای `rth_with_lock`, `rth_state_tx`, `rth_commit_config`, update/rollback و audit log
- برای هر باگ قطعی، تست رگرسیون بنویس که قبل از اصلاح شکست بخورد یا نشان بدهد رفتار معیوب رخ می‌دهد. سپس اصلاح را پیاده‌سازی کن.

## 2) P0/P1: قفل‌گذاری باید واقعاً fail-closed باشد

### فایل‌ها

- `rathole-manager/rathole-manager/ratholectl`, تابع `rth_with_lock`
- `rathole-manager/rathole-manager/ratholenode`, تابع `rth_with_lock`
- `rathole-manager/rathole-manager/common.sh`, منطق قفل و commit فایل config
- هر تابع/مسیر دیگری که state، ports، node list، tokenها یا config را تغییر می‌دهد

### باگ شناخته‌شده

در هر دو CLI، اگر باز کردن فایل قفل با `exec 9>"$RTH_LOCK"` شکست بخورد، مسیر فعلی می‌تواند مستقیماً `"$@"` را اجرا کند. این یعنی دستور حساس بدون قفل اجرا می‌شود. این رفتار باید حذف شود، نه فقط log شود.

### الزامات اصلاح

1. اگر `flock` موجود است، باز کردن فایل قفل یا گرفتن قفل نباید شکست بخورد و بعد دستور بدون قفل اجرا شود. اگر فایل/دایرکتوری قابل بازشدن نیست یا timeout رخ می‌دهد، عمل باید متوقف شود، پیام قابل‌فهم بدهد و exit code غیرصفر برگرداند.
2. fallback مبتنی بر `mkdir` فقط زمانی مجاز است که `flock` واقعاً در دسترس نباشد، نه هنگامی که مسیر `flock` به‌دلیل permission، symlink یا خطای I/O شکست خورده است.
3. قفل باید در یک directory قابل‌اعتماد با permission درست قرار گیرد. از fallback ناامن به مسیر قابل‌نوشتن عمومی مانند `/tmp/ratholectl.lock` بدون مقابله با symlink/pre-creation و بررسی مالکیت اجتناب کن. اگر مسیر امن پیدا نشد، fail closed کن.
4. قفل در همهٔ exit pathها آزاد شود. fallback دایرکتوری باید cleanup امن داشته باشد و با stale lock برخورد حساب‌شده‌ای کند. صرفاً با توجه به سن directory آن را حذف نکن، چون ممکن است عملیات زنده باشد.
5. برای CLI panel و node سیاست واحد، پیام خطا و semantics یکسان وجود داشته باشد.
6. هر مسیر تغییر state/config باید زیر همان قفل منطقی اجرا شود. read-modify-write نباید بین lockها پراکنده باشد یا یک mutation مسیر جایگزین بی‌قفل داشته باشد.
7. verify کن timeout عدد معتبر مثبت باشد؛ مقادیر غیرعددی/صفر/منفی نباید باعث busy loop یا رفتار غیرمنتظره شوند.
8. `rth_commit_config` باید lock timeout، شکست `mv`، شکست permission و شکست staging را درست گزارش کند. شکست chmod برای secrets/config باید در مسیر حساس بی‌صدا نادیده گرفته نشود، مگر اینکه دلیل قابل‌توجیهی داشته باشد.

### تست‌های اجباری قفل

- `flock` واقعی را با پردازش پس‌زمینه‌ای روی همان فایل قفل نگه دار و مطمئن شو CLI پس از timeout **بدون اجرای فرمان هدف** متوقف می‌شود.
- حالت بازنشدن فایل قفل را شبیه‌سازی کن؛ بررسی کن command اجرا نشده، state تغییر نکرده و stderr/log شامل دلیل شکست است.
- مسیر fallback `mkdir` را جداگانه با mock/path ایزوله تست کن.
- دو یا چند mutation هم‌زمان را اجرا کن و صحت state، unique بودن پورت‌ها و عدم lost update را assert کن.
- مطمئن شو تست‌ها به قفل واقعی سیستم میزبان یا مسیرهای `/run` و `/etc` دست نمی‌زنند.

---

## 3) P0/P1: Test Harness باید کاملاً ایزوله باشد

### فایل

`rathole-manager/rathole-manager/test-harness.sh`

### باگ شناخته‌شده

تست فعلی lock timeout directory به نام `${RTH_LOCK}.d` می‌سازد؛ اما وقتی `flock` نصب است، پیاده‌سازی اصلی فایل قفل را قفل می‌کند، نه آن directory. بنابراین تست، lock مورد انتظار را واقعاً نگه نمی‌دارد و شکست/نتیجهٔ آن گمراه‌کننده می‌شود.

همچنین `ensure_stream_include()` به‌طور پیش‌فرض `/etc/nginx/nginx.conf` را انتخاب می‌کند. در لاگ CI خطای permission برای فایل واقعی دیده شده است. تست نباید به config واقعی سیستم دست بزند.

### الزامات

1. تمام فایل‌های آزمایشی باید داخل `$ROOT` موقت ساخته شوند، از جمله `STATE`, فایل‌های TOML، env، سرویس‌ها، `NGINX_MAIN_CONF`, `NGINX_CONF`, `STREAM_CONF`, lockها، inventory و configهای hub.
2. برای هر مسیر واقعی، environment override یا dependency injection تمیز اضافه کن. اگر override فعلی وجود ندارد، با تغییر کوچک و قابل‌نگهداری اضافه‌اش کن، بدون تغییر ناخواستهٔ default production.
3. در تست `ensure_stream_include`, `NGINX_MAIN_CONF` را صریحاً به فایل `$ROOT/etc/nginx/nginx.conf` تنظیم کن. Assert کن هیچ فایل خارج `$ROOT` تغییر نکرده است.
4. commandهای خارجی خطرناک مانند `systemctl`, `nginx`, `apt-get`, `dpkg`, `certbot`, `ssh`, `scp` را با stub/mock کنترل کن. تست harness نباید به root نیاز داشته باشد و نباید چیزی را روی ماشین میزبان نصب، حذف، restart یا reload کند.
5. تست قفل `flock` باید فایل واقعی قفل را از یک process دیگر نگه دارد. برای fallback `mkdir` تست جدا داشته باش.
6. روی شکست عملیات، state قبل و بعد را مقایسه کن تا ثابت شود JSON/config ناقص یا نیمه‌نوشته نمی‌شود.
7. خلاصهٔ تست باید تعداد PASS/FAIL واقعی را گزارش دهد و با یک test fail، exit code کلی حتماً غیرصفر باشد.
8. تست باید در GitHub Ubuntu runner و در محیط‌های توسعهٔ پشتیبانی‌شده قابل‌اجرا باشد. وابستگی‌های اختیاری را آشکارا تشخیص بده؛ به‌جای skip خاموش، دلیل skip را چاپ کن.

**شرط قبولی:** اجرای test harness حتی با permission بالا نباید بتواند `/etc/nginx/nginx.conf` یا دیگر فایل‌های host را تغییر دهد.

---

## 4) P0/P1: Nginx و مسیر regenerate نباید موفقیت جعلی گزارش کنند

### فایل

`rathole-manager/rathole-manager/ratholectl`

### توابع/مسیرها

- `ensure_stream_include()`
- `gen_stream_conf()`
- `gen_nginx_conf()`
- `regenerate()`
- عملیات Game/SNI و هر actionی که config Nginx را تغییر می‌دهد

### باگ‌های شناخته‌شده

- `ensure_stream_include()` چند خطای `mkdir`, `cp` و نوشتن فایل را با `|| true` نادیده می‌گیرد و حتی پس از شکست می‌تواند پیام موفقیت چاپ کند.
- اگر یک `stream {}` از قبل در `nginx.conf` وجود داشته باشد، کد فعلی صرفاً هشدار می‌دهد و `return 0` می‌کند، بدون آنکه include لازم را اضافه کند. این مسیر نباید ادامهٔ موفقیت‌آمیز ساخت Game/SNI را وانمود کند.
- در `regenerate()` اگر هم `systemctl reload nginx` و هم `systemctl restart nginx` شکست بخورند، کد همچنان `nginx reload shod` را چاپ می‌کند.
- شکست `nginx -t` یا reload باید به caller منتقل شود؛ در غیر این صورت لایهٔ بالاتر می‌تواند عملیات را موفق اعلام کند.

### الزامات اصلاح

1. `ensure_stream_include()` باید idempotent باشد: include تکراری اضافه نکند و وضعیت موجود را درست تشخیص بدهد.
2. اگر `stream {}` از قبل موجود است، یا include را به همان بلاک به شکل امن و دقیق اضافه کن، یا قبل از تغییر state با خطای واضح و exit code غیرصفر عملیات را رد کن. هشدار و سپس `return 0` مجاز نیست.
3. اگر نصب `libnginx-mod-stream` لازم است، نتیجهٔ نصب را بررسی کن. اگر نصب شکست خورد، در صورت نیاز بودن قابلیت، fail closed کن؛ شکست را به `|| true` تبدیل نکن.
4. قبل از تغییر فایل live، backup معتبر در directory امن بساز. staging و جایگزینی تا حد امکان atomic باشند. شکست backup باید قبل از write به فایل اصلی متوقف شود.
5. بعد از تولید config، `nginx -t` و سپس reload را اجرا و exit code هر دو را بررسی کن. اگر reload شکست خورد، restart را امتحان کن؛ اگر هر دو شکست خوردند، پیام موفقیت نده و exit code غیرصفر برگردان.
6. اگر config جدید نامعتبر یا فعال‌سازی آن شکست خورده است، تلاش برای بازگرداندن تمام فایل‌های درگیر (HTTP و stream) به آخرین نسخهٔ known-good انجام بده. بعد از rollback دوباره `nginx -t` را اجرا کن. اگر rollback یا reload نسخهٔ قبلی هم شکست خورد، دقیقاً گزارش بده که وضعیت نیازمند مداخلهٔ دستی است.
7. اگر state پیش از regenerate تغییر کرده، خطای اعمال config نباید به ظاهر یک موفقیت کامل تبدیل شود. یا state را به snapshot قبلی برگردان، یا عملیات را با exit code غیرصفر و وضعیت partial failure کاملاً مشخص کن. برای هر فرمان رفتار ثابت تعریف کن.
8. از فایل موقت با permission محافظت‌شده استفاده کن و هر فایل موقت در تمام exit pathها پاک شود.
9. log موفقیت فقط پس از تأیید عمل واقعی چاپ شود. تست باید assert کند که پیام success هنگام fail شدن reload وجود ندارد.

### تست‌های Nginx اجباری

- نصب/افزودن Game وقتی `nginx.conf` بلاک `stream` ندارد.
- حالت `stream {}` موجود از قبل.
- include از قبل موجود است.
- `cp`, نوشتن فایل، `nginx -t`, reload و restart جداگانه fail می‌شوند.
- حالت rollback موفق و rollback ناموفق.
- در هر حالت failure، command exit code غیرصفر داشته باشد و گزارش وضعیت واقعی را بدهد.
- هیچ تستی به Nginx یا systemd واقعی متصل نشود.

---

## 5) P1: همهٔ mutationهای state باید transactional و اعتبارسنجی‌شده باشند

### فایل

`rathole-manager/rathole-manager/ratholectl`

### باگ شناخته‌شده

بخش Game هنوز مستقیماً از این الگو استفاده می‌کند:

```bash
jq ... "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
```

و بعد پیام موفقیت می‌دهد. در این صورت `jq` یا `mv` ممکن است شکست بخورد اما دستور بالاتر همچنان موفق به نظر برسد. درحالی‌که `rth_state_tx()` برای همین هدف ساخته شده است.

### الزامات

1. `cmd_game_add()` و `cmd_game_rm()` را به `rth_state_tx()` منتقل کن.
2. تمام repository را برای direct writeهای مشابه روی `STATE`, inventory و configها جست‌وجو کن و هر mutation را به مسیر مشترک atomic/validated منتقل کن یا برای آن دلیل فنی روشن مستند کن.
3. الگوی استاندارد mutation:
   - lock گرفته شود؛
   - فایل ورودی معتبر بررسی شود؛
   - داده در temp امن و هم‌فایل‌سیستم نوشته شود؛
   - خروجی JSON یا قالب config اعتبارسنجی شود؛
   - `mv`/`os.replace` کنترل شود؛
   - permission مقصد بررسی شود؛
   - فقط بعد از موفقیت، پیام success چاپ شود.
4. روی شکست `jq`, `mv`, permission یا دیسک پر، نسخهٔ قبلی state باید حفظ شود و هیچ فایل ناقص به‌عنوان نسخهٔ اصلی باقی نماند.
5. برای تمام actionهای add/remove/rename/token rotation، تست‌های success و failure اضافه کن.
6. state file در هیچ لحظه‌ای world-readable نشود. دایرکتوری حاوی tokenها، API token و کلیدهای حساس باید permission مناسب داشته باشد.

---

## 6) P1: همهٔ موفقیت‌های systemd باید واقعاً بررسی شوند

کل repository را بررسی کن و هر جا خروجی موفقیت بدون کنترل exit code/health status چاپ شده، اصلاح کن. حداقل موارد شناخته‌شده:

- `ratholectl` بخش `restart` و `enable`
- `ratholectl` بخش `fakeweb start`
- `ratholectl` بخش `hub on` و تغییر `listen_port`
- `ratholenode` تمام مسیرهای enable/restart مربوط به client، KCP، backhaul، fake web، upstreamها، watchdog و adaptive
- `update.sh` در `restart_services()`, `rollback_to()` و `health_check()`
- `install-panel.sh` و `install-node.sh` هنگام فعال‌سازی سرویس‌ها
- `uninstall-panel.sh` و `uninstall-node.sh` هنگام reload و cleanup

الزامات:

1. هر `systemctl restart`, `reload`, `start`, `enable --now`, `daemon-reload` که برای موفقیت عملیات حیاتی است، result آن بررسی شود.
2. برای سرویس اصلی، علاوه بر return code، `systemctl is-active --quiet` یا health check معادل اجرا شود. صرف موفق بودن دستور `enable` تضمین نمی‌کند سرویس active است.
3. خطای start/restart باید نام unit و راه بررسی log مثل `journalctl -u UNIT -n 30 --no-pager` را نشان دهد.
4. پیام‌هایی مانند «فعال شد»، «Restart شد»، «کامل شد» فقط بعد از تأیید واقعی چاپ شوند.
5. اگر بعضی سرویس‌های جانبی اختیاری‌اند، وضعیت آنها صریحاً به‌عنوان warning/partial failure ثبت شود و خروجی کلی فقط طبق سیاست documented تعیین شود؛ خطاهای بحرانی نباید به warning بی‌اثر تقلیل یابند.
6. در update/rollback، اگر restart یا health check شکست خورد، نتیجهٔ نهایی nonzero باشد؛ گزارش «rollback موفق» فقط وقتی درست است که سرویس‌ها و health check بعد از rollback سالم باشند.

---

## 7) P1: ورودی‌ها و فایل‌های env در `ratholenode` امن و دقیق نوشته شوند

### فایل

`rathole-manager/rathole-manager/ratholenode`

### موارد بررسی

- `env_set()` در حوالی خط 451
- تابع‌های مشابه که از `sed -i "s#^KEY=.*#KEY=VALUE#"` استفاده می‌کنند
- حذف خط‌ها با `sed -i "/^$name|/d"`
- نوشتن `services.conf`, `node.env`, upstream service configs, adaptive state و backhaul variables

### مشکل

مقدار ورودی داخل عبارت جایگزینی `sed` قرار می‌گیرد. کاراکترهایی مانند `&`, جداکننده، backslash یا newline می‌توانند مقدار را خراب کنند یا رکورد/تنظیمات دیگری را تغییر دهند. حتی در حالتی که injection کامل اتفاق نیفتد، می‌تواند یک تنظیم معتبر را بی‌صدا خراب کند.

### الزامات

1. تمام `sed -i`هایی که ورودی کاربر/شبکه را interpolate می‌کنند، بازبینی کن.
2. برای تغییر فایل‌های key-value یا pipe-delimited، تابع مشترک امن بساز که key را allowlist/regex validate کند و value را با روش امن، بدون ساختن expression شکننده، بنویسد.
3. CR/LF و کاراکترهایی را که در قالب هدف delimiter یا ساختار جدید می‌سازند، validate یا به‌درستی encode/reject کن.
4. فایل را در temp با permission امن بنویس، اعتبارسنجی کن و atomic replace انجام بده؛ خطای write باید nonzero باشد.
5. عملیات حذف باید exact-match باشد و نام سرویس نتواند regex یا الگوی sed را تغییر دهد.
6. بعد از write، مقدار خوانده‌شده را برای همان key بررسی کن و مطمئن شو کلیدهای دیگر دست‌نخورده‌اند.
7. ورودی‌های معتبر موجود را بی‌دلیل محدود نکن. اگر یک مسیر/hostname شامل کاراکتر قانونی است، آن را پشتیبانی کن یا خطای validation واضح بده.
8. تست رگرسیون برای `&`, `#`, `/`, `\`, whitespace، CR/LF و ورودی‌های خارج از allowlist اضافه کن.

---

## 8) P1: Hub، audit log و اطلاعات محرمانه

### فایل‌ها

- `rathole-manager/rathole-manager/ratholehub/hub.py`
- `rathole-manager/rathole-manager/ratholehub/hubcmds.py`
- UI و endpointهای مرتبط

### الزامات محرمانگی و صحت

1. تمام آرگومان‌های commandهایی که ممکن است token/key/password داشته باشند در `redact_cmd()` به‌شکل جامع redact شوند. به چند الگوی فعلی اکتفا نکن. همهٔ actionهای panel/node/upstream/backhaul/KCP/noise، `--token`, `--api-token`, `--password`, `--key` و secretهای positional را بررسی کن.
2. برای هر command حساس، تست بنویس که یک secret مشخص را به تابع redaction بدهد و ثابت کند secret در خروجی باقی نمانده است. تست علاوه بر وجود `***REDACTED***`، نبودن متن اصلی secret را assert کند.
3. audit log نباید password، token، private key، command قابل‌بازپخش حاوی secret یا request body حساس را ثبت کند. خطای نوشتن audit نباید secret را در error message چاپ کند.
4. file mode و directory mode برای config، inventory، audit و private keyها بررسی شود. برای فایل‌های موجود نیز اگر permission ناامن است، هنگام load/save به شکل امن اصلاح یا خطا گزارش شود؛ `chmod` حیاتی را به‌طور بی‌صدا نادیده نگیر.
5. `save_json()` باید در صورت شکست نوشتن یا `os.replace`، فایل اصلی را سالم نگه دارد و error را به لایهٔ بالاتر منتقل کند. نام فایل temp در برابر تداخل thread/process مقاوم باشد. mutation هم‌زمان config/inventory، atomic و lock شده باشد.
6. مسیر production در نبود config واقعی یا با credentials پیش‌فرض ناامن نباید با دسترسی مدیریتی باز شود. رفتار production و `MOCK` کاملاً جدا و تست‌شده باشد.
7. محدودیت تلاش ورود (rate limit) را بررسی کن. کد فعلی از `X-Real-IP` برای تعیین IP استفاده می‌کند؛ این هدر فقط وقتی قابل‌اعتماد است که درخواست از reverse proxy مورد اعتماد رسیده باشد. درخواست مستقیم نباید بتواند با جعل هدر IP محدودیت را دور بزند. یا فقط socket peer IP را به‌کار ببر، یا trusted-proxy را صریحاً پیکربندی و enforce کن.
8. احراز هویت تمام endpointهای خصوصی، cookie flags، session expiry، timing-safe comparison و مسیرهای `/hub/api` را با تست بررسی کن. endpoint عمومی health/UI باید هیچ config، inventory یا secret را افشا نکند.
9. خطاهای JSON خراب، config خراب، inventory با schema نامعتبر، permission denied و timeout SSH باید به پاسخ خطای قابل فهم منجر شوند، نه دادهٔ پیش‌فرضی که عملیات را موفق جلوه دهد.
10. خروجی لاگ‌ها و tracebackها نباید حاوی password، token، private key یا اطلاعات حساس سرور باشد.

### تست‌های Hub اجباری

- brute-force/rate-limit با IP واقعی و هدر `X-Real-IP` جعلی
- token و password صحیح/غلط، session منقضی‌شده، config missing/insecure
- درخواست JSON خراب/بسیار بزرگ/نوع JSON اشتباه
- چند mutation هم‌زمان برای inventory/config
- redact برای تمام commandهای حساس
- شکست نوشتن config و audit
- timeout و failure در SSH/provision بدون باقی‌ماندن وضعیت `active` در inventory

---

## 9) P1: Update، snapshot و rollback قابل اتکا باشند

### فایل

`rathole-manager/rathole-manager/update.sh`

### موارد الزامی

1. `make_snapshot()` اگر هیچ فایل لازم برای backup پیدا نکرد، نباید با exit code صفر و رشتهٔ خالی برگردد تا update به‌طور عادی ادامه پیدا کند. وقتی rollback فعال است، نبود snapshot معتبر باید update را **پیش از اعمال تغییرات** متوقف کند.
2. اگر کاربر صریحاً rollback خودکار را غیرفعال کرده، رفتار باید در help/documentation روشن باشد. این گزینه نباید به‌صورت ناخواسته snapshot یا safety check ضروری را از بین ببرد.
3. backupها حاوی token/cert/private key هستند؛ دایرکتوری و فایل backup باید permission محدود داشته باشند و retention نباید snapshot فعال/در حال ساخت را حذف کند.
4. `rollback_to()` تنها وقتی موفقیت گزارش دهد که archive بررسی، استخراج، سرویس‌ها reload/restart و health check نهایی پاس شده باشد. خطای restart فعلی نباید با `|| true` به rollback موفق تبدیل شود.
5. archive را قبل از extract اعتبارسنجی کن: path مطلق، component واقعی `..`, symlink/hardlink خطرناک و مسیرهایی که بیرون از مقصد می‌روند را رد کن. بررسی با grep بیش‌ازحد کلی یا parsing شکنندهٔ نام‌های دارای فاصله، جای اعتبارسنجی درست archive را نمی‌گیرد.
6. برای `tar`، owner و permissionهای archive نباید بتوانند فایل‌های حساس سیستم را ناامن کنند. فقط snapshot مورد انتظار خود پروژه را بازیابی کن و path list را کنترل کن.
7. عملیات update باید backup، apply، health check و rollback را با exit codeهای دقیق اجرا کند. اگر apply نصفه ماند، log بگو کدام نقش‌ها و سرویس‌ها تغییر کردند.
8. تست برای backup ناقص/خالی، permission denied، archive خراب، archive با path traversal، شکست restart، health check fail و rollback fail اضافه کن.
9. از اجرای `systemctl` واقعی در تست update جلوگیری کن. از stub قابل‌کنترل استفاده کن.

---

## 10) P1: امنیت استخراج bundle و فرایند نصب

### فایل‌ها

- `bootstrap.sh`
- `install.sh`
- `scripts/package.py`
- `rathole-manager/rathole-manager/install-panel.sh`
- `rathole-manager/rathole-manager/install-node.sh`
- اسکریپت‌های نصب Hub و update

### الزامات

1. `bootstrap.sh` هنگام استخراج ZIP/TAR نباید به فایل‌های absolute، path traversal، symlink/hardlink خطرناک یا filenameهای مبهم اجازه دهد. بررسی فعلی ZIP که خروجی `unzip -l | awk '{print $4}'` را می‌خواند در حضور filename دارای فاصله شکننده است. از listing قابل‌اعتماد و اعتبارسنجی component-based استفاده کن.
2. فایل نصب/استخراج باید در temp directory با permission `0700` باشد و در همهٔ exit pathها پاک شود. آرشیو فقط بعد از verification استخراج شود.
3. اگر checksum برای Release مورد انتظار است، شکست یا نبود آن نباید بی‌سروصدا به ادامهٔ نصب منجر شود. سازگاری با نسخه‌های قدیمی را آگاهانه حل کن؛ مثلاً policy نسخه‌بندی‌شده داشته باش، خطای واضح بده و هیچ‌وقت checksum نامعتبر را قبول نکن.
4. نصب تک‌خطی `curl | sudo bash` باید تمام خطاهای download، extraction، dependency، permission و اجرای نصب را با exit code درست نشان دهد.
5. `install_prereqs()` نباید پس از شکست manager package silently ادامه دهد و وانمود کند ابزارها نصب شده‌اند. بعد از هر package manager، وجود ابزارهای مورد نیاز را verify کن.
6. اگر install یا update نیمه‌کاره ماند، نسخهٔ قبلی و configها تا حد ممکن سالم بمانند؛ فایل‌های حساس یا unitهای نیمه‌ساخته باقی نمانند.
7. مسیرهای `--release`, `--version`, `--beta`, `RATHOLE_RELEASE`, `RATHOLE_GH` را validate کن. ورودی tag/slug نباید path traversal یا URL injection ایجاد کند.
8. قبل از کپی bundle، ساختار و وجود فایل‌های لازم را verify کن. بعد از نصب، نسخه‌ها و executableها و فایل‌های Hub/UI را check کن.
9. `scripts/package.py` نباید فایل‌های مخفی حساس، state سرور، کلید/backup، cache یا artifactهای محلی را bundle کند. ساختار archive باید با `bootstrap.sh` و `find_root()` سازگار باشد.
10. تست install/bootstrap فقط در sandbox اجرا شود. هر گونه remove/purge باید در tests صریحاً mock شده باشد.

---

## 11) P1: GitHub Actions و Release باید مانع انتشار نسخهٔ قرمز شوند

### فایل‌ها

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `scripts/package.py`
- `rathole-manager/rathole-manager/common.sh` (نسخهٔ `MANAGER_VERSION`)

### وضع موجودی که باید اصلاح شود

Release `v1.8.4` منتشر شده است، با این‌که CI همان commit شکست خورده بود. Workflow انتشار فعلی مستقلاً package و release می‌سازد و تضمین نمی‌کند تست‌های کامل قبلاً پاس شده باشند.

در `workflow_dispatch` نیز عبارت منطقی شبیه `${{ github.ref_name || inputs.tag_name }}` ممکن است ورودی `tag_name` را نادیده بگیرد چون `github.ref_name` هنگام اجرای دستی روی `main` هم مقدار دارد.

### الزامات

1. Release job فقط بعد از موفقیت تمام gateهای لازم اجرا شود: shell syntax، Python syntax/unit tests، test harness، package structure و checksum validation.
2. چون CI فعلی روی push تگ‌ها اجرا نمی‌شود، workflow انتشار باید همین تست‌ها را روی **همان commit/tag** اجرا کند، یا از reusable workflow مشترک استفاده کند. صرفاً به سبز بودن قبلی `main` اعتماد نکن.
3. در `workflow_dispatch`، `tag_name` واقعاً ref مورد checkout و release باشد. ورودی را اعتبارسنجی کن، وجود tag را verify کن و اجازه نده workflow روی `main` package بسازد اما آن را با نام tag دیگری منتشر کند.
4. انتشار تگ pushشده باید checkout همان tag/commit را انجام دهد و assetها دقیقاً از همان checkout ساخته شوند.
5. `MANAGER_VERSION`, tag, release name, version output و metadata بسته باید هماهنگ باشند. اگر version bump لازم است، آن را یکنواخت و مستند انجام بده.
6. assetهای مورد انتظار Release:
   - `bootstrap.sh`
   - `install.sh`
   - `rathole-manager.zip`
   - `SHA256SUMS`
7. checksumها باید پس از build نهایی همان assetها ساخته شوند و CI قبل از upload آنها را verify کند. نام فایل‌ها در checksum و Release یکسان باشد.
8. اگر یک Release با همان tag از قبل وجود دارد، رفتار workflow باید امن و قابل پیش‌بینی باشد؛ نه تکرار ناخواسته، نه جایگزینی silent و نه انتشار assetهای commit متفاوت با همان tag.
9. `workflow_dispatch` باید از انتشار ناخواسته جلوگیری کند و در صورت missing tag یا test failure nonzero شود.
10. branch protection/required status checks را مستند کن، ولی خودکار تنظیمات repository را بدون مجوز لازم تغییر نده.
11. Release notes نباید قابلیت یا «production-ready» بودن چیزی را ادعا کنند که تست واقعی یا کد موجود اثبات نکرده است.

---

## 12) بررسی تکمیلی fail-silent در کل پروژه

فقط موارد فهرست‌شده را اصلاح نکن. کل مخزن را از نظر این الگوها audit و اصلاح کن:

- `set -e` را به‌عنوان جایگزین بررسی دستی نتیجهٔ دستورات در if/pipe/subshell فرض نکن. `set -e` semantics پیچیده دارد و جایگزین کنترل صریح نیست.
- pipelineهایی مثل `command | grep | head` را بررسی کن؛ در command substitution، `set -e` و `pipefail` ممکن است نتیجه را غیرمنتظره کنند. نبود نتیجهٔ طبیعی نباید بی‌دلیل اسکریپت را terminate کند و failure واقعی نباید بلعیده شود.
- با `2>/dev/null` خطای حیاتی را مخفی نکن. خطاهای اختیاری را نیز با پیام warning مشخص کن.
- پیام‌های success را قبل از تأیید خروجی فرمان یا health check چاپ نکن.
- در Python، هر `except Exception: pass` را از نظر حساس بودن operation بررسی کن. برای config/state/security/network mutation خطا را به caller برگردان یا log امن کن.
- هیچ مسیر حساس در اثر malformed JSON/config به empty/default state برنگردد و سپس عملیات نوشتن انجام ندهد.
- timeoutها، retryها و mirror fallbackها باید محدود باشند؛ بعد از exhausted retries شکست آشکار باشد.
- download باید HTTP error را رد کند و فایل خالی/HTML error page را به‌عنوان ZIP/binary قبول نکند.
- `rathole` executable واقعی که نصب و اجرا می‌شود باید همان باینری‌ای باشد که availability/version check کرده‌ای.
- ورودی‌های host, domain, port, SNI, path, token, service name و SSH options باید allowlist validation متناسب با context داشته باشند.
- بررسی کن permissionهای فایل‌های generated configs، private key، TLS key، token state، backupها، service units و scripts صحیح باشند.
- بررسی کن shell commandها ورودی user را به‌صورت رشتهٔ خام اجرا نکنند. از argv list برای subprocess Python و quoting دقیق در shell استفاده کن.
- بررسی کن وضعیت Hub inventory فقط پس از provision موفق `active` شود و روی مرحلهٔ نیمه‌کاره inventory و authorized_keys به شکل سازگار مدیریت شوند.
- هر جا رفتار جزئی و شکست جزئی ممکن است، final status باید دقیق باشد و recovery steps بدهد.

---

## 13) نسخه‌بندی و سازگاری

1. رفتار commandهای عمومی و flagهای فعلی را حفظ کن مگر این‌که رفتار فعلی ناامن/معیوب باشد. هر breaking change را واضح مستند کن.
2. قبل از تغییر schema فایل‌های state/config، migration سازگار با نسخه‌های نصب‌شده بساز و روی fixture نسخهٔ قبلی تست کن.
3. آپدیت باید روی نصب فعلی panel، node و Hub، از جمله فایل‌های config موجود، کار کند. در محیط تست دست‌کم migration از schema قدیمی را آزمایش کن.
4. اگر اصلاحات به نسخهٔ جدید نیاز دارند، version bump را هماهنگ انجام بده. tag و Release `v1.8.4` موجود را بازنویسی نکن.
5. README یا راهنمای نصب را در صورت تغییر رفتار/پیش‌نیاز/فرمان‌ها به‌روز کن.

---

## 14) تست‌های نهایی اجباری و gate انتشار

تمام موارد زیر را تا حد ممکن اجرا کن و نتیجهٔ واقعی را گزارش بده. اگر موردی به دلیل محیط قابل اجرا نیست، آن را صریحاً **Not Run** علامت بزن، دلیل بده و ادعای قبولی نکن.

1. `bash -n` برای تمام shell scripts و CLIها.
2. ShellCheck روی اسکریپت‌های shell (در صورت در دسترس بودن، یافته‌های مهم را اصلاح کن؛ اگر lint عمداً محدود شده دلیل را بنویس).
3. Python compile/syntax check برای همهٔ ماژول‌ها.
4. Python unit tests با همهٔ نسخه‌های Python تعیین‌شده در CI.
5. test harness کامل، شامل lock، state transaction، redaction، Nginx fake config و failure injection.
6. concurrent mutation test برای افزودن چند node و unique portها.
7. Hub security tests برای auth/rate limit/redaction/permission/atomic save.
8. test update/rollback با mock برای service failure، empty snapshot و archive نامعتبر.
9. package build با `scripts/package.py` و بررسی محتوای zip/نام فایل‌ها/نبود artifact حساس.
10. verification واقعی `SHA256SUMS`.
11. تست logic انتخاب tag در Release workflow برای push tag و `workflow_dispatch`.
12. GitHub Actions کامل از commit نهایی باید سبز باشد. اگر به GitHub access نداری، صریحاً بگو workflow نهایی هنوز در GitHub تأیید نشده است.
13. هیچ تستی نباید به سرویس‌های واقعی میزبان وصل شود یا فایل خارج sandbox را تغییر دهد.

### Failure injection حداقل

- `flock` گرفته شده و timeout
- بازنشدن فایل قفل
- `jq` با exit code غیرصفر
- `mv`/`os.replace` با permission denied
- دیسک یا فایل staging غیرقابل‌نوشتن
- `nginx -t` fail
- Nginx reload و restart هر دو fail
- `systemctl start/restart` fail
- config JSON خراب یا schema اشتباه
- audit log غیرقابل‌نوشتن
- update بدون snapshot معتبر
- backup tar/zip خراب یا traversal
- download 404، timeout، فایل صفر بایت یا checksum mismatch
- SSH timeout و provision نیمه‌کاره
- مقدار env حاوی delimiter یا کاراکتر حساس برای sed

---

## 15) معیار پذیرش نهایی

کار فقط وقتی «تمام» محسوب می‌شود که:

- [ ] هیچ مسیر اجرای بی‌قفل به علت failure در بازکردن فایل lock باقی نمانده باشد.
- [ ] timeout قفل واقعاً mutation را متوقف کند و state بدون تغییر بماند.
- [ ] test harness هیچ فایل host را لمس نکند و CI lock test درست و قابل اعتماد باشد.
- [ ] Nginx existing stream block و include به‌شکل امن مدیریت شوند.
- [ ] خطای config test/reload/restart به exit code ناموفق برسد و پیام موفقیت جعلی تولید نشود.
- [ ] هیچ mutation شناخته‌شده‌ای مثل Game از direct non-atomic state write استفاده نکند.
- [ ] همهٔ مسیرهای حساس systemd و update/rollback status را درست منتقل کنند.
- [ ] env/config writeها ورودی را خراب نکنند یا رکورد دیگری را تغییر ندهند.
- [ ] هیچ token/password/private key در audit/log/test output افشا نشود.
- [ ] snapshot نامعتبر/خالی در حالت rollback-enabled اجازهٔ update ندهد.
- [ ] Release workflow تست‌ها را روی همان tag/commit اجرا کرده باشد و manual dispatch تگ واردشده را درست استفاده کند.
- [ ] package و checksum درست باشند و همهٔ تست‌های قابل‌اجرا سبز باشند.
- [ ] مستندات نصب و upgrade با رفتار کد یکسان باشد.

---

## 16) قالب گزارش نهایی که باید تحویل بدهی

در پایان یک گزارش کوتاه اما دقیق بده:

1. **خلاصه:** وضعیت نهایی را صادقانه با یکی از این‌ها مشخص کن: `PASS`, `PARTIAL`, `BLOCKED`.
2. **Commit/PR:** hash و لینک، branch و فایل‌های اصلی تغییرکرده.
3. **باگ‌های رفع‌شده:** برای هر مورد path/function، علت و اصلاح.
4. **تست‌ها:** دستور، نتیجه، تعداد pass/fail و در صورت شکست خلاصهٔ log. بین `Passed`, `Failed`, `Not Run` تفاوت واضح بگذار.
5. **CI و Release:** لینک مستقیم workflow runها؛ بگو CI روی کدام SHA اجرا شده و آیا Release gate همان SHA/tag را پوشش داده است.
6. **سازگاری:** نسخه‌های قبلی/config schema/ارتقا چطور پشتیبانی شده‌اند.
7. **ریسک‌های باقی‌مانده:** هر چیزی که هنوز end-to-end تست نشده یا به محیط واقعی نیاز دارد.
8. **Release readiness:** صریح بگو آیا نسخه برای release آماده است یا نه. سبز بودن syntax check به‌تنهایی کافی نیست.

**مهم:** فقط گزارش یا TODO تحویل نده. کد و تست‌ها را واقعاً اصلاح کن. اگر به یک مانع واقعی برخورد کردی، کارهای قابل‌انجام را ادامه بده و فقط همان قسمت را `BLOCKED` اعلام کن. چیزی را که اجرا نکرده‌ای، به‌عنوان پاس‌شده گزارش نکن.
