import json
from datetime import timedelta
from decimal import Decimal
from functools import wraps

from django.db import IntegrityError, transaction
from django.http import JsonResponse, StreamingHttpResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt

from . import serializers
from .models import AppState, Category, Order, OrderItem, Product, Sale, Table, TableState, Ticket
from .state import (
    DEFAULT_PRICES,
    EVENT_SUBSCRIBERS,
    FISH_KEYS,
    OTHER_KEYS,
    PRODUCT_LABELS,
    EventSubscriber,
    as_int,
    bump_revision,
    load_state_from_db,
    notify_subscribers,
    save_state_to_db,
)
from .tasks import process_order_notification


def _json(data, status=200):
    return JsonResponse(data, status=status, safe=False, json_dumps_params={'ensure_ascii': False})


def _payload(request):
    content_type = request.content_type or ''
    if 'application/json' in content_type:
        raw = request.body.decode('utf-8').strip()
        if not raw:
            return {}
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError('JSON object expected')
        return data
    data = request.POST.dict()
    for key in ('product_ids', 'quantities'):
        if key in request.POST:
            data[key] = request.POST.getlist(key)
    if 'items' in request.POST:
        try:
            data['items'] = json.loads(request.POST['items'])
        except (TypeError, ValueError):
            pass
    return data


def api_view(methods):
    def decorator(func):
        @csrf_exempt
        @wraps(func)
        def wrapper(request, *args, **kwargs):
            if request.method not in methods:
                response = _json({'error': 'Method not allowed'}, 405)
                response['Allow'] = ', '.join(methods)
                return response
            try:
                return func(request, *args, **kwargs)
            except ValueError as exc:
                return _json({'error': str(exc)}, 400)
            except IntegrityError as exc:
                return _json({'error': str(exc)}, 400)
        return wrapper
    return decorator


def _get(model, pk):
    return model.objects.filter(pk=pk).first()


def _not_found():
    return _json({'error': 'Not found'}, 404)


def _list_response(queryset, serializer):
    items = list(queryset)
    return _json({'count': len(items), 'results': [serializer(item) for item in items]})


@api_view(['GET', 'POST'])
def category_list(request):
    if request.method == 'GET':
        return _list_response(Category.objects.order_by('id'), serializers.category_dict)
    data = _payload(request)
    category = Category.objects.create(**serializers.category_fields(data))
    bump_revision()
    return _json({'category': serializers.category_dict(category)}, 201)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def category_detail(request, pk):
    category = _get(Category, pk)
    if category is None:
        return _not_found()
    if request.method == 'GET':
        return _json({'category': serializers.category_dict(category)})
    if request.method == 'DELETE':
        category.delete()
        bump_revision()
        return _json({'deleted': True, 'id': pk})
    data = _payload(request)
    for key, value in serializers.category_fields(data, partial=request.method == 'PATCH').items():
        setattr(category, key, value)
    category.save()
    bump_revision()
    return _json({'category': serializers.category_dict(category)})


@api_view(['GET', 'POST'])
def product_list(request):
    if request.method == 'GET':
        queryset = Product.objects.select_related('category').order_by('id')
        category_id = request.GET.get('category')
        if category_id:
            queryset = queryset.filter(category_id=as_int(category_id, 0))
        search = request.GET.get('search')
        if search:
            queryset = queryset.filter(name__icontains=search)
        return _list_response(queryset, lambda item: serializers.product_dict(item, request))
    data = _payload(request)
    fields = serializers.product_fields(data)
    if 'image' in request.FILES:
        fields['image'] = request.FILES['image']
    product = Product.objects.create(**fields)
    bump_revision()
    return _json({'product': serializers.product_dict(product, request)}, 201)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def product_detail(request, pk):
    product = _get(Product, pk)
    if product is None:
        return _not_found()
    if request.method == 'GET':
        return _json({'product': serializers.product_dict(product, request)})
    if request.method == 'DELETE':
        product.delete()
        bump_revision()
        return _json({'deleted': True, 'id': pk})
    data = _payload(request)
    fields = serializers.product_fields(data, partial=request.method == 'PATCH')
    if 'image' in request.FILES:
        fields['image'] = request.FILES['image']
    for key, value in fields.items():
        setattr(product, key, value)
    product.save()
    bump_revision()
    return _json({'product': serializers.product_dict(product, request)})


@api_view(['GET', 'POST'])
def table_list(request):
    if request.method == 'GET':
        return _list_response(Table.objects.order_by('number'), serializers.table_dict)
    data = _payload(request)
    table = Table.objects.create(**serializers.table_fields(data))
    bump_revision()
    return _json({'table': serializers.table_dict(table)}, 201)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def table_detail(request, pk):
    table = _get(Table, pk)
    if table is None:
        return _not_found()
    if request.method == 'GET':
        return _json({'table': serializers.table_dict(table)})
    if request.method == 'DELETE':
        table.delete()
        bump_revision()
        return _json({'deleted': True, 'id': pk})
    data = _payload(request)
    for key, value in serializers.table_fields(data, partial=request.method == 'PATCH').items():
        setattr(table, key, value)
    table.save()
    bump_revision()
    return _json({'table': serializers.table_dict(table)})


@api_view(['POST'])
def table_close(request, pk):
    table = _get(Table, pk)
    if table is None:
        return _not_found()
    table.is_busy = False
    table.save(update_fields=['is_busy'])
    bump_revision()
    return _json({'table': serializers.table_dict(table)})


@api_view(['POST'])
def table_open(request, pk):
    table = _get(Table, pk)
    if table is None:
        return _not_found()
    table.is_busy = True
    table.save(update_fields=['is_busy'])
    bump_revision()
    return _json({'table': serializers.table_dict(table)})


def _recalculate_order(order):
    total = sum(
        (item.product.price * item.quantity for item in order.items.select_related('product')),
        Decimal('0'),
    )
    order.total_price = total
    order.save(update_fields=['total_price'])


def _create_order(request):
    data = _payload(request)
    fields = serializers.order_create_fields(data)
    items = fields.pop('items')
    with transaction.atomic():
        table = fields.get('table')
        if table is not None and fields.get('order_type') == 'dine_in':
            table.is_busy = True
            table.save(update_fields=['is_busy'])
        order = Order.objects.create(**fields)
        total = Decimal('0')
        for product, quantity in items:
            OrderItem.objects.create(order=order, product=product, quantity=quantity)
            total += product.price * quantity
        order.total_price = total
        order.save(update_fields=['total_price'])
    bump_revision()
    return order


@api_view(['GET', 'POST'])
def order_list(request):
    if request.method == 'GET':
        queryset = Order.objects.select_related('table').prefetch_related('items__product').order_by('-created_at')
        status = request.GET.get('status')
        if status:
            queryset = queryset.filter(status=status)
        order_type = request.GET.get('order_type')
        if order_type:
            queryset = queryset.filter(order_type=order_type)
        table_id = request.GET.get('table')
        if table_id:
            queryset = queryset.filter(table_id=as_int(table_id, 0))
        return _list_response(queryset, serializers.order_dict)
    order = _create_order(request)
    return _json({'order': serializers.order_dict(order)}, 201)


@api_view(['POST'])
def order_create_legacy(request):
    order = _create_order(request)
    return _json({'success': True, 'order_id': order.id, 'order': serializers.order_dict(order)}, 201)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def order_detail(request, pk):
    order = _get(Order, pk)
    if order is None:
        return _not_found()
    if request.method == 'GET':
        return _json({'order': serializers.order_dict(order)})
    if request.method == 'DELETE':
        order.delete()
        bump_revision()
        return _json({'deleted': True, 'id': pk})
    data = _payload(request)
    for key, value in serializers.order_update_fields(data, partial=request.method == 'PATCH').items():
        setattr(order, key, value)
    order.save()
    bump_revision()
    return _json({'order': serializers.order_dict(order)})


@api_view(['POST'])
def order_complete(request, pk):
    order = _get(Order, pk)
    if order is None:
        return _not_found()
    data = _payload(request)
    order.status = str(data.get('status') or 'Tayyor').strip()
    order.save(update_fields=['status'])
    bump_revision()
    return _json({'order': serializers.order_dict(order)})


@api_view(['POST'])
def order_item_add(request, pk):
    order = _get(Order, pk)
    if order is None:
        return _not_found()
    data = _payload(request)
    items = serializers.order_items(data)
    with transaction.atomic():
        for product, quantity in items:
            OrderItem.objects.create(order=order, product=product, quantity=quantity)
        _recalculate_order(order)
    bump_revision()
    return _json({'order': serializers.order_dict(order)}, 201)


@api_view(['DELETE'])
def order_item_delete(request, pk, item_id):
    order = _get(Order, pk)
    if order is None:
        return _not_found()
    item = OrderItem.objects.filter(pk=item_id, order_id=order.id).first()
    if item is None:
        return _not_found()
    item.delete()
    _recalculate_order(order)
    bump_revision()
    return _json({'order': serializers.order_dict(order)})


@api_view(['GET', 'POST'])
def ticket_list(request):
    if request.method == 'GET':
        queryset = Ticket.objects.order_by('id')
        for key in ('done', 'acc', 'seen'):
            value = request.GET.get(key)
            if value is not None:
                queryset = queryset.filter(**{key: value.lower() in ('1', 'true', 'yes', 'on')})
        table_key = request.GET.get('table')
        if table_key:
            queryset = queryset.filter(table_key=table_key)
        return _list_response(queryset, serializers.ticket_dict)
    data = _payload(request)
    fields, ticket_id = serializers.ticket_create_fields(data)
    with transaction.atomic():
        ticket = Ticket.objects.create(id=ticket_id, **fields)
        app_state, _ = AppState.objects.select_for_update().get_or_create(pk=1)
        if ticket_id >= (app_state.seq or 1):
            app_state.seq = ticket_id + 1
            app_state.save(update_fields=['seq'])
    bump_revision()
    try:
        process_order_notification.delay(ticket.id)
    except Exception:
        pass
    return _json({'ticket': serializers.ticket_dict(ticket)}, 201)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def ticket_detail(request, pk):
    ticket = _get(Ticket, pk)
    if ticket is None:
        return _not_found()
    if request.method == 'GET':
        return _json({'ticket': serializers.ticket_dict(ticket)})
    if request.method == 'DELETE':
        ticket.delete()
        bump_revision()
        return _json({'deleted': True, 'id': pk})
    data = _payload(request)
    for key, value in serializers.ticket_fields(data, partial=request.method == 'PATCH').items():
        setattr(ticket, key, value)
    ticket.save()
    bump_revision()
    return _json({'ticket': serializers.ticket_dict(ticket)})


def _ticket_action(pk, **changes):
    ticket = _get(Ticket, pk)
    if ticket is None:
        return _not_found()
    for key, value in changes.items():
        setattr(ticket, key, value)
    ticket.save()
    bump_revision()
    return _json({'ticket': serializers.ticket_dict(ticket)})


@api_view(['POST'])
def ticket_accept(request, pk):
    return _ticket_action(pk, acc=True)


@api_view(['POST'])
def ticket_ready(request, pk):
    now = int(timezone.now().timestamp() * 1000)
    return _ticket_action(pk, done=True, done_at=now, seen=False)


@api_view(['POST'])
def ticket_seen(request, pk):
    return _ticket_action(pk, seen=True)


def _period_start(period):
    now = timezone.localtime()
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    if period == 'today':
        return int(start.timestamp() * 1000)
    if period == 'week':
        return int((start - timedelta(days=6)).timestamp() * 1000)
    if period == 'all':
        return 0
    raise ValueError('period must be today, week or all')


def _sales_for_period(period):
    return Sale.objects.filter(time__gte=_period_start(period)).order_by('id')


def _sale_quantity(sale, key):
    return float((sale.items or {}).get(key, 0) or 0)


def _sale_price(sale, key):
    return float((sale.prices or {}).get(key, 0) or 0)


def _current_price(key):
    app_state = AppState.get_state()
    prices = {**DEFAULT_PRICES, **(app_state.prices or {})}
    try:
        return float(prices.get(key, 0) or 0)
    except (TypeError, ValueError):
        return 0.0


@api_view(['GET', 'POST', 'DELETE'])
def sale_list(request):
    if request.method == 'GET':
        period = request.GET.get('period', 'all')
        queryset = _sales_for_period(period)
        start = request.GET.get('from')
        if start:
            queryset = queryset.filter(time__gte=as_int(start, 0))
        end = request.GET.get('to')
        if end:
            queryset = queryset.filter(time__lte=as_int(end, 0))
        return _list_response(queryset, serializers.sale_dict)

    if request.method == 'DELETE':
        Sale.objects.all().delete()
        bump_revision()
        return _json({'deleted': True})

    data = _payload(request)
    fields, sale_id, clear_table = serializers.sale_create_fields(data)
    table_key = fields['table_key']
    with transaction.atomic():
        sale = Sale.objects.create(id=sale_id, **fields)
        if clear_table:
            TableState.objects.filter(table_key=table_key).delete()
            if table_key.isdigit():
                Table.objects.filter(number=int(table_key)).update(is_busy=False)
    bump_revision()
    return _json({'sale': serializers.sale_dict(sale)}, 201)


@api_view(['GET', 'DELETE'])
def sale_detail(request, pk):
    sale = _get(Sale, pk)
    if sale is None:
        return _not_found()
    if request.method == 'DELETE':
        sale.delete()
        bump_revision()
        return _json({'deleted': True, 'id': pk})
    return _json({'sale': serializers.sale_dict(sale)})


@api_view(['GET', 'POST'])
def table_state_list(request):
    if request.method == 'GET':
        return _list_response(TableState.objects.order_by('table_key'), serializers.table_state_dict)
    data = _payload(request)
    fields = serializers.table_state_fields(data)
    table_state, _ = TableState.objects.update_or_create(
        table_key=fields.pop('table_key'),
        defaults=fields,
    )
    bump_revision()
    return _json({'table_state': serializers.table_state_dict(table_state)}, 201)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def table_state_detail(request, table_key):
    if request.method == 'GET':
        table_state = TableState.objects.filter(table_key=table_key).first()
        if table_state is None:
            return _not_found()
        return _json({'table_state': serializers.table_state_dict(table_state)})
    if request.method == 'DELETE':
        deleted, _ = TableState.objects.filter(table_key=table_key).delete()
        if not deleted:
            return _not_found()
        bump_revision()
        return _json({'deleted': True, 'table_key': table_key})
    data = _payload(request)
    if 'table_key' not in data and 'table' not in data:
        data['table_key'] = table_key
    fields = serializers.table_state_fields(data, partial=request.method == 'PATCH')
    provided_key = fields.pop('table_key', table_key)
    if provided_key != table_key:
        raise ValueError('table_key does not match')
    table_state, _ = TableState.objects.update_or_create(table_key=table_key, defaults=fields)
    bump_revision()
    return _json({'table_state': serializers.table_state_dict(table_state)})


@api_view(['GET', 'PUT', 'PATCH'])
def settings(request):
    app_state = AppState.get_state()
    if request.method == 'GET':
        return _json({'settings': serializers.app_state_dict(app_state)})
    data = _payload(request)
    fields = serializers.settings_fields(data, app_state, partial=request.method == 'PATCH')
    for key, value in fields.items():
        setattr(app_state, key, value)
    app_state.save()
    bump_revision()
    app_state.refresh_from_db()
    return _json({'settings': serializers.app_state_dict(app_state)})


@api_view(['POST'])
def settings_reset(request):
    with transaction.atomic():
        Sale.objects.all().delete()
        Ticket.objects.all().delete()
        TableState.objects.all().delete()
        app_state, _ = AppState.objects.select_for_update().get_or_create(pk=1)
        app_state.seq = 1
        app_state.seq_s = 0
        app_state._rev = (app_state._rev or 0) + 1
        if not app_state.prices:
            app_state.prices = dict(DEFAULT_PRICES)
        app_state.save()
    notify_subscribers()
    return _json({'settings': serializers.app_state_dict(app_state)})


@api_view(['GET'])
def stats_summary(request):
    period = request.GET.get('period', 'today')
    sales = list(_sales_for_period(period))
    revenue = sum(float(sale.total or 0) for sale in sales)
    items_total = sum(float(sale.sub or 0) for sale in sales)
    service_fee = sum(float(sale.fee or 0) for sale in sales)
    fish_kg = sum(_sale_quantity(sale, key) for sale in sales for key in FISH_KEYS)
    busy_tables = sum(
        1
        for table_state in TableState.objects.all()
        if not str(table_state.table_key).startswith('S') and (table_state.items or {})
    )
    total_tables = Table.objects.count() or 7
    return _json({
        'period': period,
        'receipts': len(sales),
        'revenue': round(revenue, 2),
        'items_total': round(items_total, 2),
        'service_fee': round(service_fee, 2),
        'fish_kg': round(fish_kg, 2),
        'busy_tables': busy_tables,
        'total_tables': total_tables,
    })


@api_view(['GET'])
def stats_fish(request):
    period = request.GET.get('period', 'today')
    sales = list(_sales_for_period(period))
    total_kg = sum(_sale_quantity(sale, key) for sale in sales for key in FISH_KEYS)
    total_amount = sum(
        _sale_quantity(sale, key) * _sale_price(sale, key)
        for sale in sales
        for key in FISH_KEYS
    )
    results = []
    for key in FISH_KEYS:
        quantity = sum(_sale_quantity(sale, key) for sale in sales)
        amount = sum(_sale_quantity(sale, key) * _sale_price(sale, key) for sale in sales)
        results.append({
            'key': key,
            'name': PRODUCT_LABELS.get(key, key),
            'price': _current_price(key),
            'quantity': round(quantity, 2),
            'amount': round(amount, 2),
            'share': round((quantity / total_kg * 100) if total_kg else 0, 2),
        })
    return _json({
        'period': period,
        'results': results,
        'total_kg': round(total_kg, 2),
        'total_amount': round(total_amount, 2),
    })


@api_view(['GET'])
def stats_other(request):
    period = request.GET.get('period', 'today')
    sales = list(_sales_for_period(period))
    results = []
    total_amount = 0.0
    for key in OTHER_KEYS:
        quantity = sum(_sale_quantity(sale, key) for sale in sales)
        amount = sum(_sale_quantity(sale, key) * _sale_price(sale, key) for sale in sales)
        total_amount += amount
        results.append({
            'key': key,
            'name': PRODUCT_LABELS.get(key, key),
            'price': _current_price(key),
            'quantity': round(quantity, 2),
            'amount': round(amount, 2),
        })
    return _json({
        'period': period,
        'results': results,
        'total_amount': round(total_amount, 2),
    })


@api_view(['GET'])
def health(request):
    return _json({
        'status': 'ok',
        'rev': AppState.get_state()._rev,
        'time': int(timezone.now().timestamp() * 1000),
    })


@api_view(['GET'])
def legacy_cook_orders(request):
    queryset = Order.objects.filter(status='Yangi').select_related('table').prefetch_related('items__product')
    return _json({'orders': [serializers.order_dict(order) for order in queryset]})


@api_view(['GET'])
def legacy_admin_orders(request):
    orders = Order.objects.select_related('table').prefetch_related('items__product').order_by('-created_at')
    tables = Table.objects.order_by('number')
    return _json({
        'orders': [serializers.order_dict(order) for order in orders],
        'tables': [serializers.table_dict(table) for table in tables],
    })


@csrf_exempt
def api_state(request):
    if request.method == 'GET':
        state = load_state_from_db()
        return _json({'rev': state['_rev'], 'state': state})
    if request.method != 'POST':
        return _json({'error': 'Method not allowed'}, 405)
    try:
        data = json.loads(request.body.decode('utf-8') or '{}')
    except (TypeError, ValueError):
        return _json({'error': 'Invalid JSON'}, 400)

    client_rev = as_int(data.get('rev'), 0)
    state = data.get('state') or {}
    if not isinstance(state, dict):
        return _json({'error': 'Invalid state'}, 400)

    conflict = False
    new_rev = 0
    new_ticket_ids = []
    try:
        with transaction.atomic():
            app_state, _ = AppState.objects.select_for_update().get_or_create(pk=1)
            if client_rev != app_state._rev:
                conflict = True
            else:
                old_ticket_ids = set(Ticket.objects.values_list('id', flat=True))
                new_rev = app_state._rev + 1
                save_state_to_db(state, app_state, new_rev)
                new_ticket_ids = [
                    as_int(item.get('id'), 0)
                    for item in (state.get('tickets') or [])
                    if as_int(item.get('id'), 0) > 0 and as_int(item.get('id'), 0) not in old_ticket_ids
                ]
    except Exception as exc:
        return _json({'error': str(exc)}, 400)

    if conflict:
        current = load_state_from_db()
        return _json({'rev': current['_rev'], 'state': current}, 409)

    for ticket_id in new_ticket_ids:
        try:
            process_order_notification.delay(ticket_id)
        except Exception:
            pass

    notify_subscribers()
    state['_rev'] = new_rev
    return _json({'rev': new_rev, 'state': state})


def api_events(request):
    if request.method != 'GET':
        return _json({'error': 'Method not allowed'}, 405)

    subscriber = EventSubscriber()
    EVENT_SUBSCRIBERS.append(subscriber)

    def event_stream():
        try:
            state = load_state_from_db()
            payload = json.dumps({'rev': state['_rev'], 'state': state})
            yield f'data: {payload}\n\n'
            while True:
                message = subscriber.get(1)
                yield message if message else ': keepalive\n\n'
        except GeneratorExit:
            pass
        finally:
            if subscriber in EVENT_SUBSCRIBERS:
                EVENT_SUBSCRIBERS.remove(subscriber)

    response = StreamingHttpResponse(event_stream(), content_type='text/event-stream')
    response['Cache-Control'] = 'no-cache'
    response['Connection'] = 'keep-alive'
    response['X-Accel-Buffering'] = 'no'
    return response
