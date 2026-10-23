# راهنماهای عملی (Workflow Guides)

سناریوهای رایج، گام‌به‌گام و تست‌شده روی v1.8.9. هر بخش مستقل است.

## ۱. سرویس جدید روی تونل موجود

```bash
# پنل:
sudo ratholectl add trk02 2088            # پورت داده خودکار تخصیص می‌یابد
sudo ratholectl token trk02               # توکن + دستور نصب
# نود:
ratholenode add-svc trk02 <TOKEN> 2088
# بررسی:
sudo ratholectl doctor                    # «node trk02 … amade ast»
```

سپس inbound سمت نود (3x-ui/Xray) را روی `127.0.0.1:2088` با `path=/trk02` بسازید. آدرس کاربران: `wss://<دامنه>/trk02`

## ۲. سوییچ ترنسپورت (بدون از دست دادن سرویس‌ها)

هر سوییچ دو طرفه است و snapshot + rollback دارد؛ نام سرویس‌ها/توکن‌ها/مسیر کاربران عوض نمی‌شود.

```bash
# ── KCP (UDP+FEC؛ برای اینترنت پکت‌لوس) ──
sudo ratholectl kcp on 443 balanced        # پنل → KEY چاپ می‌شود
ratholenode kcp on <iran-ip>:443 <KEY> balanced
# بازگشت:  ratholenode kcp off  +  sudo ratholectl kcp off

# ── Noise (رمزنگاری بدون cert؛ عبور از DPI certificates) ──
sudo ratholectl noise on                   # پنل → pubkey چاپ می‌شود
ratholenode noise on <iran-ip>:2334 <pubkey>
sudo ratholectl noise node trk01 on        # ثبت نود در noise-server (الزامی)
# بازگشت:  ratholenode noise off  +  sudo ratholectl noise node trk01 off  +  sudo ratholectl noise off

# ── Backhaul (SMUX؛ تک‌پورت 443، پشت nginx) ──
sudo ratholectl backhaul on                # پنل → token چاپ می‌شود (mode=nginx_tls)
ratholenode backhaul on <domain> <TOKEN> wssmux balanced
sudo ratholectl backhaul node trk01 on
# بازگشت:  ratholenode backhaul off  +  sudo ratholectl backhaul node trk01 off  +  sudo ratholectl backhaul off

# ── Plain (بدون TLS؛ وقتی گواهی مشکل دارد) ──
sudo ratholectl plain on 8880
ratholenode plain on <iran-ip>:8880
# بازگشت:  ratholenode plain off  +  sudo ratholectl plain off
```

⚠️ profile هر دو طرف باید یکی باشد. فایروال: `443/udp` برای KCP، `2334/tcp` برای Noise، پورت plain/direct برای آن حالت‌ها.

## ۳. دامنه دوم + گواهی

```bash
# با certbot (دامنه به همین پنل):
sudo ratholectl domain add www.example.ir --certbot --email admin@example.ir
# با گواهی آماده:
sudo ratholectl domain add www.example.ir --fullchain <fc> --key <k>
sudo ratholectl domain ls                   # فهرست + primary
sudo ratholectl domain primary www.example.ir
```

کاربران می‌توانند با هر دامنه وصل شوند (SNI جدا برای هر کدام ساخته می‌شود).

## ۴. نود متصل به چند سرور ایران (upstream)

```bash
# روی ایرانِ دوم:  sudo ratholectl add up2 2089  →  توکن را بردارید
# روی نود:
ratholenode upstream add up2 <iran2-host>:443 <tls_hostname>
ratholenode upstream add-svc up2 up2 <TOKEN> 2089    # نام سرویس = نام نود در آن پنل
ratholenode upstream ls
# ترنسپورت مستقل برای هر upstream:
ratholenode upstream kcp up2 on <iran2-ip>:443 <KEY> balanced
# حذف:  ratholenode upstream rm up2
```

هر upstream واحد مستقل `rathole-client@<id>` دارد؛ watchdog آن را هم پایش می‌کند.

## ۵. به‌روزرسانی بدون استرس

```bash
sudo ratholectl update stable      # پنل   (یا: ratholenode update stable روی نود)
# اگر health-check شکست بخورد خودکار rollback می‌شود — لاگ را بخوانید.
# بازگردانی دستی:  sudo bash /opt/rathole-manager/update.sh --rollback [ts]
```

## ۶. مدیریت از طریق هاب

```bash
sudo ratholectl hub on 2087        # https://<دامنه>/hub/
```

ثبت سرورها → provision با رمز SSH → اکشن‌ها از UI (restart/regen/logs/سوییچ ترنسپورت). اگر پورت 22 پنل از بیرون فیلتر است، host سرور ایران را در UI روی `127.0.0.1` ویرایش کنید — هاب از loopback مدیریت می‌کند. جزئیات: [Hub-Management](Hub-Management)
