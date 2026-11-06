import json

from django.test import Client, TestCase

from .models import AppState, Sale, TableState, Ticket

PRICES = {
    'sazan': 80000,
    'oq': 90000,
    'buxarski': 100000,
    'ilonbosh': 110000,
    'non': 3000,
    'sous': 5000,
    'fanta': 12000,
    'cola': 12000,
}


def make_state(**overrides):
    state = {
        'prices': PRICES,
        'tables': {},
        'tickets': [],
        'sales': [],
        'seq': 1,
        'seqS': 0,
        'service': 10,
    }
    state.update(overrides)
    return state


class ApiStateTests(TestCase):
    def setUp(self):
        self.client = Client()

    def get_state(self):
        response = self.client.get('/api/state')
        self.assertEqual(response.status_code, 200)
        return response.json()

    def post_state(self, rev, state):
        return self.client.post(
            '/api/state',
            data=json.dumps({'rev': rev, 'state': state}),
            content_type='application/json',
        )

    def test_get_returns_default_state(self):
        data = self.get_state()
        self.assertEqual(data['rev'], 0)
        self.assertEqual(data['state']['prices'], PRICES)
        self.assertEqual(data['state']['tables'], {})

    def test_order_ticket_is_saved_for_cook(self):
        rev = self.get_state()['rev']
        state = make_state(
            tables={'1': {'items': {'sazan': 0.5}}},
            tickets=[{
                'id': 1,
                'table': '1',
                'time': 1000,
                'items': {'sazan': 0.5},
                'done': False,
                'seen': False,
            }],
            seq=2,
        )

        response = self.post_state(rev, state)
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()['rev'], rev + 1)

        ticket = Ticket.objects.get(id=1)
        self.assertEqual(ticket.table_key, '1')
        self.assertFalse(ticket.acc)
        self.assertFalse(ticket.done)
        self.assertEqual(ticket.items, {'sazan': 0.5})

    def test_saboy_table_and_address_are_saved(self):
        rev = self.get_state()['rev']
        state = make_state(
            tables={'S1': {'items': {'sazan': 1}, 'saboy': True, 'address': 'Chilonzor 5'}},
            tickets=[{
                'id': 1,
                'table': 'S1',
                'time': 1000,
                'items': {'sazan': 1},
                'done': False,
                'acc': False,
                'seen': False,
            }],
            seq=2,
            seqS=1,
        )

        response = self.post_state(rev, state)
        self.assertEqual(response.status_code, 200, response.content)

        table = TableState.objects.get(table_key='S1')
        self.assertTrue(table.saboy)
        self.assertEqual(table.address, 'Chilonzor 5')
        self.assertEqual(Ticket.objects.get(id=1).table_key, 'S1')

    def test_cook_status_update_is_saved(self):
        rev = self.get_state()['rev']
        state = make_state(
            tables={'1': {'items': {'sazan': 0.5}}},
            tickets=[{
                'id': 1,
                'table': '1',
                'time': 1000,
                'items': {'sazan': 0.5},
                'done': False,
                'acc': False,
                'seen': False,
            }],
            seq=2,
        )
        rev = self.post_state(rev, state).json()['rev']

        state['tickets'][0].update({'acc': True, 'done': True, 'doneAt': 2000})
        response = self.post_state(rev, state)
        self.assertEqual(response.status_code, 200, response.content)

        ticket = Ticket.objects.get(id=1)
        self.assertTrue(ticket.acc)
        self.assertTrue(ticket.done)
        self.assertEqual(ticket.done_at, 2000)

    def test_sale_is_saved_for_admin(self):
        rev = self.get_state()['rev']
        state = make_state(
            sales=[{
                'id': 1,
                'time': 3000,
                'table': 'S1',
                'items': {'sazan': 1},
                'sub': 80000,
                'pct': 0,
                'fee': 0,
                'total': 80000,
                'address': 'Chilonzor 5',
                'prices': PRICES,
            }],
        )

        response = self.post_state(rev, state)
        self.assertEqual(response.status_code, 200, response.content)

        sale = Sale.objects.get(id=1)
        self.assertEqual(sale.table_key, 'S1')
        self.assertEqual(float(sale.total), 80000)
        self.assertEqual(sale.address, 'Chilonzor 5')

    def test_stale_revision_returns_conflict(self):
        rev = self.get_state()['rev']
        state = make_state(tables={'1': {'items': {'sazan': 0.5}}})
        first = self.post_state(rev, state)
        self.assertEqual(first.status_code, 200, first.content)

        stale = self.post_state(rev, state)
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(stale.json()['rev'], first.json()['rev'])
        self.assertEqual(TableState.objects.count(), 1)

    def test_deleted_items_are_removed_from_db(self):
        rev = self.get_state()['rev']
        state = make_state(tables={'1': {'items': {'sazan': 0.5}}})
        rev = self.post_state(rev, state).json()['rev']

        response = self.post_state(rev, make_state())
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(TableState.objects.count(), 0)
        self.assertEqual(AppState.get_state()._rev, rev + 1)
