from decimal import Decimal, InvalidOperation

from django.utils import timezone

from .models import AppState, Category, Order, Product, Sale, Table, TableState, Ticket
from .state import DEFAULT_PRICES, as_bool, as_int

ORDER_TYPE_KEYS = {value for value, _ in Order.ORDER_TYPES}


def _image_url(obj, request=None):
    if not obj.image:
        return None
    try:
        if request is not None:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url
    except ValueError:
        return None


def category_dict(obj):
    return {
        'id': obj.id,
        'name': obj.name,
    }


def product_dict(obj, request=None):
    return {
        'id': obj.id,
        'category': obj.category_id,
        'category_name': obj.category.name if obj.category_id else None,
        'name': obj.name,
        'price': str(obj.price),
        'image': _image_url(obj, request),
        'description': obj.description or '',
    }


def table_dict(obj):
    return {
        'id': obj.id,
        'number': obj.number,
        'is_busy': obj.is_busy,
    }


def order_item_dict(obj):
    return {
        'id': obj.id,
        'order': obj.order_id,
        'product': obj.product_id,
        'product_name': obj.product.name if obj.product_id else None,
        'quantity': obj.quantity,
    }


def order_dict(obj):
    return {
        'id': obj.id,
        'table': obj.table_id,
        'table_number': obj.table.number if obj.table_id else None,
        'order_type': obj.order_type,
        'order_type_display': obj.get_order_type_display(),
        'address': obj.address or '',
        'created_at': obj.created_at.isoformat() if obj.created_at else None,
        'status': obj.status,
        'total_price': str(obj.total_price),
        'items': [order_item_dict(item) for item in obj.items.all()],
    }


def table_state_dict(obj):
    return {
        'table_key': obj.table_key,
        'items': obj.items or {},
        'address': obj.address or '',
        'saboy': obj.saboy,
        'linked_table': obj.linked_table or '',
    }


def ticket_dict(obj):
    return obj.to_dict()


def sale_dict(obj):
    return obj.to_dict()


def app_state_dict(obj):
    return obj.to_dict()


def _text(data, key, label=None):
    value = data.get(key)
    if value is None:
        raise ValueError(f'{label or key} is required')
    value = str(value).strip()
    if not value:
        raise ValueError(f'{label or key} is required')
    return value


def _decimal(value, label='value'):
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise ValueError(f'{label} is invalid')


def _plain_number(value, label='value'):
    number = _decimal(value, label)
    if number == number.to_integral_value():
        return int(number)
    return float(number)


def category_fields(data, partial=False):
    fields = {}
    if 'name' in data or not partial:
        fields['name'] = _text(data, 'name')
    return fields


def product_fields(data, partial=False):
    fields = {}
    if 'category' in data or 'category_id' in data or not partial:
        category_id = data.get('category', data.get('category_id'))
        category = Category.objects.filter(pk=as_int(category_id, 0)).first()
        if category is None:
            raise ValueError('category not found')
        fields['category'] = category
    if 'name' in data or not partial:
        fields['name'] = _text(data, 'name')
    if 'price' in data or not partial:
        price = _decimal(data.get('price'), 'price')
        if price < 0:
            raise ValueError('price must be zero or positive')
        fields['price'] = price
    if 'description' in data or not partial:
        fields['description'] = data.get('description') or ''
    if 'image' in data or not partial:
        image = data.get('image')
        if image in (None, ''):
            fields['image'] = None
        else:
            fields['image'] = image
    return fields


def table_fields(data, partial=False):
    fields = {}
    if 'number' in data or not partial:
        number = as_int(data.get('number'), None)
        if number is None or number <= 0:
            raise ValueError('number is required')
        fields['number'] = number
    if 'is_busy' in data or not partial:
        fields['is_busy'] = as_bool(data.get('is_busy', False))
    return fields


def _raw_order_items(data):
    raw = data.get('items')
    if raw is None:
        product_ids = data.get('product_ids') or []
        quantities = data.get('quantities') or []
        if not isinstance(product_ids, (list, tuple)):
            product_ids = [product_ids]
        if not isinstance(quantities, (list, tuple)):
            quantities = [quantities]
        raw = [
            {'product': product_id, 'quantity': quantity}
            for product_id, quantity in zip(product_ids, quantities)
        ]
    if not isinstance(raw, list):
        raise ValueError('items must be a list')
    return raw


def order_items(data):
    items = []
    for row in _raw_order_items(data):
        if not isinstance(row, dict):
            raise ValueError('item must be an object')
        product_id = row.get('product', row.get('product_id'))
        quantity = as_int(row.get('quantity', 1), 0)
        if quantity <= 0:
            continue
        product = Product.objects.filter(pk=as_int(product_id, 0)).first()
        if product is None:
            raise ValueError(f'product not found: {product_id}')
        items.append((product, quantity))
    if not items:
        raise ValueError('items is required')
    return items


def order_create_fields(data):
    order_type = str(data.get('order_type') or 'dine_in').strip()
    if order_type not in ORDER_TYPE_KEYS:
        raise ValueError('order_type is invalid')
    table = None
    table_value = data.get('table', data.get('table_id'))
    if table_value not in (None, '', 'null'):
        table = Table.objects.filter(pk=as_int(table_value, 0)).first()
        if table is None:
            raise ValueError('table not found')
    return {
        'table': table,
        'order_type': order_type,
        'address': data.get('address') or '',
        'items': order_items(data),
    }


def order_update_fields(data, partial=False):
    fields = {}
    if 'status' in data or not partial:
        fields['status'] = str(data.get('status') or 'Yangi').strip()
    if 'address' in data or not partial:
        fields['address'] = data.get('address') or ''
    if 'order_type' in data or not partial:
        order_type = str(data.get('order_type') or 'dine_in').strip()
        if order_type not in ORDER_TYPE_KEYS:
            raise ValueError('order_type is invalid')
        fields['order_type'] = order_type
    if 'table' in data or 'table_id' in data or not partial:
        table_value = data.get('table', data.get('table_id'))
        table = None
        if table_value not in (None, '', 'null'):
            table = Table.objects.filter(pk=as_int(table_value, 0)).first()
            if table is None:
                raise ValueError('table not found')
        fields['table'] = table
    if 'total_price' in data:
        fields['total_price'] = _decimal(data.get('total_price'), 'total_price')
    return fields


def ticket_create_fields(data):
    table_key = str(data.get('table', data.get('table_key', '')) or '').strip()
    if not table_key:
        raise ValueError('table is required')
    items = data.get('items') or {}
    if not isinstance(items, dict):
        raise ValueError('items must be an object')

    app_state = AppState.get_state()
    last_ticket = Ticket.objects.order_by('-id').first()
    next_id = max(app_state.seq or 1, (last_ticket.id if last_ticket else 0) + 1)
    ticket_id = as_int(data.get('id'), 0) or next_id
    if ticket_id <= 0:
        raise ValueError('id is invalid')

    now = int(timezone.now().timestamp() * 1000)
    done = as_bool(data.get('done', False))
    done_at = as_int(data.get('doneAt', data.get('done_at')), 0)
    if done and not done_at:
        done_at = now

    return {
        'table_key': table_key,
        'items': items,
        'time': as_int(data.get('time'), 0) or now,
        'done': done,
        'acc': as_bool(data.get('acc', False)),
        'seen': as_bool(data.get('seen', False)),
        'done_at': done_at or None,
    }, ticket_id


def ticket_fields(data, partial=False):
    fields = {}
    if 'table' in data or 'table_key' in data or not partial:
        table_key = str(data.get('table', data.get('table_key', '')) or '').strip()
        if not table_key:
            raise ValueError('table is required')
        fields['table_key'] = table_key
    if 'items' in data or not partial:
        items = data.get('items') or {}
        if not isinstance(items, dict):
            raise ValueError('items must be an object')
        fields['items'] = items
    if 'time' in data or not partial:
        fields['time'] = as_int(data.get('time'), 0) or int(timezone.now().timestamp() * 1000)
    if 'done' in data or not partial:
        fields['done'] = as_bool(data.get('done', False))
    if 'acc' in data or not partial:
        fields['acc'] = as_bool(data.get('acc', False))
    if 'seen' in data or not partial:
        fields['seen'] = as_bool(data.get('seen', False))
    if 'doneAt' in data or 'done_at' in data or not partial:
        done_at = as_int(data.get('doneAt', data.get('done_at')), 0)
        if done_at:
            fields['done_at'] = done_at
        elif fields.get('done'):
            fields['done_at'] = int(timezone.now().timestamp() * 1000)
        else:
            fields['done_at'] = None
    if fields.get('done') and not fields.get('done_at'):
        fields['done_at'] = int(timezone.now().timestamp() * 1000)
    if fields.get('done') is False and 'done_at' not in fields:
        fields['done_at'] = None
    return fields


def sale_create_fields(data):
    table_key = str(data.get('table', data.get('table_key', '')) or '').strip()
    if not table_key:
        raise ValueError('table is required')
    items = data.get('items') or {}
    if not isinstance(items, dict):
        raise ValueError('items must be an object')
    prices = data.get('prices') or {}
    if not isinstance(prices, dict):
        raise ValueError('prices must be an object')

    app_state = AppState.get_state()
    price_map = {**DEFAULT_PRICES, **(app_state.prices or {})}
    for key, value in prices.items():
        price_map[key] = _plain_number(value, 'price')
    price_map = {key: _plain_number(value, 'price') for key, value in price_map.items()}

    if data.get('sub') is not None:
        sub = _decimal(data.get('sub'), 'sub').quantize(Decimal('0.01'))
    else:
        sub = sum(
            (
                _decimal(quantity, 'quantity') * _decimal(price_map.get(key, 0), 'price')
                for key, quantity in items.items()
                if key != '_fish' and isinstance(quantity, (int, float))
            ),
            Decimal('0'),
        ).quantize(Decimal('0.01'))

    pct = as_int(data.get('pct'), 0)
    if pct < 0 or pct > 100:
        raise ValueError('pct must be between 0 and 100')

    if data.get('fee') is not None:
        fee = _decimal(data.get('fee'), 'fee').quantize(Decimal('0.01'))
    else:
        fee = Decimal(round(float(sub) * pct / 100)).quantize(Decimal('0.01'))

    if data.get('total') is not None:
        total = _decimal(data.get('total'), 'total').quantize(Decimal('0.01'))
    else:
        total = (sub + fee).quantize(Decimal('0.01'))

    last_sale = Sale.objects.order_by('-id').first()
    sale_id = as_int(data.get('id'), 0) or ((last_sale.id if last_sale else 0) + 1)
    if sale_id <= 0:
        raise ValueError('id is invalid')

    fields = {
        'time': as_int(data.get('time'), 0) or int(timezone.now().timestamp() * 1000),
        'table_key': table_key,
        'items': items,
        'sub': sub,
        'pct': pct,
        'fee': fee,
        'total': total,
        'address': data.get('address') or '',
        'prices': price_map,
        'linked_table': str(data.get('linked_table', data.get('linkedTable')) or '').strip() or None,
    }
    clear_table = as_bool(data.get('clear_table', data.get('close_table', True)))
    return fields, sale_id, clear_table


def table_state_fields(data, partial=False):
    fields = {}
    if 'table_key' in data or not partial:
        table_key = str(data.get('table_key', data.get('table', '')) or '').strip()
        if not table_key:
            raise ValueError('table_key is required')
        fields['table_key'] = table_key
    if 'items' in data or not partial:
        items = data.get('items') or {}
        if not isinstance(items, dict):
            raise ValueError('items must be an object')
        fields['items'] = items
    if 'address' in data or not partial:
        fields['address'] = data.get('address') or ''
    if 'saboy' in data or not partial:
        fields['saboy'] = as_bool(data.get('saboy', False))
    if 'linked_table' in data or 'linkedTable' in data:
        fields['linked_table'] = str(data.get('linked_table', data.get('linkedTable')) or '').strip() or None
    return fields


def settings_fields(data, instance=None, partial=False):
    fields = {}
    if 'prices' in data or not partial:
        raw = data.get('prices')
        if raw is None:
            raw = {}
        if not isinstance(raw, dict):
            raise ValueError('prices must be an object')
        if partial and instance is not None:
            prices = {**DEFAULT_PRICES, **(instance.prices or {})}
        else:
            prices = dict(DEFAULT_PRICES)
        for key, value in raw.items():
            prices[key] = _plain_number(value, 'price')
        fields['prices'] = prices
    if 'service' in data or not partial:
        service = as_int(data.get('service'), 10)
        if service < 0 or service > 100:
            raise ValueError('service must be between 0 and 100')
        fields['service'] = service
    if 'seq' in data or not partial:
        seq = as_int(data.get('seq'), 1)
        if seq < 1:
            raise ValueError('seq must be positive')
        fields['seq'] = seq
    if 'seqS' in data or 'seq_s' in data or not partial:
        seq_s = as_int(data.get('seqS', data.get('seq_s')), 0)
        if seq_s < 0:
            raise ValueError('seqS must be zero or positive')
        fields['seq_s'] = seq_s
    if 'fishList' in data or 'fish_list' in data:
        raw = data.get('fishList', data.get('fish_list'))
        if raw is None:
            raw = []
        if not isinstance(raw, list):
            raise ValueError('fishList must be a list')
        fields['fish_list'] = raw
    if 'stock' in data:
        raw = data.get('stock')
        if raw is None:
            raw = {}
        if not isinstance(raw, dict):
            raise ValueError('stock must be an object')
        stock = {}
        for key, value in raw.items():
            number = _plain_number(value, 'stock')
            if float(number) < 0:
                raise ValueError('stock must be zero or positive')
            stock[key] = number
        fields['stock'] = stock
    return fields
