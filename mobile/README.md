# Orzu Baliqxonasi — Flutter mobil ilova

Django backend (`Orzu_Baliqxona`) bilan ishlaydigan mobil ilova. Veb-versiyadagi
uch rol (Ofitsiant, Oshpaz, Admin) to'liq Flutter'ga ko'chirilgan.

## Imkoniyatlar

- **Ofitsiant** — 7 hona va saboy buyurtmalari, miqdor kiritish, oshxonaga
  yuborish, xizmat haqi hisobi, chek chiqarish.
- **Oshpaz** — yangi buyurtmalar (ovozli signal bilan), qabul qilish,
  "baliq pishdi" belgilash, saboy uchun manzil kiritish.
- **Admin** — bugun / 7 kun / hammasi bo'yicha statistika, baliq hisoboti,
  non va ichimlik hisoboti, sotuvlar tarixi, narxlar va xizmat foizi.
- Har 2 sekundda server bilan avtomatik sinxronizatsiya.

## 1. Server ishga tushirish

Kompyuterda (loyiha ildizida):

```bash
source .venv/bin/activate
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

`0.0.0.0:8000` muhim — shunda telefon ham serverga ulana oladi.

Kompyuterning Wi-Fi IP manzilini aniqlang:

```bash
ipconfig getifaddr en0
```

Masalan `192.168.1.25` bo'lsa, ilovadagi manzil:
`http://192.168.1.25:8000`

## 2. Ilovani ishga tushirish

```bash
cd mobile
flutter pub get
flutter run
```

Telefon va kompyuter bitta Wi-Fi tarmog'ida bo'lishi kerak.
Birinchi ochilishda **"Serverni sozlash"** tugmasi orqali manzilni kiriting.

- Android emulyatorida: `http://10.0.2.2:8000` (standart qiymat).
- iOS simulyatorida: `http://127.0.0.1:8000` (standart qiymat).
- Haqiqiy telefonda: `http://<kompyuter-IP>:8000`.

## 3. APK yig'ish

```bash
cd mobile
flutter build apk --release
```

Tayyor fayl: `build/app/outputs/flutter-apk/app-release.apk`

## 4. iOS

```bash
cd mobile
flutter build ios --release
```

Xcode'da imzo (signing) sozlangandan keyin qurilma yoki App Store uchun
yig'ish mumkin.

## Tuzilma

```
lib/
  main.dart                 — kirish nuqtasi
  api.dart                  — REST API mijozi
  store.dart                — umumiy holat + 2 sekundlik polling
  models.dart               — API modellari
  constants.dart            — mahsulotlar, narxlar, formatlash
  theme.dart                — light/dark mavzu (veb ranglari)
  sound.dart                — ovozli signal
  widgets.dart              — umumiy widgetlar va chek oynasi
  screens/
    role_screen.dart        — rol tanlash + server sozlamasi
    home_shell.dart         — pastki navigatsiya
    waiter_screen.dart      — honalar
    order_editor_screen.dart— buyurtma tahrirlash
    cook_screen.dart        — oshxona
    admin_screen.dart       — statistika va sozlamalar
```

## Eslatma

Backend manzili ilova ichida saqlanadi (`shared_preferences`), shuning uchun
har safar kiritish shart emas. Server manzilini yuqori o'ng menyudan
o'zgartirish mumkin.
