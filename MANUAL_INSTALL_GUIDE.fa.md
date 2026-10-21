# راهنمای جامع نصب و راه‌اندازی دستی (Manual Installation)
## پروژه تانل معکوس چندمنظوره Rathole Manager
### (شامل راه‌اندازی کامل حالت معمولی WS و XHTTP + حالت گیمینگ 0-RTT + ضد پکت‌لاس KCP)

این راهنما برای زمانی است که می‌خواهید پروژه را **به صورت دستی و مستقیم (با فایل زیپ و بدون نیاز به گیت‌هاب)** روی سرور ایران و سرور خارج مستقر کنید.

---

## فهرست مطالب
1. [پیش‌نیازها و تنظیم دامنه‌ها](#۱-پیش‌نیازها-و-تنظیم-دامنه‌ها)
2. [گام ۱: انتقال فایل زیپ به هر دو سرور](#۲-گام-۱-انتقال-فایل-زیپ-به-هر-دو-سرور)
3. [گام ۲: راه‌اندازی سرور ایران (پنل و سرور تانل)](#۳-گام-۲-راه‌اندازی-سرور-ایران-پنل-و-سرور-تانل)
4. [گام ۳: راه‌اندازی نود در سرور خارج](#۴-گام-۳-راه‌اندازی-نود-در-سرور-خارج)
5. [گام ۴: کانفیگ حالت معمولی الف - پروتکل WebSocket (WS)](#۵-گام-۴-کانفیگ-حالت-معمولی-الف---پروتکل-websocket-ws)
6. [گام ۵: کانفیگ حالت معمولی ب - پروتکل فوق‌پیشرفته XHTTP (SplitHTTP)](#۶-گام-۵-کانفیگ-حالت-معمولی-ب---پروتکل-فوق‌پیشرفته-xhttp-splithttp)
7. [گام ۶: کانفیگ حالت گیمینگ فوق‌سریع (L4 SNI + VLESS-Vision + UDP FullCone)](#۷-گام-۶-کانفیگ-حالت-گیمینگ-فوق‌سریع-l4-sni--vless-vision--udp-fullcone)
8. [گام ۷: فعال‌سازی سلاح ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)](#۸-گام-۷-فعال‌سازی-سلاح-ضد-پکت‌لاس-گیم-kcp--udpfec-روی-پورت-443)
9. [تنظیمات بهینه کلاینت‌ها (v2rayNG, Sing-box, Nekobox)](#۹-تنظیمات-بهینه-کلاینت‌ها-v2rayng-sing-box-nekobox)
10. [دستورات کاربردی و نگهداری](#۱۰-دستورات-کاربردی-و-نگهداری)

---

## ۱. پیش‌نیازها و تنظیم دامنه‌ها

| مورد | مقدار پیشنهادی | توضیحات |
| :--- | :--- | :--- |
| **سرور ایران** | Ubuntu 20.04/22.04/24.04 یا Debian 11/12 | رم حداقل ۱ گیگابایت، دسترسی روت |
| **سرور خارج** | Ubuntu یا Debian | با پینگ مناسب به ایران (آلمان، هلند، ترکیه و...) |
| **دامنه اصلی** | مثلاً `iran.example.com` | رکورد A در Cloudflare مستقیم به **IP سرور ایران** (پروکسی ☁️ خاموش) |
| **ساب‌دامین گیم** | مثلاً `game.example.com` | رکورد A در Cloudflare مستقیم به **IP سرور ایران** (پروکسی ☁️ خاموش) |
| **پورت‌های باز** | `80/tcp`, `443/tcp`, `443/udp` | روی سرور ایران باز باشند |

---

## ۲. گام ۱: انتقال فایل زیپ به هر دو سرور

فایل `rathole-manager.zip` در سیستم لوکال شما قرار دارد. آن را به سرور ایران و سرور خارج انتقال دهید.

### دستور ارسال فایل از سیستم خودتان (با ترمینال یا PowerShell):
```bash
# ارسال به سرور ایران:
scp "rathole-manager.zip" root@<IRAN_IP>:/root/

# ارسال به سرور خارج:
scp "rathole-manager.zip" root@<NODE_IP>:/root/
```

### استخراج و آماده‌سازی روی هر دو سرور:
وارد سرور ایران و سرور خارج شوید و دستورات زیر را وارد کنید:
```bash
# نصب پکیج unzip
apt-get update -y && apt-get install -y unzip

# استخراج در مسیر rathole-setup
cd /root
unzip -o rathole-manager.zip -d rathole-setup
cd rathole-setup

# رفع خطاهای پرمیشن و فرمت ویندوز (CRLF) با اسکریپت بوت‌استرپ
chmod +x bootstrap.sh
sudo bash bootstrap.sh
```

---

## ۳. گام ۲: راه‌اندازی سرور ایران (پنل و سرور تانل)

روی **سرور ایران** وارد مسیر پروژه شوید:
```bash
cd /root/rathole-setup
sudo bash install-panel.sh
```

### ثبت دامنه و دریافت گواهی SSL:
```bash
# دامنه اصلی خود را وارد کنید (مثال: iran.example.com):
sudo ratholectl cert iran.example.com admin@example.com
```

### اعمال تنظیمات پرسرعت BBR و بافرهای شبکه:
```bash
sudo ratholectl tune
```

### فعال‌سازی پنل مدیریت وب تحت وب هاب (RatholeHub):
```bash
sudo ratholectl hub on 2087
```
سپس در مرورگر خود آدرس را باز کنید:
👉 `https://iran.example.com/hub/`

---

## ۴. گام ۳: راه‌اندازی نود در سرور خارج

### تعریف نود روی سرور ایران:
روی سرور ایران، یک نود جدید ایجاد کنید (مثلاً نود با پورت لوکال 10001 در خارج):
```bash
sudo ratholectl add node1 10001
```
سپس دستور زیر را بزنید تا اطلاعات توکن نمایش داده شود:
```bash
sudo ratholectl token node1
```

### اجرای نصاب روی سرور خارج:
روی **سرور خارج** وارد پوشه پروژه شده و نصب نود را انجام دهید:
```bash
cd /root/rathole-setup
sudo bash install-node.sh
```
سپس نود را به سرور ایران متصل کنید:
```bash
sudo ratholenode set SERVER iran.example.com:443
sudo ratholenode add-svc node1 <TOKEN_DARYAFTI> 10001
```
برای بررسی وضعیت اتصال در خارج:
```bash
sudo ratholenode status
```

---

## ۵. گام ۴: کانفیگ حالت معمولی الف - پروتکل WebSocket (WS)

پروتکل محبوب و سازگار با تمامی اپلیکیشن‌ها و سیستم‌عامل‌ها.

روی **سرور خارج**، فایل کانفیگ Xray (`/usr/local/etc/xray/config.json`) را ویرایش کنید:
```json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "vless-ws-in",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "e8a93cb4-56c2-48df-b118-86d1d4cb8040", "level": 0 }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/node1"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct", "settings": { "domainStrategy": "UseIP" } }
  ]
}
```
سرویس Xray را ریستارت کنید:
```bash
systemctl restart xray
```

### لینک اتصال کلاینت (VLESS WebSocket):
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?type=ws&security=tls&path=%2Fnode1&sni=iran.example.com#Normal-WS
```

---

## ۶. گام ۵: کانفیگ حالت معمولی ب - پروتکل فوق‌پیشرفته XHTTP (SplitHTTP)

### چرا XHTTP؟
پروتکل **XHTTP** (نسل جدید انتقالات Xray) به جای برقراری ارتباط مداوم وب‌سوکت، ترافیک را در قالب درخواست‌های استاندارد HTTP/2 و HTTP POST/GET ارسال می‌کند. برای سیستم‌های فیلترینگ و هوش مصنوعی، ترافیک کاربر **دقیقاً مانند آپلود فایل یا کار با یک وب‌سایت سازمانی** به نظر می‌رسد و فیلترچی نمی‌تواند آن را به عنوان کانکشن پایدار VPN تشخیص داده یا محدود کند.

> [!TIP]
> هسته پروژه Rathole Manager با فعال‌سازی `chunked_transfer_encoding on` و `proxy_request_buffering off` و سیستم تفکیک پروب، به طور کامل و ۱۰۰٪ بهینه از XHTTP پشتیبانی می‌کند.

روی **سرور خارج**، پورت دیگری مثلاً `10003` برای XHTTP در نظر می‌گیریم:
ابتدا این سرویس را در تانل خارج ثبت کنید:
```bash
# روی ایران:
sudo ratholectl add xhttp1 10003
# روی خارج:
sudo ratholenode add-svc xhttp1 <TOKEN_XHTTP1> 10003
```

سپس در فایل `/usr/local/etc/xray/config.json` در سرور خارج، این Inbound را اضافه کنید:
```json
{
  "tag": "vless-xhttp-in",
  "port": 10003,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [
      { "id": "e8a93cb4-56c2-48df-b118-86d1d4cb8040", "level": 0 }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "xhttp",
    "security": "none",
    "xhttpSettings": {
      "path": "/xhttp1",
      "mode": "auto"
    }
  }
}
```
سرویس Xray را ریستارت کنید:
```bash
systemctl restart xray
```

### لینک اتصال کلاینت (VLESS XHTTP):
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?type=xhttp&security=tls&path=%2Fxhttp1&mode=auto&sni=iran.example.com#Normal-XHTTP-Stealth
```

---

## ۷. گام ۶: کانفیگ حالت گیمینگ فوق‌سریع (L4 SNI + VLESS-Vision + UDP FullCone)

این حالت مخصوص بازی‌های آنلاین (Call of Duty, FIFA, Valorant, CS2) و ویس دیسکورد است:
- صفر میلی‌ثانیه تاخیر اضافه (0-RTT).
- حذف کامل لایه‌های وب و وب‌سوکت.
- عبور مستقیم بسته‌های UDP به صورت FullCone.

### مرحله ۱: افزودن سرویس گیم روی سرور ایران
ساب‌دامین مخصوص گیم (مثلاً `game.example.com`) که به IP سرور ایران اشاره می‌کند:
```bash
# روی سرور ایران:
sudo ratholectl game add game1 10002 game.example.com
```

### مرحله ۲: دریافت گواهی و انتقال به سرور خارج
```bash
# روی سرور ایران گواهی را بگیرید:
sudo ratholectl game cert game.example.com

# انتقال با دستور امن SCP به خارج:
ssh root@<NODE_IP> "mkdir -p /etc/xray-certs/game.example.com"
scp /etc/letsencrypt/live/game.example.com/fullchain.pem root@<NODE_IP>:/etc/xray-certs/game.example.com/
scp /etc/letsencrypt/live/game.example.com/privkey.pem root@<NODE_IP>:/etc/xray-certs/game.example.com/
```

### مرحله ۳: اتصال سرویس گیم به نود خارج
```bash
# روی سرور ایران توکن را مشاهده کنید:
sudo ratholectl game ls

# روی سرور خارج سرویس را اضافه کنید:
sudo ratholenode add-svc game1 <GAME_TOKEN> 10002
```

### مرحله ۴: کانفیگ Xray در سرور خارج (حالت گیم)
در فایل `/usr/local/etc/xray/config.json` در سرور خارج این بخش را قرار دهید:
```json
{
  "tag": "vless-game-vision-in",
  "port": 10002,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [
      {
        "id": "e8a93cb4-56c2-48df-b118-86d1d4cb8040",
        "flow": "xtls-rprx-vision",
        "level": 0
      }
    ],
    "decryption": "none",
    "fallbacks": [
      { "dest": 8081 }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "tls",
    "tlsSettings": {
      "certificates": [
        {
          "certificateFile": "/etc/xray-certs/game.example.com/fullchain.pem",
          "keyFile": "/etc/xray-certs/game.example.com/privkey.pem"
        }
      ]
    }
  }
}
```
سرویس فال‌بک وب روی خارج را روشن کرده و Xray را ریستارت کنید:
```bash
sudo ratholenode fakeweb start 8081
systemctl restart xray
```

### لینک اتصال کلاینت (VLESS Vision Game):
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?security=tls&encryption=none&flow=xtls-rprx-vision&headerType=none&type=tcp&sni=game.example.com&fp=chrome#Game-Vision-Direct
```

---

## ۸. گام ۷: فعال‌سازی سلاح ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)

اگر شب‌ها در اینترنت بین‌الملل پکت‌لاس دارید و پینگ بازی شما بالا و پایین می‌پرد:
1. روی سرور ایران پورت `443/udp` را باز کنید:
   ```bash
   sudo ufw allow 443/udp
   ```
2. KCP را با پروفایل متوازن روشن کنید:
   ```bash
   sudo ratholectl kcp on 443 balanced
   sudo ratholectl kcp status
   ```
   (کلید امنیتی نمایش داده‌شده را بردارید).
3. روی سرور خارج دستور سوئیچ به UDP را با کلید بزنید:
   ```bash
   sudo ratholenode kcp on <IRAN_IP>:443 <KEY_DARYAFTI> balanced
   ```

**نتیجه**: ارتباط بین دو سرور بدون نیاز به تغییر کانفیگ کاربر، روی بستر UDP با استتار QUIC و تصحیح خطای ریاضی Reed-Solomon منتقل شده و پکت‌لاس صفر می‌شود.

---

## ۹. تنظیمات بهینه کلاینت‌ها (v2rayNG, Sing-box, Nekobox)

1. **برای گیمینگ**: حتماً گزینه **TUN Mode** را در نرم‌افزار فعال کنید تا تمامی بازی‌ها از پروکسی رد شوند.
2. **غیرفعال‌سازی Mux در گیمینگ**: گزینه **Multiplex (Mux)** را برای کانفیگ گیمینگ خاموش کنید تا پکت‌ها صف نبندند.
3. **برای وب‌گردی با XHTTP**: از کلاینت‌های به‌روز که از XHTTP پشتیبانی می‌کنند (v2rayNG نسخه 1.8.20+ یا Sing-box نسخه 1.9+ یا v2rayN 6.40+) استفاده کنید.

---

## ۱۰. دستورات کاربردی و نگهداری

```bash
# بررسی کامل سلامت سیستم و Nginx
sudo ratholectl doctor

# مشاهده وضعیت کلی پورت‌ها و نودها
sudo ratholectl status

# مشاهده لاگ‌های سیستم با سانسور توکن‌ها
sudo ratholectl logs 50

# ساخت بک‌آپ کامل از تنظیمات
sudo ratholectl backup /root/rathole-backup.json

# مشاهده لیست سرویس‌های گیمینگ
sudo ratholectl game ls
```
