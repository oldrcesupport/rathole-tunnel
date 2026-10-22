# راهنمای مدرن نصب و راه‌اندازی از طریق گیت‌هاب (GitHub Installation)
## پروژه تانل معکوس Rathole Manager و ادغام با پنل سنایی ([3x-ui](https://github.com/MHSanaei/3x-ui))
### (شامل نصب تک‌خطی خودکار، ساخت اینباندهای WS ،XHTTP و Vision در 3x-ui، آپدیت بدون قطعی)

این راهنما استانداردترین و سریع‌ترین شیوه راه‌اندازی تانل معکوس سرور ایران به خارج و ادغام آن با **پنل گرافیکی سنایی (3x-ui)** است. با این روش، تمامی کاربران، کانفیگ‌ها و اینباندها را در محیط گرافیکی ۳x-ui مدیریت می‌کنید و بروزرسانی تمامی سرورها با دستور `git pull` در چند ثانیه انجام می‌شود.

---

## فهرست مطالب
1. [نصب سرور ایران از طریق گیت‌هاب](#۱-نصب-سرور-ایران-از-طریق-گیت‌هاب)
2. [نصب پنل سنایی (3x-ui) روی سرور خارج](#۲-نصب-پنل-سنایی-3x-ui-روی-سرور-خارج)
3. [نصب نود تانل روی سرور خارج](#۳-نصب-نود-تانل-روی-سرور-خارج)
4. [پیکربندی اینباندهای 3x-ui (ورودی‌های عادی الف و ب)](#۴-پیکربندی-اینباندهای-3x-ui-ورودی‌های-عادی-الف-و-ب)
5. [پیکربندی اینباند گیمینگ فوق‌سریع در 3x-ui (حالت L4 Vision)](#۵-پیکربندی-اینباند-گیمینگ-فوق‌سریع-در-3x-ui-حالت-l4-vision)
6. [فعال‌سازی ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)](#۶-فعال‌سازی-ضد-پکت‌لاس-گیم-kcp--udpfec-روی-پورت-443)
7. [روش بروزرسانی آنی سرورها با گیت‌هاب (Zero-Downtime Update)](#۷-روش-بروزرسانی-آنی-سرورها-با-گیت‌هاب-zero-downtime-update)

---

## ۱. نصب سرور ایران از طریق گیت‌هاب

وارد SSH **سرور ایران** شوید و یکی از دو روش زیر را انتخاب کنید:

### روش الف: نصب خودکار تک‌خطی (سریع‌ترین روش)
```bash
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel
```

### روش ب: نصب از طریق کلون گیت‌هاب
```bash
# نصب پکیج‌های پایه
apt-get update -y && apt-get install -y git curl

# دریافت پروژه از گیت‌هاب
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager

# ورود و اجرای نصاب پنل ایران
cd /root/rathole-manager
sudo bash install-panel.sh
```

### تنظیم دامنه اصلی و گواهی SSL:
```bash
# ثبت دامنه سرور ایران و دریافت خودکار SSL (مثال: iran.example.com):
sudo ratholectl cert iran.example.com admin@example.com

# بهینه‌سازی سرعت هسته سرور (BBR):
sudo ratholectl tune

# راه‌اندازی پنل گرافیکی وب RatholeHub:
sudo ratholectl hub on 2087
```
🌐 آدرس پنل مانیتورینگ ایران: `https://iran.example.com/hub/`

---

## ۲. نصب پنل سنایی (3x-ui) روی سرور خارج

وارد SSH **سرور خارج** شوید و نصاب رسمی پنل سنایی را اجرا کنید:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```
- در مراحل نصب، نام کاربری، پسورد و پورت پنل (مثلاً `2053`) را انتخاب کنید.
- پس از اتمام نصب، وارد پنل وب شوید: `http://<IP_KHAREJ>:2053/`

---

## ۳. نصب نود تانل روی سرور خارج

### گام اول: تعریف پورت‌های اینباند سنایی در سرور ایران
روی سرور ایران، پورت‌هایی که قرار است تانل به خارج متصل کند را بسازید:
```bash
# ساخت نود برای وب‌سوکت سنایی (پورت 10001):
sudo ratholectl add node1 10001

# ساخت نود برای XHTTP سنایی (پورت 10003):
sudo ratholectl add xhttp1 10003
```
سپس با دستورات زیر توکن‌های ایجاد شده را یادداشت کنید:
```bash
sudo ratholectl token node1
sudo ratholectl token xhttp1
```

### گام دوم: اجرای نود در سرور خارج
روی **سرور خارج** دستورات زیر را اجرا کنید:
```bash
# دریافت پروژه
apt-get update -y && apt-get install -y git curl
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager
cd /root/rathole-manager
sudo bash install-node.sh
```

سپس نود را به سرور ایران متصل کرده و سرویس‌ها را ثبت کنید:
```bash
# آدرس سرور ایران را تنظیم کنید:
sudo ratholenode set SERVER iran.example.com:443

# ثبت سرویس‌ها با توکن‌های سرور ایران:
sudo ratholenode add-svc node1 <TOKEN_NODE1> 10001
sudo ratholenode add-svc xhttp1 <TOKEN_XHTTP1> 10003

# بررسی سلامت اتصال نود
sudo ratholenode status
```

---

## ۴. پیکربندی اینباندهای 3x-ui (ورودی‌های عادی الف و ب)

وارد پنل وب **3x-ui** در سرور خارج شوید (`http://<IP_KHAREJ>:2053/`) و اینباندها را تعریف کنید:

### الف) ورودی ترافیک وب‌سوکت (WebSocket):
روی **Inbounds > Add Inbound** کلیک کنید:
- **Remark**: `Iran-WS`
- **Protocol**: `vless`
- **Listening IP**: `127.0.0.1`  *(برای امنیت، پورت مستقیم روی اینترنت باز نماند)*
- **Port**: `10001`
- **Transmission**: `ws`
- **Path**: `/node1`
- **Security**: `none` *(رمزگشایی SSL در سرور ایران انجام می‌شود)*
- **تنظیمات خروجی کلاینت (Stream Settings)**:
  - **Address**: `iran.example.com`
  - **Port**: `443`
  - **TLS**: فعال (`tls`) با SNI: `iran.example.com`

---

### ب) ورودی ترافیک استتار نوین (XHTTP / SplitHTTP):
برای کاربرانی که وب‌سوکت آن‌ها مسدود است، یک ورودی دیگر در ۳x-ui اضافه کنید:
- **Remark**: `Iran-XHTTP`
- **Protocol**: `vless`
- **Listening IP**: `127.0.0.1`
- **Port**: `10003`
- **Transmission**: `xhttp` (یا `splithttp`)
- **Path**: `/xhttp1`
- **Mode**: `auto`
- **Security**: `none`
- **تنظیمات خروجی کلاینت**:
  - **Address**: `iran.example.com`
  - **Port**: `443`
  - **TLS**: فعال (`tls`) با SNI: `iran.example.com`

---

## ۵. پیکربندی اینباند گیمینگ فوق‌سریع در 3x-ui (حالت L4 Vision)

برای گیمرهای آنلاین (صفر تاخیر، عبور مستقیم لایه ۴ و UDP FullCone):

### ۱. تعریف در سرور ایران:
```bash
# روی ایران:
sudo ratholectl game add game1 10002 game.example.com
sudo ratholectl game cert game.example.com
sudo ratholectl game ls
```

### ۲. ارسال گواهی SSL به خارج:
```bash
ssh root@<IP_KHAREJ> "mkdir -p /etc/xray-certs/game.example.com"
scp /etc/letsencrypt/live/game.example.com/fullchain.pem root@<IP_KHAREJ>:/etc/xray-certs/game.example.com/
scp /etc/letsencrypt/live/game.example.com/privkey.pem root@<IP_KHAREJ>:/etc/xray-certs/game.example.com/
```

### ۳. اتصال سرویس گیم به نود خارج:
```bash
# روی خارج:
sudo ratholenode add-svc game1 <GAME_TOKEN> 10002
sudo ratholenode fakeweb start 8081
```

### ۴. ساخت اینباند گیمینگ در 3x-ui:
در پنل ۳x-ui یک ورودی جدید ایجاد کنید:
- **Remark**: `Game-Vision-Direct`
- **Protocol**: `vless`
- **Listening IP**: `127.0.0.1`
- **Port**: `10002`
- **Transmission**: `tcp`
- **Security**: **`tls`** *(در حالت گیمینگ، هندشیک TLS مستقیماً در سنایی انجام می‌شود)*
- **Flow**: **`xtls-rprx-vision`**
- **Certificate**: فایل `/etc/xray-certs/game.example.com/fullchain.pem` و کلید `/etc/xray-certs/game.example.com/privkey.pem`
- **Fallbacks**: پورت `8081`

---

## ۶. فعال‌سازی ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)

در ساعات اختلال شدید و پکت‌لاس اینترنت بین‌الملل:
1. **روی سرور ایران**:
   ```bash
   sudo ufw allow 443/udp
   sudo ratholectl kcp on 443 balanced
   sudo ratholectl kcp status
   ```
2. **روی سرور خارج**:
   ```bash
   sudo ratholenode kcp on <IP_IRAN>:443 <کلید_دریافتی> balanced
   ```

تانل بلافاصله روی بستر ضد پکت‌لاس QUIC+FEC سوئیچ کرده و تمام اینباندهای پنل سنایی بدون افت کیفیت و پکت‌لاس به کار خود ادامه می‌دهند.

---

## ۷. روش بروزرسانی آنی سرورها با گیت‌هاب (Zero-Downtime Update)

هر زمان که تغییری در مخزن گیت‌هاب ایجاد شد، روی سرورها کافیست دستور زیر را اجرا کنید:

```bash
cd /root/rathole-manager
git pull
sudo ratholectl regen
```
کلیه سرویس‌ها بدون حتی یک ثانیه قطعی برای کاربران آنلاین (Zero-Downtime Reload) بروزرسانی می‌شوند.
