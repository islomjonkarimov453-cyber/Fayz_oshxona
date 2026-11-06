import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from main.models import Category, Product, Table

# Create tables
for i in range(1, 11):
    Table.objects.get_or_create(number=i)

# Create categories
cat1, _ = Category.objects.get_or_create(name="Baliq")
cat2, _ = Category.objects.get_or_create(name="Salat")
cat3, _ = Category.objects.get_or_create(name="Ichimlik")

# Create products
products = [
    ("Baliq 1.5 kg", 150000, cat1),
    ("Baliq 2 kg", 200000, cat1),
    ("Baliq 3 kg", 300000, cat1),
    ("Chuchvara baliq", 120000, cat1),
    ("Kabob baliq", 180000, cat1),
    ("Sezar salat", 35000, cat2),
    ("Grecheskiy salat", 30000, cat2),
    ("Coca Cola", 10000, cat3),
    ("Fanta", 10000, cat3),
    ("Suv", 5000, cat3),
]

for name, price, category in products:
    Product.objects.get_or_create(name=name, price=price, category=category)

print("Ma'lumotlar qo'shildi!")
