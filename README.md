# 🚀 Rathole Tunnel Manager (سامانه تانل معکوس ضدتحریم و گیمینگ)

سیستم جامع و ماژولار مدیریت تانل معکوس پایدار و پرسرعت بین سرور ایران و سرور خارج، مجهز به دفاع فعال در برابر فیلترینگ و اسکنرهای هوشمند، پشتیبانی از پروتکل‌های وب‌گردی **WebSocket (WS)** و نسل نوین **XHTTP (SplitHTTP)**، حالت **گیمینگ فوق‌سریع لایه ۴ (0-RTT Vision + UDP FullCone)** و مهارکننده پکت‌لاس **KCP (UDP+FEC)** روی پورت ۴۴۳.

کاملاً بهینه‌سازی شده برای استقرار آسان در کنار پنل محبوب گرافیکی **سنایی ([3x-ui](https://github.com/MHSanaei/3x-ui))** و مدیریت متمرکز کاربران بدون نیاز به تغییر مستقیم هسته Xray.

---

## 📚 فهرست راهنماهای اختصاصی (Documentation)

| راهنما | فایل / مسیر | محتوا و کاربرد |
| :--- | :--- | :--- |
| ⚡ **[راهنمای نصب سریع با گیت‌هاب](rathole-manager/docs/GITHUB_INSTALL_GUIDE.fa.md)** | `rathole-manager/docs/GITHUB_INSTALL_GUIDE.fa.md` | نصب تک‌خطی از گیت‌هاب، پیکربندی اینباندهای 3x-ui، آپدیت آنی |
| 📦 **[راهنمای نصب دستی و آفلاین](rathole-manager/docs/MANUAL_INSTALL_GUIDE.fa.md)** | `rathole-manager/docs/MANUAL_INSTALL_GUIDE.fa.md` | نصب با فایل زیپ/آفلاین بدون وابستگی به اینترنت، مدیریت با اسکریپت |
| 🧠 **[مرجع جامع فنی و معماری](rathole-manager/docs/SETUP_AND_GAMING_GUIDE.fa.md)** | `rathole-manager/docs/SETUP_AND_GAMING_GUIDE.fa.md` | معماری عمیق، ضدپروب Nginx، کانفیگ‌های پیشرفته Xray و تیونینگ سیستم |
| 🏗️ **[مستندات معماری و ترانزیت](rathole-manager/docs/)** | `rathole-manager/docs/` | دیاگرام‌های تفصیلی، مشخصات پروتکل‌های ترانزیت، هاب و ویکی کامل |

---

## ⚡ روش‌های نصب و راه‌اندازی (Installation)

### روش ۱: نصب تک‌خطی فوق‌سریع از گیت‌هاب (پیشنهادی)

#### ۱. سرور ایران (Panel / Hub):
```bash
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel
```
پس از نصب، گواهی SSL و پنل وب را فعال کنید:
```bash
# دریافت SSL رایگان Let's Encrypt:
sudo ratholectl cert iran.example.com admin@example.com

# بهینه‌سازی سرعت هسته لینوکس (BBR):
sudo ratholectl tune

# فعال‌سازی پنل مدیریت وب RatholeHub:
sudo ratholectl hub on 2087
```
🌐 پنل تحت وب ایران: `https://iran.example.com/hub/`

#### ۲. سرور خارج (Node) در کنار پنل ۳x-ui سنایی:
روی سرور خارج:
```bash
# ۱. نصب پنل سنایی (3x-ui)
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

# ۲. اتصال نود تانل معکوس به سرور ایران
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --node -- \
  --server iran.example.com:443 --name node1 --token YOUR_NODE_TOKEN --inbound-port 10001
```

---

### روش ۲: نصب از طریق کلون گیت‌هاب (برای توسعه‌دهندگان)

```bash
# کلون ریپازیتوری
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager
cd /root/rathole-manager

# سرور ایران:
sudo bash install-panel.sh

# سرور خارج:
sudo bash install-node.sh
```

---

## 🛡️ ویژگی‌های برجسته امنیتی و فنی

1. **دفاع فعال در برابر پروب و فیلترینگ (Active Probe Defense)**:
   - درخواست‌های کاوشگر فیلترچی و ربات‌های اسکنر پورت به جای ارورهای مشکوک ۵۰۲ یا بسته بودن پورت، وب‌سایت شرکتی مدرن فارسی با کد وضعیت `200 OK` دریافت می‌کنند.
   - جداسازی کامل و بدون بافر ترافیک واقعی WebSocket و XHTTP از ترافیک‌های کاوشگر.
2. **پشتیبانی کامل از XHTTP (SplitHTTP)**:
   - عبور استریم پیوسته با `chunked_transfer_encoding on` و حذف کامل بافرینگ برای عدم شناسایی توسط فایروال هوش مصنوعی.
3. **حالت گیمینگ بدون تاخیر (L4 SNI Passthrough 0-RTT)**:
   - عبور ترافیک مستقیم TCP/UDP بدون دخالت Nginx لایه ۷ با پروتکل `VLESS-Vision` و هندشیک رمزنگاری در سرور مقصد خارج.
4. **مهار پکت‌لاس با KCP / UDP+FEC روی پورت 443**:
   - شبیه‌سازی الگوی QUIC گوگل و ترمیم بسته‌های از دست رفته اینترنت بین‌الملل با الگوریتم Reed-Solomon.
5. **معماری فوق امنیتی (Fail-Closed & Hardened)**:
   - مجوزهای محدود `umask 077`، `0600` برای فایل‌ها و `0700` برای دایرکتوری‌ها.
   - قفل‌های تراکنشی اتمیک در نوشتن کانفیگ‌ها و state.
   - رمزنگاری پسورد پنل با الگوریتم امن **PBKDF2-HMAC-SHA256**.
   - حذف کامل و اتوماتیک اطلاعات حساس (توکن‌ها، پسوردها و کلیدها) از لاگ‌های ممیزی و خروجی‌های سیستم.
6. **بروزرسانی بدون قطعی (Zero-Downtime Reload)**:
   - بروزرسانی سریع تنظیمات با `git pull` بدون قطع شدن کانکشن کاربران آنلاین.

---

## 🛠️ دستورات پرکاربرد مدیریت سیستم (CLI)

```bash
# بررسی سلامت کامل سیستم و ارتباطات
sudo ratholectl doctor

# مشاهده وضعیت نودها و پورت‌های تانل
sudo ratholectl status

# افزودن یک نود جدید
sudo ratholectl add node2 10002

# دریافت توکن یک نود
sudo ratholectl token node2

# راه‌اندازی سرویس گیمینگ اختصاصی (لایه ۴)
sudo ratholectl game add game1 10003 game.example.com

# روشن کردن حالت ضد پکت‌لاس KCP روی پورت ۴۴۳
sudo ratholectl kcp on 443 balanced

# تولید مجدد کانفیگ‌ها و ریلود بدون قطعی
sudo ratholectl regen
```

---
*توسعه داده شده جهت ایجاد دسترسی پایدار، امن و پرسرعت به اینترنت آزاد.*
