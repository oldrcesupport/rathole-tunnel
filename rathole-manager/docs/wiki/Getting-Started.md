# راهنمای شروع سریع (Getting Started)

نسخه مرجع: **1.8.9** — تست‌شده روی Ubuntu 24.04 (پنل ایران + نود خارج).

## ۱. معماری در یک نگاه

```
کاربر ──► nginx:443 (TLS + ضدپروب) ──► rathole-server (کنترل + داده)
              │                              │
              ├── /hub/  → ratholehub (127.0.0.1:8088)   پنل وب
              ├── مسیر نودها (/<name>) → پورت‌های داده (127.0.0.1:1001+)
              └── بقیه مسیرها → سایت فیک (200 OK)        دفاع ضدپروب

نود خارج: rathole-client ──wss/443──► پنل  ──► 127.0.0.1:2087 (Xray/3x-ui)
```

* کانترول تونل روی یک مسیر WebSocket مخفی (`/_rh/<hex>`) می‌رود؛ مسیر را `ratholectl set control-path` می‌توان عوض کرد.
* پورت‌های داده روی پنل فقط `127.0.0.1` هستند؛ توزیع بیرونی فقط از nginx/443.
* ترنسپورت‌ها: **ws/TLS** (پیش‌فرض)، **kcp** (UDP+FEC)، **noise** (رمزنگاری بدون cert)، **backhaul** (SMUX)، **plain** (بدون TLS)، **direct** (مسیریابی هدر). هر سوییچ snapshot + rollback خودکار دارد.

## ۲. نصب پنل

```bash
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel \
  --domain panel.example.ir --fullchain <fc.pem> --key <key.pem>
# فقط IP: نصب با IP، سپس:  sudo ratholectl ip-cert <IP>
# گواهی با certbot:        sudo ratholectl cert panel.example.ir admin@example.ir
sudo ratholectl tune       # BBR + محدودیت‌ها (پیشنهاد می‌شود)
```

## ۳. افزودن نود

```bash
sudo ratholectl add trk01 2087     # نام نود + پورت inbound سمت نود
sudo ratholectl token trk01        # دستور آماده‌ی نصب چاپ می‌شود
# همان دستور را روی سرور خارج اجرا کنید (با --tls-hostname در حالت دامنه، یا --tls-trusted-root در حالت IP)
```

سپس روی نود، inbound واقعی (VLESS+WS در 3x-ui) را با `listen=127.0.0.1`، `port=2087`، `path=/trk01` بسازید.

## ۴. پنل وب (اختیاری)

```bash
sudo ratholectl hub on 2087    # → https://<دامنه>/hub/  (رمز ادمین را تعاملی می‌پرسد)
```

## ۵. پورت‌هایی که باید باز باشند

| پورت | پروتکل | کی |
| :--- | :--- | :--- |
| 443/tcp | همیشه | nginx TLS |
| 443/udp | فقط KCP | kcptun |
| 2334/tcp | فقط Noise | rathole-noise |
| 8880/8090… | فقط plain/direct | nginx |

بقیه (2333، 8080، 2096، 1001+، 8088) لوکال‌اند و نباید باز شوند.

## ۶. بررسی نصب

```bash
sudo ratholectl doctor     # 6 چک؛ شکست‌ها exit غیرصفر
sudo ratholectl status     # داشبورد JSON/متنی
ratholenode status         # سمت نود
```

بیشتر: [مرجع CLI](CLI-Reference) · [هاب](Hub-Management) · [عیب‌یابی](Troubleshooting)
