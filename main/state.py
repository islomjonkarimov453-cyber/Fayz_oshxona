import json
import queue

from django.db import transaction

from .models import AppState, Sale, TableState, Ticket

DEFAULT_PRICES = {
    'sazan': 80000,
    'oq': 90000,
    'buxarski': 100000,
    'ilonbosh': 110000,
    'non': 3000,
    'sous': 5000,
    'fanta': 12000,
    'cola': 12000,
}

FISH_KEYS = ('sazan', 'oq', 'buxarski', 'ilonbosh')
OTHER_KEYS = ('non', 'sous', 'fanta', 'cola')

PRODUCT_LABELS = {
    'sazan': 'Sazan',
    'oq': 'Oq baliq',
    'buxarski': 'Buxarski',
    'ilonbosh': 'Ilonbosh',
    'non': 'Non',
    'sous': 'Sous',
    'fanta': 'Fanta',
    'cola': 'Cola',
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


def load_state_from_db():
    app_state = AppState.get_state()

    if not app_state.prices:
        app_state.prices = dict(DEFAULT_PRICES)
        app_state.save(update_fields=['prices'])

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
        '_rev': app_state._rev,
    }


def save_state_to_db(state, app_state, rev):
    app_state.prices = state.get('prices') or {}
    app_state.service = as_int(state.get('service'), 10)
    app_state.seq = as_int(state.get('seq'), 1)
    app_state.seq_s = as_int(state.get('seqS'), 0)
    app_state._rev = rev
    app_state.save()

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
        sale.save()
    Sale.objects.exclude(id__in=keep_sales).delete()


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
