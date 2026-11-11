from django.db import models

class Category(models.Model):
    name  = models.CharField(max_length=100)

    def __str__(self):
        return self.name


class Product(models.Model):
    category = models.ForeignKey(
        Category, on_delete=models.CASCADE, related_name='products'
    )
    name = models.CharField(max_length=150)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    image = models.ImageField(upload_to='products/', blank=True, null=True)
    description = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.name


class Table(models.Model):
    number = models.IntegerField(unique=True)
    is_busy = models.BooleanField(default=False)

    def __str__(self):
        return f'{self.number}-stol'


class Order(models.Model):
    ORDER_TYPES = [('dine_in', 'Zal'), ('takeout', 'Sabo')]
    table = models.ForeignKey(
        Table, on_delete=models.SET_NULL, null=True, blank=True
    )
    order_type = models.CharField(max_length=20, choices=ORDER_TYPES, default='dine_in')
    address = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=50, default='Yangi')
    total_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    def __str__(self):
        return f'Buyurtma #{self.id}'


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order, on_delete=models.CASCADE, related_name='items'
    )
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)

    def __str__(self):
        return f'{self.product.name} x {self.quantity}'

class AppState(models.Model):
    prices = models.JSONField(default=dict)
    service = models.IntegerField(default=10)
    seq = models.IntegerField(default=1)
    seq_s = models.IntegerField(default=0)
    fish_list = models.JSONField(default=list)
    stock = models.JSONField(default=dict)
    _rev = models.IntegerField(default=0)

    def __str__(self):
        return f'AppState (rev: {self._rev})'

    @classmethod
    def get_state(cls):
        state, _ = cls.objects.get_or_create(id=1)
        return state

    def to_dict(self):
        return {
            'prices': self.prices,
            'service': self.service,
            'seq': self.seq,
            'seqS': self.seq_s,
            'fishList': self.fish_list or [],
            'stock': self.stock or {},
            '_rev': self._rev,
        }


class TableState(models.Model):
    table_key = models.CharField(max_length=50, unique=True)
    items = models.JSONField(default=dict)
    address = models.TextField(blank=True, null=True)
    saboy = models.BooleanField(default=False)
    linked_table = models.CharField(max_length=50, blank=True, null=True)

    def __str__(self):
        return f'TableState: {self.table_key}'

    def to_dict(self):
        result = {'items': self.items}
        if self.address:
            result['address'] = self.address
        if self.saboy:
            result['saboy'] = True
        if self.linked_table:
            result['linked_table'] = self.linked_table
        return result


class Ticket(models.Model):
    id = models.IntegerField(primary_key=True)
    table_key = models.CharField(max_length=50)
    items = models.JSONField(default=dict)
    time = models.BigIntegerField()
    done = models.BooleanField(default=False)
    acc = models.BooleanField(default=False)
    seen = models.BooleanField(default=False)
    done_at = models.BigIntegerField(null=True, blank=True)

    def __str__(self):
        return f'Ticket #{self.id} - {self.table_key}'

    def to_dict(self):
        result = {
            'id': self.id,
            'table': self.table_key,
            'items': self.items,
            'time': self.time,
            'done': self.done,
            'acc': self.acc,
            'seen': self.seen,
        }
        if self.done_at:
            result['doneAt'] = self.done_at
        return result


class Sale(models.Model):
    id = models.IntegerField(primary_key=True)
    time = models.BigIntegerField()
    table_key = models.CharField(max_length=50)
    items = models.JSONField(default=dict)
    sub = models.DecimalField(max_digits=12, decimal_places=2)
    pct = models.IntegerField(default=0)
    fee = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2)
    address = models.TextField(blank=True, null=True)
    prices = models.JSONField(default=dict)
    linked_table = models.CharField(max_length=50, blank=True, null=True)

    def __str__(self):
        return f'Sale #{self.id} - {self.table_key}'

    def to_dict(self):
        result = {
            'id': self.id,
            'time': self.time,
            'table': self.table_key,
            'items': self.items,
            'sub': float(self.sub),
            'pct': self.pct,
            'fee': float(self.fee),
            'total': float(self.total),
            'prices': self.prices,
        }
        if self.address:
            result['address'] = self.address
        if self.linked_table:
            result['linked_table'] = self.linked_table
        return result

