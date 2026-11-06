#!/usr/bin/env bash
# Django serverni telefonlar ham ulana oladigan qilib ishga tushirish.
set -e
cd "$(dirname "$0")"

if [ -d .venv ]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"

echo "=============================================="
echo "  Orzu Baliqxonasi serveri ishga tushmoqda"
echo "  Telefon uchun manzil: http://$IP:8000"
echo "  (telefon va kompyuter bir Wi-Fi tarmog'ida bo'lsin)"
echo "=============================================="

python manage.py migrate --noinput
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

# PWA uchun HTTPS proxy (port 8443)
if [ -f ssl_proxy.py ]; then
  python ssl_proxy.py &
  PROXY_PID=$!
  trap "kill $DJANGO_PID $PROXY_PID 2>/dev/null" EXIT
fi

wait $DJANGO_PID
