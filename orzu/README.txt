FAYZ BALIQXONASI - 3 ta kompyuterda ishlash (Ofitsiant / Oshpaz / Admin)

1) Asosiy kompyuterga (server) Node.js ni oʻrnating: https://nodejs.org (LTS)
2) Shu papkadagi start.bat ni ikki marta bosing (yoki: node server.js)
3) Oynada manzillar chiqadi, masalan:
     Ofitsiant: http://192.168.1.10:3000/waiter
     Oshpaz:    http://192.168.1.10:3000/cook
     Admin:     http://192.168.1.10:3000/admin
4) Har bir kompyuterda (bir xil Wi-Fi yoki kabel tarmogʻida) oʻz manzilini brauzerda oching.
   Har bir sahifa faqat oʻz vazifasini koʻrsatadi.

Eslatma:
- Server kompyuteri yoqilgan va start.bat ishlab turishi kerak.
- Windows xavfsizlik oynasi chiqsa "Ruxsat berish" (Allow) ni bosing.
- Admin paroli: 1234. Oʻzgartirish: server.js boshidagi ADMIN_PASS (yoki ADMIN_PASS muhit oʻzgaruvchisi).
- Maʼlumotlar data.json faylida saqlanadi (zaxira nusxa oling).
- Serverning IP manzili oʻzgarmasligi uchun routerda shu kompyuterga doimiy IP bering.

Yangi:
- Ofitsiant avval SABOY yoki HONA ni tanlaydi. Saboyga xizmat haqi olinmaydi.
- Oshpaz sahifasida yangi buyurtma kelganda ovoz chiqadi va "Qabul qildim" bosilguncha har 5 soniyada takrorlanadi.
- Brauzer qoidasi: har safar sahifa ochilganda "Ovozni yoqish" tugmasini bir marta bosing.
