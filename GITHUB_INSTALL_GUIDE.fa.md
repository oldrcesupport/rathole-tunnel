# راهنمای مدرن نصب و راه‌اندازی از طریق گیت‌هاب (GitHub Installation)
## پروژه تانل معکوس چندمنظوره Rathole Manager
### (شامل روش آپلود در گیت‌هاب، کلون یک‌خطی روی سرورها، WS، XHTTP و گیمینگ فوق‌سریع)

آپلود پروژه روی **گیت‌هاب (GitHub)** و نصب مستقیم از طریق آن، استانداردترین و راحت‌ترین شیوه استقرار روی سرورهای ابری است. با این روش دیگر نیازی به آپلود فایل زیپ یا دستور `scp` ندارید و بروزرسانی تمامی سرورها تنها با دستور `git pull` در چند ثانیه انجام می‌شود.

---

## فهرست مطالب
1. [چرا نصب از طریق گیت‌هاب بهتر است؟](#۱-چرا-نصب-از-طریق-گیت‌هاب-بهتر-است)
2. [روش آپلود پروژه در مخزن شخصی گیت‌هاب](#۲-روش-آپلود-پروژه-در-مخزن-شخصی-گیت‌هاب)
3. [نصب سرور ایران از طریق گیت‌هاب](#۳-نصب-سرور-ایران-از-طریق-گیت‌هاب)
4. [نصب سرور خارج از طریق گیت‌هاب](#۴-نصب-سرور-خارج-از-طریق-گیت‌هاب)
5. [پیکربندی ترافیک عادی الف: پروتکل WebSocket (WS)](#۵-پیکربندی-ترافیک-عادی-الف-پروتکل-websocket-ws)
6. [پیکربندی ترافیک عادی ب: پروتکل نوین XHTTP (SplitHTTP)](#۶-پیکربندی-ترافیک-عادی-ب-پروتکل-نوین-xhttp-splithttp)
7. [پیکربندی حالت گیمینگ فوق‌سریع (VLESS-Vision + FullCone UDP)](#۷-پیکربندی-حالت-گیمینگ-فوق‌سریع-vless-vision--fullcone-udp)
8. [فعال‌سازی ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)](#۸-فعال‌سازی-ضد-پکت‌لاس-گیم-kcp--udpfec-روی-پورت-443)
9. [روش بروزرسانی آنی سرورها با گیت‌هاب (Update Workflow)](#۹-روش-بروزرسانی-آنی-سرورها-با-گیت‌هاب-update-workflow)

---

## ۱. چرا نصب از طریق گیت‌هاب بهتر است؟

1. **بدون نیاز به انتقال فایل**: بدون نیاز به نرم‌افزارهای SFTP یا دستورات طولانی SCP، تنها با یک دستور کلون، پروژه در سرور مستقر می‌شود.
2. **بروزرسانی آنی و یکپارچه**: با زدن `git pull` روی هر سرور، تمام آخرین تغییرات و بهینه‌سازی‌ها فوراً اعمال می‌شوند.
3. **دور زدن محدودیت‌های ایران با میرور**: اسکریپت‌های پروژه دارای سیستم هوشمند استفاده از میرورهای پرسرعت گیت‌هاب (`ghproxy.net` و `mirror.ghproxy.com`) هستند، بنابراین حتی در صورت فیلتر بودن گیت‌هاب در دیتاسنترهای داخلی، دانلودها بدون مشکل انجام می‌شوند.

---

## ۲. روش آپلود پروژه در مخزن شخصی گیت‌هاب

اگر می‌خواهید این سورس را در گیت‌هاب شخصی خودتان نگه دارید:

### الف) ساخت مخزن در سایت GitHub:
1. وارد سایت [GitHub.com](https://github.com) شوید و لاگین کنید.
2. روی دکمه **New repository** کلیک کنید.
3. یک نام انتخاب کنید (مثلاً `my-rathole`).
4. نوع مخزن را می‌توانید **Private (خصوصی)** یا **Public (عمومی)** بگذارید.
5. دکمه **Create repository** را بزنید.

### ب) ارسال فایل‌ها از سیستم لوکال خود به مخزن:
داخل پوشه پروژه روی سیستم خود ترمینال را باز کنید:
```bash
git remote add origin https://github.com/oldrcesupport/rathole-tunnel.git
git push -u origin main
```

---

## ۳. نصب سرور ایران از طریق گیت‌هاب

وارد SSH سرور ایران شوید و دستورات زیر را اجرا کنید:

```bash
# نصب پکیج‌های پایه
apt-get update -y && apt-get install -y git curl

# کلون مخزن (در صورت مسدود بودن گیت‌هاب در ایران، از میرور زیر استفاده کنید):
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager
# یا با میرور ضدتحریم:
# git clone https://ghproxy.net/https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager

# ورود به پوشه و اجرای نصاب پنل
cd /root/rathole-manager
sudo bash install-panel.sh
```

### تنظیم دامنه و گواهی SSL در سرور ایران:
```bash
# دامنه خود را که به IP ایران متصل است ثبت کنید (مثال: iran.example.com):
sudo ratholectl cert iran.example.com admin@example.com

# بهینه‌سازی سرعت هسته (BBR):
sudo ratholectl tune

# راه‌اندازی پنل گرافیکی وب:
sudo ratholectl hub on 2087
```
حالا پنل تحت وب با آدرس `https://iran.example.com/hub/` در دسترس شماست.

---

## ۴. نصب سرور خارج از طریق گیت‌هاب

### گام ۱: ساخت نود روی سرور ایران
روی سرور ایران، یک نود جدید بسازید:
```bash
sudo ratholectl add node1 10001
```
سپس دستور زیر را بزنید تا اطلاعات و توکن نمایش داده شود:
```bash
sudo ratholectl token node1
```

### گام ۲: نصب روی سرور خارج با گیت‌هاب
وارد SSH سرور خارج شوید و دستورات زیر را وارد کنید:
```bash
apt-get update -y && apt-get install -y git curl
git clone https://github.com/oldrcesupport/rathole-tunnel.git /root/rathole-manager
cd /root/rathole-manager
sudo bash install-node.sh
```

سپس نود را به سرور ایران متصل کنید:
```bash
sudo ratholenode set SERVER iran.example.com:443
sudo ratholenode add-svc node1 <TOKEN_DARYAFTI> 10001
```
برای بررسی اتصال نود:
```bash
sudo ratholenode status
```

---

## ۵. پیکربندی ترافیک عادی الف: پروتکل WebSocket (WS)

پروتکل کلاسیک برای وب‌گردی و تمامی دستگاه‌ها.

روی **سرور خارج**، فایل `/usr/local/etc/xray/config.json` را باز کنید:
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
ریستارت Xray در خارج:
```bash
systemctl restart xray
```

### لینک اتصال کلاینت:
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?type=ws&security=tls&path=%2Fnode1&sni=iran.example.com#Normal-WS
```

---

## ۶. پیکربندی ترافیک عادی ب: پروتکل نوین XHTTP (SplitHTTP)

### چرا XHTTP پیشنهاد می‌شود؟
در اپراتورهایی که وب‌سوکت دچار افت سرعت یا اختلال عمدی است، پروتکل **XHTTP** ترافیک را در قالب درخواست‌های مجزای HTTP/2 POST ارسال می‌کند. فایروال این ترافیک را دقیقاً مانند دانلود/آپلود معمولی در یک وب‌سایت در نظر می‌گیرد و هیچ‌گونه حساسیتی نشان نمی‌دهد.

یک سرویس جدید مثلاً به نام `xhttp1` با پورت `10003` تعریف کنید:
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
ریستارت Xray در خارج:
```bash
systemctl restart xray
```

### لینک اتصال کلاینت (VLESS XHTTP):
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?type=xhttp&security=tls&path=%2Fxhttp1&mode=auto&sni=iran.example.com#Normal-XHTTP
```

---

## ۷. پیکربندی حالت گیمینگ فوق‌سریع (VLESS-Vision + FullCone UDP)

مخصوص بازی‌های آنلاین بدون کوچک‌ترین افت پینگ:

### ۱. تعریف در سرور ایران با ساب‌دامین اختصاصی گیم:
```bash
# روی ایران:
sudo ratholectl game add game1 10002 game.example.com
sudo ratholectl game cert game.example.com
```

### ۲. انتقال گواهی به خارج:
```bash
ssh root@<NODE_IP> "mkdir -p /etc/xray-certs/game.example.com"
scp /etc/letsencrypt/live/game.example.com/fullchain.pem root@<NODE_IP>:/etc/xray-certs/game.example.com/
scp /etc/letsencrypt/live/game.example.com/privkey.pem root@<NODE_IP>:/etc/xray-certs/game.example.com/
```

### ۳. افزودن سرویس گیم به نود خارج:
```bash
# روی خارج:
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

### لینک اتصال گیمینگ:
```text
vless://e8a93cb4-56c2-48df-b118-86d1d4cb8040@iran.example.com:443?security=tls&encryption=none&flow=xtls-rprx-vision&headerType=none&type=tcp&sni=game.example.com&fp=chrome#Game-Vision-Direct
```

---

## ۸. فعال‌سازی ضد پکت‌لاس گیم (KCP / UDP+FEC روی پورت 443)

در ساعات شلوغی شبکه که پکت‌لاس ایجاد می‌شود:
1. روی سرور ایران:
   ```bash
   sudo ufw allow 443/udp
   sudo ratholectl kcp on 443 balanced
   sudo ratholectl kcp status
   ```
2. روی سرور خارج با کلید دریافتی از ایران:
   ```bash
   sudo ratholenode kcp on <IRAN_IP>:443 <KEY> balanced
   ```

ترافیک تانل با الگوی QUIC گوگل رد شده و با تصحیح خطای ریاضی Reed-Solomon، پکت‌لاس به صورت کامل مهار می‌شود.

---

## ۹. روش بروزرسانی آنی سرورها با گیت‌هاب (Update Workflow)

هر زمان که تغییری در کدها ایجاد کرده و روی گیت‌هاب Push کردید، روی هر سرور کافیست دستور زیر را بزنید:

```bash
cd /root/rathole-manager
git pull
sudo ratholectl regen
```
کلیه سرویس‌ها بدون حتی یک ثانیه قطعی برای کاربران آنلاین (Zero-Downtime Reload) بروزرسانی می‌شوند.
