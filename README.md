# 🚀 Rathole Tunnel Manager (پروژه تانل معکوس ضدتحریم و گیمینگ)

سیستم جامع مدیریت تانل معکوس پرسرعت و پایدار بین سرور ایران و سرور خارج، مجهز به دفاع فعال در برابر فیلترینگ هوشمند، پشتیبانی از پروتکل‌های وب‌گردی **WebSocket (WS)** و نسل نوین **XHTTP (SplitHTTP)**، حالت **گیمینگ فوق‌سریع لایه ۴ (0-RTT Vision + UDP FullCone)** و مهارکننده پکت‌لاس **KCP (UDP+FEC)** روی پورت ۴۴۳.

---

## 📚 فهرست راهنماهای اختصاصی (Documentation)

| راهنما | فرمت / موضوع | کاربرد |
| :--- | :--- | :--- |
| 📖 **[راهنمای نصب با گیت‌هاب](GITHUB_INSTALL_GUIDE.fa.md)** | `GITHUB_INSTALL_GUIDE.fa.md` | نصب سریع تک‌خطی از طریق مخزن، آپدیت آنی سرورها با `git pull` |
| 📦 **[راهنمای نصب دستی و آفلاین](MANUAL_INSTALL_GUIDE.fa.md)** | `MANUAL_INSTALL_GUIDE.fa.md` | نصب با فایل زیپ و دستور `scp`، بدون وابستگی به گیت‌هاب |
| 🧠 **[مرجع جامع فنی و معماری](SETUP_AND_GAMING_GUIDE.fa.md)** | `SETUP_AND_GAMING_GUIDE.fa.md` | معماری عمیق، ضد پروب Nginx، کانفیگ‌های کامل Xray و تیونینگ سیستم |

---

## ⚡ نصب سریع از طریق گیت‌هاب (Quick Start)

### ۱. راه‌اندازی سرور ایران (Panel / Hub):
```bash
# نصب پیش‌نیازها
apt-get update -y && apt-get install -y git curl

# دریافت پروژه
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager

# ورود به پوشه و اجرای نصاب پنل
cd /root/rathole-manager
sudo bash install-panel.sh

# ثبت دامنه و دریافت SSL رایگان:
sudo ratholectl cert iran.example.com admin@example.com

# بهینه‌سازی سرعت هسته سرور (BBR):
sudo ratholectl tune

# فعال‌سازی پنل مدیریت تحت وب:
sudo ratholectl hub on 2087
```
🌐 پنل تحت وب: `https://iran.example.com/hub/`

---

### ۲. راه‌اندازی سرور خارج (Node):
ابتدا روی سرور ایران نود را اضافه کرده و توکن را مشاهده کنید:
```bash
sudo ratholectl add node1 10001
sudo ratholectl token node1
```

سپس وارد سرور خارج شده و اجرا کنید:
```bash
apt-get update -y && apt-get install -y git curl
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager
cd /root/rathole-manager
sudo bash install-node.sh

# اتصال نود به سرور ایران:
sudo ratholenode set SERVER iran.example.com:443
sudo ratholenode add-svc node1 <YOUR_TOKEN> 10001

# بررسی وضعیت اتصال:
sudo ratholenode status
```

---

## 🛡️ ویژگی‌های برجسته امنیتی و فنی

1. **دفاع فعال در برابر پروب و فیلترینگ (Active Probe Defense)**:
   - درخواست‌های کاوشگر فیلترچی (Active Scanners) به جای خطای ۵۰۲/۵۰۳ یا صفحات مشکوک، یک پورتال شرکتی معتبر فناوری با کد وضعیت `200 OK` دریافت می‌کنند.
   - تفکیک خودکار بسته‌های WebSocket و XHTTP از ربات‌های کاوشگر.
2. **پشتیبانی کامل از XHTTP (SplitHTTP)**:
   - عبور استریم پیوسته با `chunked_transfer_encoding on` و حذف کامل بافرینگ برای عدم شناسایی توسط فایروال هوش مصنوعی.
3. **حالت گیمینگ بدون تاخیر (L4 SNI Passthrough 0-RTT)**:
   - عبور ترافیک مستقیم TCP/UDP بدون دخالت Nginx لایه ۷ با پروتکل `VLESS-Vision` و هندشیک رمزنگاری در سرور مقصد خارج.
4. **مهار پکت‌لاس با KCP / UDP+FEC روی پورت 443**:
   - شبیه‌سازی الگوی QUIC گوگل و ترمیم بسته‌های از دست رفته اینترنت بین‌الملل با الگوریتم Reed-Solomon.
5. **بروزرسانی بدون قطعی (Zero-Downtime Reload)**:
   - بروزرسانی سریع تنظیمات و هسته‌ها با `git pull` بدون قطع شدن کانکشن کاربران آنلاین.

---

## 🛠️ دستورات پرکاربرد مدیریت سیستم (CLI)

```bash
# بررسی سلامت کل سیستم و اجزا
sudo ratholectl doctor

# مشاهده وضعیت نودها و پورت‌های تانل
sudo ratholectl status

# راه‌اندازی سرویس گیمینگ اختصاصی
sudo ratholectl game add game1 10002 game.example.com

# روشن کردن حالت ضد پکت‌لاس KCP
sudo ratholectl kcp on 443 balanced

# تولید مجدد و ریلود بدون قطعی
sudo ratholectl regen
```

---
*توسعه داده شده جهت ایجاد دسترسی پایدار، امن و پرسرعت به اینترنت آزاد.*
