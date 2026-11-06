import json

from django.test import Client, TestCase

from .models import AppState, Category, Order, Product, Sale, Table, TableState, Ticket


class RestApiTests(TestCase):
    def setUp(self):
        self.client = Client()

    def post_json(self, url, data):
        return self.client.post(url, data=json.dumps(data), content_type='application/json')

    def patch_json(self, url, data):
        return self.client.patch(url, data=json.dumps(data), content_type='application/json')

    def test_category_product_table_crud(self):
        response = self.post_json('/api/categories/', {'name': 'Baliq'})
        self.assertEqual(response.status_code, 201)
        category = response.json()['category']

        response = self.post_json('/api/products/', {
            'category': category['id'],
            'name': 'Sazan',
            'price': 80000,
            'description': 'Yangi',
        })
        self.assertEqual(response.status_code, 201)
        product = response.json()['product']
        self.assertEqual(product['category'], category['id'])

        response = self.post_json('/api/tables/', {'number': 1})
        self.assertEqual(response.status_code, 201)
        table = response.json()['table']
        self.assertFalse(table['is_busy'])

        response = self.patch_json(f"/api/products/{product['id']}/", {'price': 90000})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Product.objects.get(pk=product['id']).price, 90000)

        response = self.client.delete(f"/api/products/{product['id']}/")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Product.objects.filter(pk=product['id']).exists())

    def test_order_flow(self):
        category = Category.objects.create(name='Baliq')
        product = Product.objects.create(category=category, name='Sazan', price=80000)
        table = Table.objects.create(number=1)

        response = self.post_json('/api/orders/', {
            'table': table.id,
            'order_type': 'dine_in',
            'items': [{'product': product.id, 'quantity': 2}],
        })
        self.assertEqual(response.status_code, 201)
        order = response.json()['order']
        self.assertEqual(order['total_price'], '160000.00')
        self.assertEqual(len(order['items']), 1)
        table.refresh_from_db()
        self.assertTrue(table.is_busy)

        response = self.post_json(f"/api/orders/{order['id']}/items/", {
            'items': [{'product': product.id, 'quantity': 1}],
        })
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()['order']['total_price'], '240000.00')

        item_id = response.json()['order']['items'][-1]['id']
        response = self.client.delete(f"/api/orders/{order['id']}/items/{item_id}/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['order']['total_price'], '160000.00')

        response = self.post_json(f"/api/orders/{order['id']}/complete/", {})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['order']['status'], 'Tayyor')

        response = self.post_json('/api/tables/999/close/', {})
        self.assertEqual(response.status_code, 404)
        response = self.post_json(f'/api/tables/{table.id}/close/', {})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()['table']['is_busy'])

    def test_ticket_flow(self):
        response = self.post_json('/api/tickets/', {
            'table': '1',
            'items': {'sazan': 0.5},
        })
        self.assertEqual(response.status_code, 201)
        ticket = response.json()['ticket']
        self.assertFalse(ticket['acc'])

        response = self.post_json(f"/api/tickets/{ticket['id']}/accept/", {})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['ticket']['acc'])

        response = self.post_json(f"/api/tickets/{ticket['id']}/ready/", {})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['ticket']['done'])
        self.assertIn('doneAt', response.json()['ticket'])

        response = self.post_json(f"/api/tickets/{ticket['id']}/seen/", {})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['ticket']['seen'])

        response = self.client.get('/api/tickets/?done=true')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['count'], 1)

    def test_sale_creation_clears_table_state(self):
        TableState.objects.create(table_key='1', items={'sazan': 1})

        response = self.post_json('/api/sales/', {
            'table': '1',
            'items': {'sazan': 1},
            'pct': 10,
            'prices': {'sazan': 80000},
        })
        self.assertEqual(response.status_code, 201)
        sale = response.json()['sale']
        self.assertEqual(sale['sub'], 80000.0)
        self.assertEqual(sale['fee'], 8000.0)
        self.assertEqual(sale['total'], 88000.0)
        self.assertFalse(TableState.objects.filter(table_key='1').exists())

        response = self.client.get('/api/stats/summary/?period=all')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['receipts'], 1)
        self.assertEqual(data['revenue'], 88000.0)

        response = self.client.get('/api/stats/fish/?period=all')
        self.assertEqual(response.status_code, 200)
        fish = response.json()
        self.assertEqual(fish['results'][0]['key'], 'sazan')
        self.assertEqual(fish['results'][0]['quantity'], 1.0)

    def test_settings_and_reset(self):
        response = self.client.get('/api/settings/')
        self.assertEqual(response.status_code, 200)

        response = self.patch_json('/api/settings/', {
            'service': 12,
            'prices': {'sazan': 85000},
        })
        self.assertEqual(response.status_code, 200)
        settings = response.json()['settings']
        self.assertEqual(settings['service'], 12)
        self.assertEqual(settings['prices']['sazan'], 85000)
        self.assertEqual(settings['prices']['non'], 3000)

        Sale.objects.create(
            id=1, time=1, table_key='1', items={'sazan': 1},
            sub=1, pct=0, fee=0, total=1, prices={},
        )
        Ticket.objects.create(id=1, table_key='1', items={}, time=1)
        TableState.objects.create(table_key='1', items={'sazan': 1})

        response = self.post_json('/api/settings/reset/', {})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['settings']['seq'], 1)
        self.assertEqual(Sale.objects.count(), 0)
        self.assertEqual(Ticket.objects.count(), 0)
        self.assertEqual(TableState.objects.count(), 0)

    def test_table_state_crud(self):
        response = self.post_json('/api/table-states/', {
            'table_key': 'S1',
            'items': {'sazan': 1},
            'address': 'Chilonzor',
            'saboy': True,
        })
        self.assertEqual(response.status_code, 201)

        response = self.client.get('/api/table-states/S1/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['table_state']['address'], 'Chilonzor')

        response = self.patch_json('/api/table-states/S1/', {'address': 'Yunusobod'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['table_state']['address'], 'Yunusobod')

        response = self.client.put(
            '/api/table-states/S1/',
            data=json.dumps({'items': {'oq': 2}, 'saboy': False}),
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['table_state']['items'], {'oq': 2})

        response = self.client.delete('/api/table-states/S1/')
        self.assertEqual(response.status_code, 200)
        self.assertFalse(TableState.objects.filter(table_key='S1').exists())

    def test_state_health_and_events_routes(self):
        response = self.client.get('/api/state')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['rev'], 0)

        response = self.client.post(
            '/api/state',
            data=json.dumps({'rev': 0, 'state': {'prices': {}, 'tables': {}, 'tickets': [], 'sales': []}}),
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(AppState.get_state()._rev, 1)

        response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['status'], 'ok')

        response = self.client.get('/api/legacy/cook-orders/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Order.objects.count(), 0)

        response = self.client.get('/api/legacy/admin-orders/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['orders'], [])
