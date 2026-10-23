# rathole-tunnel Wiki

به ویکی پروژه **rathole-tunnel** خوش آمدید — مدیریت تانل معکوس ایران ↔ خارج با هسته rathole، nginx ضدپروب و پنل وب RatholeHub. همه‌ی دستورها با نسخه **1.8.9** روی سرور واقعی تست شده‌اند.

## شروع سریع (۳ گام)

```bash
# ۱) پنل (ایران) — با دامنه و گواهی:
curl -fsSL https://raw.githubusercontent.com/oldrcesupport/rathole-tunnel/main/install.sh | sudo bash -s -- --panel \
  --domain panel.example.ir --fullchain <fc.pem> --key <key.pem>

# ۲) ساخت نود روی پنل + گرفتن دستور نصب:
sudo ratholectl add trk01 2087 && sudo ratholectl token trk01

# ۳) اجرای دستور چاپ‌شده روی سرور خارج، سپس:
sudo ratholectl doctor        # باید «node trk01 amade ast» ببینید
```

سرور بدون دامنه؟ بعد از نصب: `sudo ratholectl ip-cert <IP>` و روی نود `--tls-trusted-root`.

## صفحات ویکی

* 🚀 **[راهنمای شروع سریع](Getting-Started)** — معماری، نصب، جدول پورت‌ها
* 📖 **[مرجع کامل دستورات CLI](CLI-Reference)** — همه‌ی زیرفرمان‌های ratholectl و ratholenode
* 🌐 **[مدیریت هاب](Hub-Management)** — پنل وب، API، provision، امنیت
* 🔧 **[عیب‌یابی، بک‌آپ و رول‌بک](Troubleshooting)** — خطاهای واقعی و راه‌حل
* 🧭 **[گردش‌کارها](Workflow-Guides)** — سناریوهای روزمره (سرویس جدید، تغییر ترنسپورت، مهاجرت، به‌روزرسانی)
* 📖 **[راهنمای نصب کامل](../install-manual.fa.md)** · 🌐 **[هاب](../hub.md)** · 🏗️ **[معماری](../architecture.md)** · 🚦 **[حالت‌های ترنسپورت](../transport-modes.md)** · 📊 **[جریان ترافیک](../traffic-flow.md)**
