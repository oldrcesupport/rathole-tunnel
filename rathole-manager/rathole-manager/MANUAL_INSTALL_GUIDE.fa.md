# راهنمای جامع نصب و راه‌اندازی دستی (Manual Installation)
## پروژه تانل معکوس Rathole Manager و ادغام با پنل سنایی ([3x-ui](https://github.com/MHSanaei/3x-ui))
### (شامل استقرار با فایل زیپ، راه‌اندازی اینباندهای WS ،XHTTP، گیمینگ 0-RTT Vision و ضد پکت‌لاس KCP)

این راهنما برای زمانی است که می‌خواهید پروژه تانل معکوس را به صورت آفلاین یا مستقیم (با فایل زیپ) مستقر کرده و تمامی اینباندها و کاربران را از طریق **پنل گرافیکی سنایی (3x-ui)** مدیریت کنید. در این روش، شما نیازی به ویرایش دستی فایل‌های Xray در لینوکس ندارید.

---

## فهرست مطالب
1. [پیش‌نیازها و رکوردهای دامنه](#۱-پیش‌نیازها-و-رکوردهای-دامنه)
2. [گام ۱: انتقال فایل زیپ به هر دو سرور](#۲-گام-۱-انتقال-فایل-زیپ-به-هر-دو-سرور)
3. [گام ۲: راه‌اندازی سرور ایران (پنل و Nginx)](#۳-گام-۲-راه‌اندازی-سرور-ایران-پنل-و-nginx)
4. [گام ۳: نصب پنل سنایی (3x-ui) و نود تانل در سرور خارج](#۴-گام-۳-نصب-پنل-سنایی-3x-ui-و-نود-تانل-در-سرور-خارج)
5. [گام ۴: ساخت اینباند ترافیک عادی الف (WebSocket) در 3x-ui](#۵-گام-۴-ساخت-اینباند-ترافیک-عادی-الف-websocket-در-3x-ui)
6. [گام ۵: ساخت اینباند ترافیک عادی ب (XHTTP استتار نوین) در 3x-ui](#۶-گام-۵-ساخت-اینباند-ترافیک-عادی-ب-xhttp-استتار-نوین-در-3x-ui)
7. [گام ۶: ساخت اینباند گیمینگ فوق‌سریع (L4 Vision 0-RTT) در 3x-ui](#۷-گام-۶-ساخت-اینباند-گیمینگ-فوق‌سریع-l4-vision-0-rtt-در-3x-ui)
8. [گام ۷: فعال‌سازی سلاح ضد پکت‌لاس KCP روی پورت 443](#۸-گام-۷-فعال‌سازی-سلاح-ضد-پکت‌لاس-kcp-روی-پورت-443)
9. [دستورات پرکاربرد نگهداری و عیب‌یابی](#۹-دستورات-پرکاربرد-نگهداری-و-عیب‌یابی)

---

## ۱. پیش‌نیازها و رکوردهای دامنه

| مورد | مقدار پیشنهادی | توضیحات |
| :--- | :--- | :--- |
| **سرور ایران** | اوبونتو یا دبیان | حداقل ۱ گیگابایت رم، دسترسی روت |
| **سرور خارج** | اوبونتو یا دبیان | پینگ مناسب به ایران، دسترسی روت |
| **دامنه اصلی** | مثلاً `iran.example.com` | رکورد A در کلودفلر مستقیم به **IP سرور ایران** (پروکسی ☁️ خاموش / DNS Only) |
| **ساب‌دامین گیم** | مثلاً `game.example.com` | رکورد A در کلودفلر مستقیم به **IP سرور ایران** (پروکسی ☁️ خاموش / DNS Only) |
| **پورت‌های باز** | `80/tcp`, `443/tcp`, `443/udp` | روی سرور ایران باز باشند |

---

## ۲. گام ۱: انتقال فایل زیپ به هر دو سرور

فایل `rathole-manager.zip` در مخزن یا سیستم لوکال شما قرار دارد. آن را به سرور ایران و سرور خارج انتقال دهید:

```bash
# ارسال فایل به سرور ایران:
scp "rathole-manager.zip" root@<IRAN_IP>:/root/

# ارسال فایل به سرور خارج:
scp "rathole-manager.zip" root@<NODE_IP>:/root/
```

سپس وارد هر دو سرور شده و فایل را استخراج کنید:
```bash
apt-get update -y && apt-get install -y unzip
cd /root
unzip -o rathole-manager.zip -d rathole-setup
```

---

## ۳. گام ۲: راه‌اندازی سرور ایران (پنل و Nginx)

روی **سرور ایران** به پوشه اسکریپت‌ها بروید و نصاب را اجرا کنید:

```bash
cd /root/rathole-setup/rathole-manager/rathole-manager
sudo bash install-panel.sh
```

### ثبت دامنه اصلی و دریافت SSL رایگان:
```bash
# دامنه اصلی خود را وارد کنید (مثال: iran.example.com):
sudo ratholectl cert iran.example.com admin@example.com
```

### بهینه‌سازی سرعت هسته سیستم (BBR):
```bash
sudo ratholectl tune
```

### فعال‌سازی پنل مدیریت وب RatholeHub:
```bash
sudo ratholectl hub on 2087
```
🌐 آدرس پنل تحت وب ایران: `https://iran.example.com/hub/`

---

## ۴. گام ۳: نصب پنل سنایی (3x-ui) و نود تانل در سرور خارج

روی **سرور خارج**، ابتدا پنل سنایی را نصب کنید:

### ۱. نصب پنل محبوب سنایی (3x-ui):
```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```
- نام کاربری، کلمه عبور و پورت پنل (مثلاً `2053`) را تنظیم کنید.
- پس از اتمام نصب، وارد پنل وب شوید: `http://<IP_KHAREJ>:2053/`

### ۲. تعریف پورت‌های سرویس روی سرور ایران:
به ترمینال سرور ایران بروید و پورت‌های محلی نود را ایجاد کنید:
```bash
# پورت 10001 برای وب‌سوکت سنایی:
sudo ratholectl add node1 10001

# پورت 10003 برای XHTTP سنایی:
sudo ratholectl add xhttp1 10003
```
با دستورات زیر توکن‌های هر نود را مشاهده کنید:
```bash
sudo ratholectl token node1
sudo ratholectl token xhttp1
```

### ۳. نصب و راه‌اندازی نود در سرور خارج:
به ترمینال سرور خارج برگردید:
```bash
cd /root/rathole-setup/rathole-manager/rathole-manager
sudo bash install-node.sh
```

سپس سرویس‌ها را با توکن‌های دریافتی به تانل معکوس اضافه کنید:
```bash
# ست کردن آدرس سرور ایران:
sudo ratholenode set SERVER iran.example.com:443

# اضافه کردن اینباندها به تانل:
sudo ratholenode add-svc node1 <TOKEN_NODE1> 10001
sudo ratholenode add-svc xhttp1 <TOKEN_XHTTP1> 10003

# بررسی آنلاین بودن اتصال:
sudo ratholenode status
```

---

## ۵. گام ۴: ساخت اینباند ترافیک عادی الف (WebSocket) در 3x-ui

وارد پنل وب ۳x-ui در خارج شوید (`http://<IP_KHAREJ>:2053/`):
1. به منوی **Inbounds** رفته و روی **Add Inbound** کلیک کنید.
2. فیلدها را به این صورت پر کنید:
   - **Remark**: `Iran-WS`
   - **Protocol**: `vless`
   - **Listening IP**: `127.0.0.1`  *(حتماً 127.0.0.1 بگذارید تا پورت روی اینترنت لو نرود)*
   - **Port**: `10001`
   - **Transmission**: `ws`
   - **Path**: `/node1`  *(دقیقاً همنام با نامی که در ratholectl add زدید)*
   - **Security**: `none` *(چون TLS در سرور ایران بازگشایی می‌شود)*
3. در کلاینت کاربران:
   - **Address**: `iran.example.com`
   - **Port**: `443`
   - **TLS**: فعال (`tls`) با SNI: `iran.example.com`

---

## ۶. گام ۵: ساخت اینباند ترافیک عادی ب (XHTTP استتار نوین) در 3x-ui

برای کاربرانی که وب‌سوکت آن‌ها با اختلال مواجه می‌شود:
1. در ۳x-ui یک اینباند جدید بسازید:
   - **Remark**: `Iran-XHTTP`
   - **Protocol**: `vless`
   - **Listening IP**: `127.0.0.1`
   - **Port**: `10003`
   - **Transmission**: `xhttp` (یا `splithttp`)
   - **Path**: `/xhttp1`
   - **Mode**: `auto`
   - **Security**: `none`
2. در کلاینت کاربران:
   - **Address**: `iran.example.com`
   - **Port**: `443`
   - **TLS**: فعال (`tls`) با SNI: `iran.example.com`

---

## ۷. گام ۶: ساخت اینباند گیمینگ فوق‌سریع (L4 Vision 0-RTT) در 3x-ui

این حالت مخصوص گیمرهایی است که پینگ حداقلی، صفر تاخیر و UDP FullCone می‌خواهند:

### ۱. تعریف در سرور ایران:
```bash
sudo ratholectl game add game1 10002 game.example.com
sudo ratholectl game cert game.example.com
```

### ۲. انتقال گواهینامه SSL ساب‌دامین گیم به سرور خارج:
```bash
ssh root@<IP_KHAREJ> "mkdir -p /etc/xray-certs/game.example.com"
scp /etc/letsencrypt/live/game.example.com/fullchain.pem root@<IP_KHAREJ>:/etc/xray-certs/game.example.com/
scp /etc/letsencrypt/live/game.example.com/privkey.pem root@<IP_KHAREJ>:/etc/xray-certs/game.example.com/
```

### ۳. اتصال سرویس گیم به نود خارج:
```bash
sudo ratholenode add-svc game1 <GAME_TOKEN> 10002
sudo ratholenode fakeweb start 8081
```

### ۴. ساخت اینباند در 3x-ui:
در پنل ۳x-ui:
- **Remark**: `Game-Vision-Direct`
- **Protocol**: `vless`
- **Listening IP**: `127.0.0.1`
- **Port**: `10002`
- **Transmission**: `tcp`
- **Security**: **`tls`**
- **Flow**: **`xtls-rprx-vision`**
- **Public Key / Cert**: فایل `/etc/xray-certs/game.example.com/fullchain.pem`
- **Private Key**: فایل `/etc/xray-certs/game.example.com/privkey.pem`
- **Fallbacks**: پورت `8081`

---

## ۸. گام ۷: فعال‌سازی سلاح ضد پکت‌لاس KCP روی پورت 443

هنگامی که پکت‌لاس شدید روی اینترنت ایجاد می‌شود:
1. **روی سرور ایران**:
   ```bash
   sudo ufw allow 443/udp
   sudo ratholectl kcp on 443 balanced
   ```
2. **روی سرور خارج**:
   ```bash
   sudo ratholenode kcp on <IP_IRAN>:443 <کلید_KCP> balanced
   ```

---

## ۹. دستورات پرکاربرد نگهداری و عیب‌یابی

```bash
# عیب‌یابی جامع و بررسی تمام سرویس‌ها:
sudo ratholectl doctor

# مشاهده وضعیت و کانکشن‌های فعال نودها:
sudo ratholectl status

# تولید مجدد کانفیگ‌ها و ریلود بدون قطعی کاربران:
sudo ratholectl regen

# تست اتصال و وضعیت نود در خارج:
sudo ratholenode status
```
