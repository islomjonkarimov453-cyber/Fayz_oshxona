# Fayz Baliqxona REST API (Django REST Framework)

Barcha API manzillari: `http://<server-ip>:8000/api/v1/`

- Autentifikatsiya: hozircha ochiq (`AllowAny`).
- Format: `application/json`. Rasm yuklash uchun `multipart/form-data`.
- Brauzerda ochish mumkin (DRF Browsable API): `http://<server-ip>:8000/api/v1/`
- Har bir yozish amali umumiy `state` revision'ini oshiradi (`GET /api/v1/state/` dagi `rev`).

## Resurslar

| Resurs | Manzil | Metodlar |
|---|---|---|
| Kategoriyalar | `/api/v1/categories/` | GET, POST |
| Kategoriya | `/api/v1/categories/{id}/` | GET, PUT, PATCH, DELETE |
| Mahsulotlar | `/api/v1/products/` | GET, POST |
| Mahsulot | `/api/v1/products/{id}/` | GET, PUT, PATCH, DELETE |
| Stollar | `/api/v1/tables/` | GET, POST |
| Stol | `/api/v1/tables/{id}/` | GET, PUT, PATCH, DELETE |
| Stolni ochish | `/api/v1/tables/{id}/open/` | POST |
| Stolni yopish | `/api/v1/tables/{id}/close/` | POST |
| Buyurtmalar | `/api/v1/orders/` | GET, POST |
| Buyurtma | `/api/v1/orders/{id}/` | GET, PUT, PATCH, DELETE |
| Buyurtma tayyor | `/api/v1/orders/{id}/complete/` | POST |
| Buyurtmaga taom qo'shish | `/api/v1/orders/{id}/items/` | POST |
| Buyurtmadan taom o'chirish | `/api/v1/orders/{id}/items/{item_id}/` | DELETE |
| Oshxona ticketlari | `/api/v1/tickets/` | GET, POST |
| Ticket | `/api/v1/tickets/{id}/` | GET, PUT, PATCH, DELETE |
| Ticketni qabul qilish | `/api/v1/tickets/{id}/accept/` | POST |
| Ticket tayyor | `/api/v1/tickets/{id}/ready/` | POST |
| Ticket ko'rildi | `/api/v1/tickets/{id}/seen/` | POST |
| Sotuvlar | `/api/v1/sales/` | GET, POST |
| Sotuv | `/api/v1/sales/{id}/` | GET, DELETE |
| Stol holatlari | `/api/v1/table-states/` | GET, POST |
| Stol holati | `/api/v1/table-states/{table_key}/` | GET, PUT, PATCH, DELETE |
| Sozlamalar | `/api/v1/settings/` | GET, PUT, PATCH |
| Sozlamalarni reset | `/api/v1/settings/reset/` | POST |
| Statistika (umumiy) | `/api/v1/stats/summary/` | GET |
| Statistika (baliq) | `/api/v1/stats/fish/` | GET |
| Statistika (non/ichimlik) | `/api/v1/stats/other/` | GET |
| Holat snapshot | `/api/v1/state/` | GET |
| Health check | `/api/v1/health/` | GET |

## Filtrlar

- `GET /api/v1/products/?category=1&search=sazan`
- `GET /api/v1/orders/?status=Yangi&order_type=dine_in&table=1`
- `GET /api/v1/tickets/?done=false&acc=true&table=S1`
- `GET /api/v1/sales/?period=today|week|all&from=<ms>&to=<ms>`
- `GET /api/v1/stats/summary/?period=today|week|all`

## Misollar

### Mahsulot yaratish

```bash
curl -X POST http://127.0.0.1:8000/api/v1/products/ \
  -H 'Content-Type: application/json' \
  -d '{"category":1,"name":"Sazan","price":"80000","description":"Yangi"}'
```

### Buyurtma yaratish

```bash
curl -X POST http://127.0.0.1:8000/api/v1/orders/ \
  -H 'Content-Type: application/json' \
  -d '{
    "table": 1,
    "order_type": "dine_in",
    "items": [{"product": 1, "quantity": 2}]
  }'
```

### Oshxona ticketi

```bash
curl -X POST http://127.0.0.1:8000/api/v1/tickets/ \
  -H 'Content-Type: application/json' \
  -d '{"table":"1","items":{"sazan":0.5}}'

curl -X POST http://127.0.0.1:8000/api/v1/tickets/1/accept/
curl -X POST http://127.0.0.1:8000/api/v1/tickets/1/ready/
curl -X POST http://127.0.0.1:8000/api/v1/tickets/1/seen/
```

### Sotuv (chek) yaratish

`clear_table` standart holatda `true` — sotuvdan keyin stol holati tozalanadi.

```bash
curl -X POST http://127.0.0.1:8000/api/v1/sales/ \
  -H 'Content-Type: application/json' \
  -d '{
    "table": "1",
    "items": {"sazan": 1, "non": 2},
    "pct": 10,
    "prices": {"sazan": 80000, "non": 3000}
  }'
```

### Stol holati (ofitsiant ekrani)

```bash
curl -X PATCH http://127.0.0.1:8000/api/v1/table-states/1/ \
  -H 'Content-Type: application/json' \
  -d '{"items":{"sazan":0.5,"non":2}}'
```

### Sozlamalar

```bash
curl http://127.0.0.1:8000/api/v1/settings/

curl -X PATCH http://127.0.0.1:8000/api/v1/settings/ \
  -H 'Content-Type: application/json' \
  -d '{"service":12,"prices":{"sazan":85000}}'
```

### Holat snapshot (frontend polling)

```bash
curl http://127.0.0.1:8000/api/v1/state/
```

Javob:

```json
{
  "rev": 12,
  "state": {
    "prices": {"sazan": 80000, "oq": 90000},
    "tables": {"1": {"items": {"sazan": 0.5}, "address": "", "saboy": false}},
    "tickets": [],
    "sales": [],
    "seq": 3,
    "seqS": 1,
    "service": 10,
    "_rev": 12
  }
}
```

## Frontend

`static/js/app.js` endi barcha o'qish/yozish amallarini `/api/v1/` orqali bajaradi:

- Ro'yxat/snapshot: `GET /api/v1/state/` (har 2 sekundda polling).
- Stol holati: `POST/PATCH/DELETE /api/v1/table-states/...`.
- Oshxona: `POST /api/v1/tickets/`, `accept/`, `ready/`, `seen/`.
- Chek: `POST /api/v1/sales/`.
- Sozlamalar: `GET/PATCH /api/v1/settings/`, `POST /api/v1/settings/reset/`.

## Eski endpointlar

`/api/...` (masalan `/api/state`, `/api/products/`) moslik uchun saqlangan.
Yangi integratsiyalar uchun `/api/v1/...` dan foydalaning.
