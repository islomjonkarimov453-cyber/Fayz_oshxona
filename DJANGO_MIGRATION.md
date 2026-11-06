# Django Migration - JSON to Database

## Overview
Barcha JSON formatdagi state ma'lumotlari Django modelsiga ko'chirildi. Endi ma'lumotlar database'da saqlanadi, JSON file'da emas.

## Qo'shilgan Django Models

### 1. AppState
Global app state - narxlar, xizmat haqi, sequence raqamlari
- `prices`: JSONField - barcha mahsulot narxlari
- `service`: Integer - xizmat haqi foizi
- `seq`: Integer - buyurtma sequence raqami
- `seq_s`: Integer - sabo sequence raqami
- `_rev`: Integer - state revision raqami

### 2. TableState
Hona va sabo state - items va manzil
- `table_key`: CharField - '1', '2', ... yoki 'S1', 'S2', ...
- `items`: JSONField - honadagi mahsulotlar
- `address`: TextField - manzil (sabo uchun)
- `saboy`: Boolean - sabo yoki yo'q

### 3. Ticket
Oshpazga yuborilgan buyurtmalar
- `id`: Integer (primary key) - ticket ID
- `table_key`: CharField - hona/sabo key
- `items`: JSONField - buyurtma items
- `time`: BigInteger - timestamp
- `done`: Boolean - tayyor bo'ldimi
- `acc`: Boolean - oshpaz qabul qildimi
- `seen`: Boolean - ofitsiant ko'rdimi
- `done_at`: BigInteger - tayyor bo'lgan vaqt

### 4. Sale
Tugatilgan buyurtmalar tarixi
- `id`: Integer (primary key) - sale ID
- `time`: BigInteger - timestamp
- `table_key`: CharField - hona/sabo key
- `items`: JSONField - buyurtma items
- `sub`: Decimal - taomlar summasi
- `pct`: Integer - xizmat foizi
- `fee`: Decimal - xizmat haqi
- `total`: Decimal - jami summa
- `address`: TextField - manzil
- `prices`: JSONField - o'sha paytdagi narxlar

## O'zgartirilgan Views

### load_state_from_db()
Endi state JSON file'dan emas, Django modelsdan yuklanadi:
- AppState'dan narxlar, service, seq raqamlar
- TableState'dan barcha honalar
- Ticket'dan barcha tickets
- Sale'dan barcha sales

### save_state_to_db()
State Django modelsga saqlanadi:
- AppState yangilanadi
- TableState yangilanadi/yaratiladi
- Ticket yangilanadi/yaratiladi
- Sale yangilanadi/yaratiladi

### api_state()
GET va POST requestlar endi DB'dan ishlaydi:
- GET: load_state_from_db() chaqiradi
- POST: save_state_to_db() chaqiradi

## Migratsiyalar

```bash
python3 manage.py makemigrations
python3 manage.py migrate
```

Migratsiya muvaffaqiyatli yakunlandi: `main.0010_appstate_sale_tablestate_ticket`

## Redis va Celery

Redis va Celery hali o'rnatilmagan bo'lsa ham loyiha ishlaydi:
- Fallback cache (LocMemCache) ishlatiladi
- Celery tasks try-except bilan qo'shildi
- Paketlar o'rnatilgandan keyin Redis/Celery yoqilishi mumkin

Paketlarni o'rnatish:
```bash
pip install -r requirements.txt
```

Redis o'rnatish (macOS):
```bash
brew install redis
brew services start redis
```

Celery worker ishga tushirish:
```bash
celery -A config worker -l info
```

## Frontend

Frontend (app.js) to'liq REST API'ga o'tkazildi:

- O'qish: `GET /api/v1/state/` (snapshot + polling)
- Yozish: `/api/v1/table-states/`, `/api/v1/tickets/`, `/api/v1/sales/`, `/api/v1/settings/`

Batafsil: `API.md`. Eski `/api/state` endpoint moslik uchun saqlangan.

## Xavfsizlik

- Barcha ma'lumotlar database'da saqlanadi
- JSON file dependency olib tashlandi
- Transaction atomic ishlatiladi (data integrity uchun)
- Redis/Celery optional - yo'q bo'lsa ham ishlaydi

## Keyingi Qadamlar

1. Redis o'rnatish (ixtiyoriy, lekin tavsiya etiladi)
2. Celery worker ishga tushirish (ixtiyoriy)
3. Serverni ishga tushirish: `python3 manage.py runserver`
4. Test qilish - barcha funksiyalar ishlashi kerak
