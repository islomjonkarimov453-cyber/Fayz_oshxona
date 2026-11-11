import json
import queue
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from .models import AppState, Sale, TableState, Ticket

DEFAULT_PRICES = {
    'sazan': 80000,
    'oq': 90000,
    'buxarski': 100000,
    'ilonbosh': 110000,
    'amur': 95000,
    'non': 3000,
    'sous': 5000,
    'fanta': 12000,
    'cola': 12000,
    'tabaka': 45000,
}

FISH_KEYS = ('sazan', 'oq', 'buxarski', 'ilonbosh', 'amur')
OTHER_KEYS = ('non', 'sous', 'fanta', 'cola', 'tabaka')
STOCK_KEYS = ('tabaka',)
SALE_RETENTION_DAYS = 10

PRODUCT_LABELS = {
    'sazan': 'Sazan',
    'oq': 'Oq baliq',
    'buxarski': 'Buxarski',
    'ilonbosh': 'Ilonbosh',
    'amur': 'Amur',
    'non': 'Non',
    'sous': 'Sous',
    'fanta': 'Fanta',
    'cola': 'Cola',
    'tabaka': 'Tabaka',
}

EVENT_SUBSCRIBERS = []


class EventSubscriber:
    def __init__(self):
        self.messages = queue.Queue()

    def write(self, data):
        self.messages.put(data)

    def flush(self):
        pass

    def get(self, timeout=1):
        try:
            return self.messages.get(timeout=timeout)
        except queue.Empty:
            return None


def as_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def as_bool(value):
    if isinstance(value, str):
        return value.lower() in ('1', 'true', 'yes', 'on')
    return bool(value)


def get_rev():
    return AppState.get_state()._rev


def sale_retention_cutoff_ms():
    return int((timezone.now() - timedelta(days=SALE_RETENTION_DAYS)).timestamp() * 1000)


def prune_old_sales():
    deleted, _ = Sale.objects.filter(time__lt=sale_retention_cutoff_ms()).delete()
    return deleted


def today_local_iso():
    return timezone.localtime().date().isoformat()


def close_current_day():
    app_state = AppState.get_state()
    closed = list(app_state.closed_dates or [])
    today = today_local_iso()
    if today not in closed:
        closed.append(today)
    min_date = (timezone.localtime().date() - timedelta(days=SALE_RETENTION_DAYS - 1)).isoformat()
    closed = sorted({d for d in closed if isinstance(d, str) and d >= min_date})[-SALE_RETENTION_DAYS:]
    app_state.closed_dates = closed
    app_state.save(update_fields=['closed_dates'])
    prune_old_sales()
    return closed


def load_state_from_db():
    app_state = AppState.get_state()

    prices = {**DEFAULT_PRICES, **(app_state.prices or {})}
    if prices != (app_state.prices or {}):
        app_state.prices = prices
        app_state.save(update_fields=['prices'])

    if prune_old_sales():
        app_state._rev = (app_state._rev or 0) + 1
        app_state.save(update_fields=['_rev'])

    tables = {}
    for table_state in TableState.objects.all():
        tables[table_state.table_key] = table_state.to_dict()

    tickets = [ticket.to_dict() for ticket in Ticket.objects.order_by('id')]
    sales = [sale.to_dict() for sale in Sale.objects.order_by('id')]

    return {
        'prices': app_state.prices,
        'tables': tables,
        'tickets': tickets,
        'sales': sales,
        'seq': app_state.seq,
        'seqS': app_state.seq_s,
        'service': app_state.service,
        'fishList': app_state.fish_list or [],
        'stock': app_state.stock or {},
        'closedDates': app_state.closed_dates or [],
        'retentionDays': SALE_RETENTION_DAYS,
        '_rev': app_state._rev,
    }


def save_state_to_db(state, app_state, rev):
    app_state.prices = state.get('prices') or {}
    app_state.service = as_int(state.get('service'), 10)
    app_state.seq = as_int(state.get('seq'), 1)
    app_state.seq_s = as_int(state.get('seqS'), 0)
    app_state.fish_list = state.get('fishList') or state.get('fish_list') or []
    app_state.stock = state.get('stock') or {}
    app_state._rev = rev
    app_state.save(update_fields=['prices', 'service', 'seq', 'seq_s', 'fish_list', 'stock', '_rev'])

    tables_data = state.get('tables') or {}
    existing_tables = {item.table_key: item for item in TableState.objects.select_for_update()}
    keep_tables = set()
    for key, data in tables_data.items():
        key = str(key)
        data = data or {}
        keep_tables.add(key)
        table_state = existing_tables.get(key) or TableState(table_key=key)
        table_state.items = data.get('items') or {}
        table_state.address = data.get('address')
        table_state.saboy = as_bool(data.get('saboy', False))
        table_state.linked_table = str(data.get('linked_table', data.get('linkedTable')) or '').strip() or None
        table_state.save()
    TableState.objects.exclude(table_key__in=keep_tables).delete()

    tickets_data = state.get('tickets') or []
    existing_tickets = {item.id: item for item in Ticket.objects.select_for_update()}
    keep_tickets = []
    for data in tickets_data:
        ticket_id = as_int(data.get('id'), 0)
        if ticket_id <= 0:
            continue
        keep_tickets.append(ticket_id)
        ticket = existing_tickets.get(ticket_id) or Ticket(id=ticket_id)
        ticket.table_key = str(data.get('table', ''))
        ticket.items = data.get('items') or {}
        ticket.time = as_int(data.get('time'), 0)
        ticket.done = as_bool(data.get('done', False))
        ticket.acc = as_bool(data.get('acc', False))
        ticket.seen = as_bool(data.get('seen', False))
        ticket.done_at = as_int(data.get('doneAt'), 0) or None
        ticket.save()
    Ticket.objects.exclude(id__in=keep_tickets).delete()

    sales_data = state.get('sales') or []
    existing_sales = {item.id: item for item in Sale.objects.select_for_update()}
    keep_sales = []
    for data in sales_data:
        sale_id = as_int(data.get('id'), 0)
        if sale_id <= 0:
            continue
        keep_sales.append(sale_id)
        sale = existing_sales.get(sale_id) or Sale(id=sale_id)
        sale.time = as_int(data.get('time'), 0)
        sale.table_key = str(data.get('table', ''))
        sale.items = data.get('items') or {}
        sale.sub = data.get('sub') or 0
        sale.pct = as_int(data.get('pct'), 0)
        sale.fee = data.get('fee') or 0
        sale.total = data.get('total') or 0
        sale.address = data.get('address')
        sale.prices = data.get('prices') or {}
        sale.linked_table = str(data.get('linked_table', data.get('linkedTable')) or '').strip() or None
        sale.save()
    Sale.objects.exclude(id__in=keep_sales).delete()


def consume_fish_list(items):
    """Ticket items ichidagi _fish tafsilotlariga ko'ra AppState.fish_list'dan mos elementlarni o'chiradi."""
    details = (items or {}).get('_fish')
    if not isinstance(details, list) or not details:
        return False
    app_state = AppState.get_state()
    fish_list = list(app_state.fish_list or [])
    changed = False
    for detail in details:
        if not isinstance(detail, dict):
            continue
        key = detail.get('key')
        try:
            kg = float(detail.get('kg') or 0)
        except (TypeError, ValueError):
            continue
        for index, entry in enumerate(fish_list):
            entry = entry or {}
            try:
                entry_kg = float(entry.get('kg') or 0)
            except (TypeError, ValueError):
                continue
            if entry.get('key') == key and abs(entry_kg - kg) < 0.001:
                fish_list.pop(index)
                changed = True
                break
    if changed:
        app_state.fish_list = fish_list
        app_state.save(update_fields=['fish_list'])
        bump_revision()
    return changed


def consume_stock(items):
    """Sotuv items ichidagi qoldiq bilan kuzatiladigan mahsulotlar (tabaka) sonini kamaytiradi."""
    if not isinstance(items, dict):
        return False
    sold = {}
    for key in STOCK_KEYS:
        try:
            qty = float(items.get(key) or 0)
        except (TypeError, ValueError):
            qty = 0
        if qty > 0:
            sold[key] = qty
    if not sold:
        return False
    app_state = AppState.get_state()
    stock = dict(app_state.stock or {})
    changed = False
    for key, qty in sold.items():
        try:
            current = float(stock.get(key) or 0)
        except (TypeError, ValueError):
            current = 0
        remaining = max(0.0, current - qty)
        if remaining != current:
            stock[key] = int(remaining) if remaining == int(remaining) else remaining
            changed = True
    if changed:
        app_state.stock = stock
        app_state.save(update_fields=['stock'])
        bump_revision()
    return changed


def bump_revision():
    with transaction.atomic():
        app_state, _ = AppState.objects.select_for_update().get_or_create(pk=1)
        app_state._rev = (app_state._rev or 0) + 1
        if not app_state.prices:
            app_state.prices = dict(DEFAULT_PRICES)
        app_state.save()
    notify_subscribers()
    return app_state._rev


def notify_subscribers():
    state = load_state_from_db()
    payload = json.dumps({'rev': state['_rev'], 'state': state})
    for subscriber in EVENT_SUBSCRIBERS[:]:
        try:
            subscriber.write(f'data: {payload}\n\n')
            subscriber.flush()
        except Exception:
            if subscriber in EVENT_SUBSCRIBERS:
                EVENT_SUBSCRIBERS.remove(subscriber)
