# Redis va Celery o'rnatish bo'yicha ko'rsatmalar

## 1. Redis o'rnatish (macOS)

```bash
brew install redis
brew services start redis
```

Redis ishlayotganini tekshirish:
```bash
redis-cli ping
# Javob: PONG
```

## 2. Python paketlarini o'rnatish

```bash
source .venv/bin/activate
pip install -r requirements.txt
```

## 3. Celery worker ni ishga tushirish

Terminalda yangi oynani oching va quyidagi buyruqni bajaring:

```bash
celery -A config worker -l info
```

## 4. Django serverini ishga tushirish

Boshqa terminalda:

```bash
python manage.py runserver
```

## 5. Redis va Celery ishlashini tekshirish

Redis ishlayotganini tekshirish:
```bash
redis-cli monitor
```

Celery loglarida tasklar ko'rinishi kerak.

## Muhim eslatmalar

- Redis har doim ishlayotgan bo'lishi kerak (`brew services start redis`)
- Celery worker har doim ishlayotgan bo'lishi kerak (background process)
- State endi Redis'da saqlanadi, file'da emas
- Celery tasks async tarzda ishlaydi (notificationlar uchun)
