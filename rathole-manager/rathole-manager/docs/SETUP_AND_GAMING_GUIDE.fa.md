# مرجع جامع و تخصصی معماری و راه‌اندازی Rathole Multi-Location Tunnel
## (راهنمای جامع ترافیک معمولی WS و XHTTP + حالت گیمینگ 0-RTT با پشتیبانی UDP FullCone و ضد پکت‌لاس KCP)

این سند مرجع فنی، معماری و عملیاتی پروژه **Rathole Manager** است. تمامی پروتکل‌های ارتباطی، مکانیزم‌های دفاع در برابر فیلترینگ هوشمند (Active Probing Defense)، استتار کامل سرویس‌ها و تنظیمات فوق‌سریع گیمینگ به طور کامل در این فایل تشریح شده‌اند.

---

## فهرست مطالب
1. [معماری سیستم و نحوه کارکرد تانل معکوس](#۱-معماری-سیستم-و-نحوه-کارکرد-تانل-معکوس)
2. [پیش‌نیازها و تنظیم رکوردهای DNS](#۲-پیش‌نیازها-و-تنظیم-رکوردهای-dns)
3. [بررسی و مقایسه ۳ پروتکل ارتباطی (WS / XHTTP / Vision)](#۳-بررسی-و-مقایسه-۳-پروتکل-ارتباطی-ws--xhttp--vision)
4. [گام ۱: راه‌اندازی سرور ایران (پنل و سرور مرکزی)](#۴-گام-۱-راه‌اندازی-سرور-ایران-پنل-و-سرور-مرکزی)
5. [گام ۲: راه‌اندازی نود در سرور خارج](#۵-گام-۲-راه‌اندازی-نود-در-سرور-خارج)
6. [گام ۳: راه‌اندازی حالت معمولی الف - پروتکل WebSocket (WS)](#۶-گام-۳-راه‌اندازی-حالت-معمولی-الف---پروتکل-websocket-ws)
7. [گام ۴: راه‌اندازی حالت معمولی ب - پروتکل فوق‌پیشرفته XHTTP (SplitHTTP)](#۷-گام-۴-راه‌اندازی-حالت-معمولی-ب---پروتکل-فوق‌پیشرفته-xhttp-splithttp)
8. [گام ۵: راه‌اندازی حالت گیمینگ فوق‌سریع (L4 SNI + VLESS-Vision + UDP FullCone)](#۸-گام-۵-راه‌اندازی-حالت-گیمینگ-فوق‌سریع-l4-sni--vless-vision--udp-fullcone)
9. [گام ۶: فعال‌سازی سلاح ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)](#۹-گام-۶-فعال‌سازی-سلاح-ضد-پکت‌لاس-گیم-kcp--udpfec-روی-پورت-443)
10. [لایه‌های پیشرفته ضدفیلترینگ و عدم مسدودسازی IP و دامنه](#۱۰-لایه‌های-پیشرفته-ضدفیلترینگ-و-عدم-مسدودسازی-ip-و-دامنه)
11. [تنظیمات بهینه اپلیکیشن‌های کلاینت](#۱۱-تنظیمات-بهینه-اپلیکیشن‌های-کلاینت)
12. [جعبه‌ابزار دستورات مدیریتی و عیب‌یابی](#۱۲-جعبه‌ابزار-دستورات-مدیریتی-و-عیب‌یابی)

---

## ۱. معماری سیستم و نحوه کارکرد تانل معکوس

### الف) ساختار تانل معکوس (Reverse Tunnel)
در تانل‌های قدیمی، سرور ایران به سرور خارج وصل می‌شد که به دلیل اتصال خروجی مستقیم، فوراً توسط سیستم‌های فیلترینگ شناسایی و مسدود می‌شد. در معماری Rathole:
1. **سرور ایران شنونده (Listener) است**: فقط پورت 443 و 80 باز است و در نقش یک وب‌سرور عادی پاسخ می‌دهد.
2. **سرور خارج متصل‌شونده (Initiator) است**: نود خارج یک اتصال امن پایدار به سمت سرور ایران برقرار می‌کند.
3. ترافیک کاربران وارد سرور ایران شده و از درون تانل معکوس به سرور خارج هدایت می‌شود. فیلترچی نمی‌تواند تشخیص دهد ترافیک به سمت خارج است زیرا تمام بسته‌ها به شکل HTTPS معمولی داخل ایران مبادله می‌شوند.

### ب) اصل امنیت تک‌پورت (Single-Port 443)
تمام سرویس‌های زیر بدون تداخل تنها از طریق یک پورت (**TCP 443**) در سرور ایران پاسخ داده می‌شوند:
- ترافیک وب‌سوکت کاربران عادی (`/node1`, `/node2`, ...)
- ترافیک مدرن استریم XHTTP (`/xhttp1`, ...)
- ترافیک کنترل تانل بین نود و سرور ایران (مسیر مجهول و امن ۱۲۸ بیتی مثل `/_rh/xyz`)
- پنل مدیریت گرافیکی وب تحت وب هاب (در مسیر امن `/hub/`)
- وب‌سایت شرکتی فوق‌العاده واقعی روی روت دامنه (`/`) برای فریب اسکنرهای فیلترینگ
- ترافیک گیمینگ با فناوری **L4 SNI Passthrough** بدون باز شدن TLS در ایران

---

## ۲. پیش‌نیازها و تنظیم رکوردهای DNS

| مورد | مقدار | توضیحات |
| :--- | :--- | :--- |
| **سرور ایران** | Ubuntu 20.04/22.04/24.04 یا Debian 11/12 | رم حداقل ۱ گیگابایت، دسترسی روت |
| **سرور خارج** | Ubuntu یا Debian | ترجیحاً لوکیشن با پینگ مناسب به ایران (آلمان، هلند، ترکیه، فنلاند) |
| **دامنه اصلی** | مثلاً `iran.example.com` | رکورد A در کلودفلر مستقیم به **IP سرور ایران** (پروکسی ☁️ خاموش / DNS Only) |
| **ساب‌دامین گیم** | مثلاً `game.example.com` | رکورد A در کلودفلر مستقیم به **IP سرور ایران** (پروکسی ☁️ خاموش / DNS Only) |
| **پورت‌های باز** | `80/tcp`, `443/tcp`, `443/udp` | روی سرور ایران باز باشند |

---

## ۳. بررسی و مقایسه ۳ پروتکل ارتباطی (WS / XHTTP / Vision)

| ویژگی | حالت معمولی الف (WS) | حالت معمولی ب (XHTTP) | حالت گیمینگ (Vision) |
| :--- | :--- | :--- | :--- |
| **پروتکل ارتباطی** | VLESS + WebSocket | VLESS + XHTTP (SplitHTTP) | VLESS + TCP + XTLS-Vision |
| **رفتار در فایروال** | اتصال دائمی با ارتقای WS | درخواست‌های مجزای HTTP/2 POST/GET | استتار L4 با پدینگ سایز پکت‌ها |
| **سطح استتار** | خوب (پشت دامنه با گواهی معتبر) | **حداکثر استتار** (شبیه ترافیک وب API) | عالی (رمزنگاری مستقیم بدون لایه وب) |
| **میزان تاخیر (Ping)** | دارای لایه وب (+۲۰ الی ۳۰ میلی‌ثانیه) | دارای لایه وب (+۲۰ میلی‌ثانیه) | **حداقل پینگ ممکن (0-RTT)** |
| **وضعیت UDP** | UDP بسته‌بندی‌شده در وب‌سوکت | UDP بسته‌بندی‌شده در استریم | **UDP FullCone مستقیم و آنی** |
| **سلاح ضد پکت‌لاس** | سازگار با KCP | سازگار با KCP | **KCP / UDP+FEC با استتار QUIC** |

---

## ۴. گام ۱: راه‌اندازی سرور ایران (پنل و سرور مرکزی)

روی **سرور ایران** وارد پوشه پروژه شده و نصاب پنل را اجرا کنید:

```bash
cd /root/rathole-manager/rathole-manager/rathole-manager
sudo bash install-panel.sh
```

### ثبت دامنه و دریافت گواهی SSL Let's Encrypt:
```bash
# دامنه اصلی خود را وارد کنید (مثال: iran.example.com):
sudo ratholectl cert iran.example.com admin@example.com
```

### اعمال تنظیمات پرسرعت شبکه و BBR:
```bash
sudo ratholectl tune
```

### فعال‌سازی پنل گرافیکی وب (RatholeHub):
```bash
sudo ratholectl hub on 2087
```
سپس پنل تحت وب با پروتکل امن HTTPS باز می‌شود:
👉 `https://iran.example.com/hub/`

---

## ۵. گام ۲: راه‌اندازی نود در سرور خارج

### مرحله ۱: ایجاد نود روی سرور ایران
روی سرور ایران نود اول را با پورت لوکال خارج مثلاً `10001` تعریف کنید:
```bash
sudo ratholectl add node1 10001
```
سپس دستور زیر را بزنید تا توکن و فرمان اتصال تولید شود:
```bash
sudo ratholectl token node1
```

### مرحله ۲: اجرای نصاب روی سرور خارج
روی **سرور خارج** وارد پوشه پروژه شوید:
```bash
cd /root/rathole-manager/rathole-manager/rathole-manager
sudo bash install-node.sh
```
سپس نود را با اطلاعات سرور ایران متصل کنید:
```bash
sudo ratholenode set SERVER iran.example.com:443
sudo ratholenode add-svc node1 <TOKEN_DARYAFTI> 10001
```
بررسی وضعیت اتصال در خارج:
```bash
sudo ratholenode status
```

---

## ۶. گام ۳: راه‌اندازی حالت معمولی الف - پروتکل WebSocket (WS)

روی **سرور خارج** فایل `/usr/local/etc/xray/config.json` را باز کرده و کانفیگ را قرار دهید:

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
ریستارت سرویس Xray در خارج:
```bash
systemctl restart xray
```

### لینک کلاینت VLESS WebSocket:
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?type=ws&security=tls&path=%2Fnode1&sni=iran.example.com#Iran-Normal-WS
```

---

## ۷. گام ۴: راه‌اندازی حالت معمولی ب - پروتکل فوق‌پیشرفته XHTTP (SplitHTTP)

پروتکل **XHTTP** ارتباط را به جای یک کانکشن وب‌سوکت طولانی، در قالب ریکوئست‌های استاندارد HTTP/2 POST/GET کپسوله می‌کند تا از هرگونه فیلترینگ و شناسایی مصون بماند.

روی **سرور ایران** یک سرویس برای XHTTP تعریف کنید (پورت لوکال خارج: 10003):
```bash
sudo ratholectl add xhttp1 10003
```
روی **سرور خارج** سرویس را به تانل متصل کنید:
```bash
sudo ratholenode add-svc xhttp1 <TOKEN_XHTTP1> 10003
```

در فایل `/usr/local/etc/xray/config.json` در سرور خارج، این Inbound را اضافه کنید:
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
ریستارت Xray:
```bash
systemctl restart xray
```

### لینک کلاینت VLESS XHTTP:
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?type=xhttp&security=tls&path=%2Fxhttp1&mode=auto&sni=iran.example.com#Iran-Normal-XHTTP
```

---

## ۸. گام ۵: راه‌اندازی حالت گیمینگ فوق‌سریع (L4 SNI + VLESS-Vision + UDP FullCone)

این حالت با حذف تمامی لایه‌های وب و بدون دستکاری TLS در ایران، بسته‌ها را به طور مستقیم با فناوری **0-RTT** و بدون بافرینگ مخابره می‌کند:

### ۱. تعریف سرویس گیم روی سرور ایران:
```bash
sudo ratholectl game add game1 10002 game.example.com
sudo ratholectl game cert game.example.com
```

### ۲. انتقال امن گواهی به سرور خارج:
```bash
ssh root@<NODE_IP> "mkdir -p /etc/xray-certs/game.example.com"
scp /etc/letsencrypt/live/game.example.com/fullchain.pem root@<NODE_IP>:/etc/xray-certs/game.example.com/
scp /etc/letsencrypt/live/game.example.com/privkey.pem root@<NODE_IP>:/etc/xray-certs/game.example.com/
```

### ۳. اتصال سرویس گیم به نود خارج و اجرای فال‌بک وب:
```bash
sudo ratholenode add-svc game1 <GAME_TOKEN> 10002
sudo ratholenode fakeweb start 8081
```

### ۴. کانفیگ Xray در سرور خارج (بخش گیمینگ):
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
ریستارت Xray:
```bash
systemctl restart xray
```

### لینک کلاینت گیمینگ (VLESS Vision):
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?security=tls&encryption=none&flow=xtls-rprx-vision&headerType=none&type=tcp&sni=game.example.com&fp=chrome#Iran-Game-Vision
```

---

## ۹. گام ۶: فعال‌سازی سلاح ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)

اگر در ساعات اوج مصرف اینترنت پکت‌لاس دارید و پینگ بازی دچار پرش می‌شود:
1. روی سرور ایران:
   ```bash
   sudo ufw allow 443/udp
   sudo ratholectl kcp on 443 balanced
   sudo ratholectl kcp status
   ```
2. روی سرور خارج با کلید امنیتی دریافتی از ایران:
   ```bash
   sudo ratholenode kcp on <IRAN_IP>:443 <KEY_DARYAFTI> balanced
   ```

بستر زیرساخت تانل به **UDP با استتار QUIC/HTTP3** تبدیل شده و الگوریتم تصحیح خطای Reed-Solomon تمام بسته‌های گم‌شده را بدون تأخیر بازسازی می‌کند. پکت‌لاس گیم به **صفر مطلق** می‌رسد.

---

## ۱۰. لایه‌های پیشرفته ضدفیلترینگ و عدم مسدودسازی IP و دامنه

۱. **دفاع در برابر پروب فعال (Active Probe Defense)**: اگر اسکنر فایروال به مسیرهای تانل مانند `/node1` سرک بکشد، چون درخواست معمولی وب است، به جای ارور ۴۰۰ یا ۵۰۲، پرتال شرکتی معتبر فارسی با کد **200 OK** تحویل داده می‌شود. فقط کلاینت‌های واقعی با هدر WS یا XHTTP به تانل راه پیدا می‌کنند.
۲. **پرتال شرکتی واقعی فارسی**: صفحه پیش‌فرض انگلیسی با پرتال رسمی «شرکت پیشگامان ارتباطات و داده‌های ابری پارس» با شناسه ثبت، آدرس تهران و طراحی مدرن جایگزین شده است.
۳. **رهگیری ارورهای ۵۰۲/۵۰۳**: حتی در صورت قطعی موقت سرور خارج، Nginx ارور ۵۰۲ به فایروال نشان نمی‌دهد، بلکه صفحه رسمی سایت با کد ۲۰۰ تحویل داده می‌شود.
۴. **پنهان‌سازی مشخصات وب‌سرور (`server_tokens off`)**: شماره نسخه Nginx و سیستم‌عامل از تمامی هدرها حذف شده‌اند.
۵. **سایفرهای استاندارد موزیلا**: استفاده از رمزنگاری مدرن و واگذاری اولویت انتخاب به مرورگر کاربر تا فینگرپرینت TLS کاملاً شبیه ترافیک واقعی کروم باشد.

---

## ۱۱. تنظیمات بهینه اپلیکیشن‌های کلاینت

1. **برای گیمینگ**: در نرم‌افزار v2rayNG / Sing-box / Nekobox حتماً گزینه **TUN Mode** را فعال کنید تا بسته‌های بازی و دیسکورد هدایت شوند.
2. **غیرفعال‌سازی Mux در گیمینگ**: گزینه Multiplex (Mux) را خاموش کنید تا پکت‌ها صف نبندند.
3. **برای وب‌گردی با XHTTP**: از نسخه‌های جدید نرم‌افزارها (v2rayNG نسخه 1.8.20 به بالا یا Sing-box 1.9+ یا v2rayN 6.40+) استفاده کنید.

---

## ۱۲. جعبه‌ابزار دستورات مدیریتی و عیب‌یابی

```bash
# عیب‌یابی کامل سیستم
sudo ratholectl doctor

# داشبورد وضعیت کلی پورت‌ها و نودها
sudo ratholectl status

# مشاهده لاگ‌ها بدون لو رفتن توکن‌ها
sudo ratholectl logs 50

# لیست سرویس‌های گیمینگ فعال
sudo ratholectl game ls

# تعویض توکن‌های یک نود بدون پاک شدن
sudo ratholectl rotate <name>

# تهیه بک‌آپ کامل
sudo ratholectl backup /root/backup.json
```
