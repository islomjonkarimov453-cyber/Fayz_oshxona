from django.contrib import admin

from .models import AppState, Category, Order, OrderItem, Product, Sale, Table, TableState, Ticket

admin.site.register(Category)
admin.site.register(Product)
admin.site.register(Table)
admin.site.register(Order)
admin.site.register(OrderItem)
admin.site.register(AppState)
admin.site.register(TableState)
admin.site.register(Ticket)
admin.site.register(Sale)
