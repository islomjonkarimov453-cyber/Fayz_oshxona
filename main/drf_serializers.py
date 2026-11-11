from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.utils import timezone
from rest_framework import serializers

from .models import (
    AppState,
    Category,
    Order,
    OrderItem,
    Product,
    Sale,
    Table,
    TableState,
    Ticket,
)
from .state import DEFAULT_PRICES


def now_ms():
    return int(timezone.now().timestamp() * 1000)


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name']


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    image = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Product
        fields = ['id', 'category', 'category_name', 'name', 'price', 'image', 'description']
        extra_kwargs = {
            'description': {'required': False, 'allow_blank': True, 'allow_null': True},
        }

    def validate_price(self, value):
        if value < 0:
            raise serializers.ValidationError('price must be zero or positive')
        return value


class TableSerializer(serializers.ModelSerializer):
    class Meta:
        model = Table
        fields = ['id', 'number', 'is_busy']
        extra_kwargs = {'is_busy': {'required': False}}

    def validate_number(self, value):
        if value <= 0:
            raise serializers.ValidationError('number must be positive')
        return value


class OrderItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)

    class Meta:
        model = OrderItem
        fields = ['id', 'order', 'product', 'product_name', 'quantity']


def _normalize_order_items(raw):
    if raw is None:
        return []
    if isinstance(raw, dict):
        raw = [{'product': key, 'quantity': value} for key, value in raw.items()]
    if not isinstance(raw, (list, tuple)):
        raise serializers.ValidationError({'items': 'items must be a list'})
    rows = []
    for row in raw:
        if not isinstance(row, dict):
            raise serializers.ValidationError({'items': 'each item must be an object'})
        product_id = row.get('product', row.get('product_id'))
        try:
            quantity = int(row.get('quantity', 1))
        except (TypeError, ValueError):
            raise serializers.ValidationError({'items': 'quantity is invalid'})
        if quantity <= 0:
            continue
        product = Product.objects.filter(pk=product_id).first()
        if product is None:
            raise serializers.ValidationError({'items': f'product not found: {product_id}'})
        rows.append((product, quantity))
    if not rows:
        raise serializers.ValidationError({'items': 'items is required'})
    return rows


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    table_number = serializers.IntegerField(source='table.number', read_only=True)
    order_type_display = serializers.CharField(source='get_order_type_display', read_only=True)
    total_price = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'table', 'table_number', 'order_type', 'order_type_display',
            'address', 'created_at', 'status', 'total_price', 'items',
        ]
        extra_kwargs = {
            'table': {'required': False, 'allow_null': True},
            'address': {'required': False, 'allow_blank': True, 'allow_null': True},
            'status': {'required': False},
            'order_type': {'required': False},
        }

    def to_internal_value(self, data):
        data = data.copy() if hasattr(data, 'copy') else dict(data)
        self._raw_items = data.pop('items', None) if hasattr(data, 'pop') else None
        return super().to_internal_value(data)

    def create(self, validated_data):
        raw_items = getattr(self, '_raw_items', None)
        items = _normalize_order_items(raw_items)
        with transaction.atomic():
            table = validated_data.get('table')
            if table is not None and validated_data.get('order_type', 'dine_in') == 'dine_in':
                table.is_busy = True
                table.save(update_fields=['is_busy'])
            order = Order.objects.create(**validated_data)
            total = Decimal('0')
            for product, quantity in items:
                OrderItem.objects.create(order=order, product=product, quantity=quantity)
                total += product.price * quantity
            order.total_price = total
            order.save(update_fields=['total_price'])
        return order

    def update(self, instance, validated_data):
        raw_items = getattr(self, '_raw_items', None)
        instance = super().update(instance, validated_data)
        if raw_items is not None:
            items = _normalize_order_items(raw_items)
            with transaction.atomic():
                instance.items.all().delete()
                for product, quantity in items:
                    OrderItem.objects.create(order=instance, product=product, quantity=quantity)
                _recalculate_order_total(instance)
        return instance


def _recalculate_order_total(order):
    total = sum(
        (item.product.price * item.quantity for item in order.items.select_related('product')),
        Decimal('0'),
    )
    order.total_price = total
    order.save(update_fields=['total_price'])
    return order


class TableStateSerializer(serializers.ModelSerializer):
    class Meta:
        model = TableState
        fields = ['table_key', 'items', 'address', 'saboy', 'linked_table']
        extra_kwargs = {
            'items': {'required': False},
            'address': {'required': False, 'allow_blank': True, 'allow_null': True},
            'saboy': {'required': False},
            'linked_table': {'required': False, 'allow_blank': True, 'allow_null': True},
        }

    def validate_items(self, value):
        if value is None:
            return {}
        if not isinstance(value, dict):
            raise serializers.ValidationError('items must be an object')
        return value


class TicketSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(required=False, min_value=1)
    table = serializers.CharField(source='table_key')
    items = serializers.JSONField()
    doneAt = serializers.IntegerField(source='done_at', required=False, allow_null=True)

    class Meta:
        model = Ticket
        fields = ['id', 'table', 'items', 'time', 'done', 'acc', 'seen', 'doneAt']
        extra_kwargs = {
            'time': {'required': False},
            'done': {'required': False},
            'acc': {'required': False},
            'seen': {'required': False},
        }

    def validate_id(self, value):
        if self.instance is None and Ticket.objects.filter(pk=value).exists():
            raise serializers.ValidationError('ticket with this id already exists')
        return value

    def validate_items(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError('items must be an object')
        return value

    def create(self, validated_data):
        done = validated_data.get('done', False)
        done_at = validated_data.get('done_at')
        if done and not done_at:
            done_at = now_ms()
        validated_data['done_at'] = done_at or None
        if not validated_data.get('time'):
            validated_data['time'] = now_ms()
        if not validated_data.get('id'):
            app_state = AppState.get_state()
            last_ticket = Ticket.objects.order_by('-id').first()
            validated_data['id'] = max(
                app_state.seq or 1,
                (last_ticket.id if last_ticket else 0) + 1,
            )
        with transaction.atomic():
            ticket = Ticket.objects.create(**validated_data)
            app_state, _ = AppState.objects.select_for_update().get_or_create(pk=1)
            if ticket.id >= (app_state.seq or 1):
                app_state.seq = ticket.id + 1
                app_state.save(update_fields=['seq'])
        return ticket


class SaleSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(required=False, min_value=1)
    table = serializers.CharField(source='table_key')
    items = serializers.JSONField()
    prices = serializers.JSONField(required=False)
    clear_table = serializers.BooleanField(write_only=True, required=False, default=True)

    class Meta:
        model = Sale
        fields = [
            'id', 'time', 'table', 'items', 'sub', 'pct', 'fee', 'total',
            'address', 'prices', 'linked_table', 'clear_table',
        ]
        extra_kwargs = {
            'time': {'required': False},
            'sub': {'required': False},
            'pct': {'required': False},
            'fee': {'required': False},
            'total': {'required': False},
            'address': {'required': False, 'allow_blank': True, 'allow_null': True},
            'linked_table': {'required': False, 'allow_blank': True, 'allow_null': True},
        }

    def validate_id(self, value):
        if self.instance is None and Sale.objects.filter(pk=value).exists():
            raise serializers.ValidationError('sale with this id already exists')
        return value

    def validate_items(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError('items must be an object')
        return value

    def validate_prices(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError('prices must be an object')
        return value

    def validate_pct(self, value):
        if value < 0 or value > 100:
            raise serializers.ValidationError('pct must be between 0 and 100')
        return value

    def create(self, validated_data):
        clear_table = validated_data.pop('clear_table', True)
        items = validated_data.get('items') or {}
        app_state = AppState.get_state()
        price_map = {**DEFAULT_PRICES, **(app_state.prices or {})}
        price_map.update(validated_data.get('prices') or {})
        try:
            price_map = {key: float(value or 0) for key, value in price_map.items()}
        except (TypeError, ValueError):
            raise serializers.ValidationError({'prices': 'prices are invalid'})
        validated_data['prices'] = price_map

        sub = validated_data.get('sub')
        if sub is None:
            sub = sum(
                (
                    Decimal(str(quantity)) * Decimal(str(price_map.get(key, 0)))
                    for key, quantity in items.items()
                    if key != '_fish' and isinstance(quantity, (int, float))
                ),
                Decimal('0'),
            )
        validated_data['sub'] = sub

        pct = validated_data.get('pct')
        if pct is None:
            pct = 0
        validated_data['pct'] = pct

        fee = validated_data.get('fee')
        if fee is None:
            fee = Decimal(round(float(sub) * pct / 100))
        validated_data['fee'] = fee

        total = validated_data.get('total')
        if total is None:
            total = Decimal(str(sub)) + Decimal(str(fee))
        validated_data['total'] = total

        if not validated_data.get('time'):
            validated_data['time'] = now_ms()
        if not validated_data.get('id'):
            last_sale = Sale.objects.order_by('-id').first()
            validated_data['id'] = (last_sale.id if last_sale else 0) + 1

        with transaction.atomic():
            sale = Sale.objects.create(**validated_data)
            if clear_table:
                TableState.objects.filter(table_key=sale.table_key).delete()
                if sale.table_key.isdigit():
                    Table.objects.filter(number=int(sale.table_key)).update(is_busy=False)
        return sale


class AppStateSerializer(serializers.ModelSerializer):
    seqS = serializers.IntegerField(source='seq_s', required=False, min_value=0)
    fishList = serializers.JSONField(source='fish_list', required=False)
    stock = serializers.JSONField(required=False)
    closedDates = serializers.JSONField(source='closed_dates', required=False)

    class Meta:
        model = AppState
        fields = ['prices', 'service', 'seq', 'seqS', 'fishList', 'stock', 'closedDates']
        extra_kwargs = {
            'prices': {'required': False},
            'service': {'required': False},
            'seq': {'required': False},
        }

    def validate_prices(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError('prices must be an object')
        result = {}
        try:
            for key, raw in value.items():
                number = float(raw)
                if number < 0:
                    raise serializers.ValidationError(f'{key} must be zero or positive')
                result[key] = int(number) if number.is_integer() else number
        except (TypeError, ValueError, InvalidOperation):
            raise serializers.ValidationError('prices are invalid')
        return result

    def validate_service(self, value):
        if value < 0 or value > 100:
            raise serializers.ValidationError('service must be between 0 and 100')
        return value

    def validate_seq(self, value):
        if value < 1:
            raise serializers.ValidationError('seq must be positive')
        return value

    def validate_fishList(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError('fishList must be a list')
        return value

    def validate_stock(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError('stock must be an object')
        result = {}
        for key, raw in value.items():
            try:
                number = float(raw)
            except (TypeError, ValueError):
                raise serializers.ValidationError(f'{key} is invalid')
            if number < 0:
                raise serializers.ValidationError(f'{key} must be zero or positive')
            result[key] = int(number) if number.is_integer() else number
        return result

    def validate_closedDates(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError('closedDates must be a list')
        return [str(item) for item in value]

    def update(self, instance, validated_data):
        if 'prices' in validated_data:
            validated_data['prices'] = {
                **DEFAULT_PRICES,
                **(instance.prices or {}),
                **validated_data['prices'],
            }
        return super().update(instance, validated_data)
