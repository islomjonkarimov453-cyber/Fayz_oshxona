from django.test import TestCase
from rest_framework.test import APIClient

from .models import AppState, Category, Order, Product, Sale, Table, TableState, Ticket


class DrfApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_catalog_crud(self):
        response = self.client.post('/api/v1/categories/', {'name': 'Baliq'}, format='json')
        self.assertEqual(response.status_code, 201, response.content)
        category = response.json()

        response = self.client.post(
            '/api/v1/products/',
            {'category': category['id'], 'name': 'Sazan', 'price': '80000'},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        product = response.json()
        self.assertEqual(product['category'], category['id'])
        self.assertEqual(product['price'], '80000.00')

        response = self.client.patch(
            f"/api/v1/products/{product['id']}/", {'price': '90000'}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(Product.objects.get(pk=product['id']).price, 90000)

        response = self.client.get('/api/v1/products/?search=Saz')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)

        response = self.client.delete(f"/api/v1/products/{product['id']}/")
        self.assertEqual(response.status_code, 204)
        self.assertFalse(Product.objects.filter(pk=product['id']).exists())

    def test_table_actions(self):
        table = Table.objects.create(number=1)
        response = self.client.post(f'/api/v1/tables/{table.id}/open/')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['is_busy'])

        response = self.client.post(f'/api/v1/tables/{table.id}/close/')
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()['is_busy'])

    def test_order_flow(self):
        category = Category.objects.create(name='Baliq')
        product = Product.objects.create(category=category, name='Sazan', price=80000)
        table = Table.objects.create(number=1)

        response = self.client.post(
            '/api/v1/orders/',
            {
                'table': table.id,
                'order_type': 'dine_in',
                'items': [{'product': product.id, 'quantity': 2}],
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        order = response.json()
        self.assertEqual(order['total_price'], '160000.00')
        self.assertEqual(len(order['items']), 1)
        table.refresh_from_db()
        self.assertTrue(table.is_busy)

        response = self.client.post(
            f"/api/v1/orders/{order['id']}/items/",
            {'items': [{'product': product.id, 'quantity': 1}]},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.json()['total_price'], '240000.00')

        item_id = response.json()['items'][-1]['id']
        response = self.client.delete(f"/api/v1/orders/{order['id']}/items/{item_id}/")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()['total_price'], '160000.00')

        response = self.client.post(f"/api/v1/orders/{order['id']}/complete/", {}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['status'], 'Tayyor')

    def test_ticket_flow_and_seq(self):
        response = self.client.post(
            '/api/v1/tickets/', {'table': '1', 'items': {'sazan': 0.5}}, format='json'
        )
        self.assertEqual(response.status_code, 201, response.content)
        ticket = response.json()
        self.assertEqual(ticket['table'], '1')
        self.assertFalse(ticket['acc'])
        self.assertEqual(AppState.get_state().seq, ticket['id'] + 1)

        response = self.client.post(f"/api/v1/tickets/{ticket['id']}/accept/")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['acc'])

        response = self.client.post(f"/api/v1/tickets/{ticket['id']}/ready/")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['done'])
        self.assertIn('doneAt', response.json())

        response = self.client.post(f"/api/v1/tickets/{ticket['id']}/seen/")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()['seen'])

        response = self.client.get('/api/v1/tickets/?done=true')
        self.assertEqual(len(response.json()), 1)

    def test_sale_creation_clears_table_state(self):
        TableState.objects.create(table_key='1', items={'sazan': 1})

        response = self.client.post(
            '/api/v1/sales/',
            {
                'table': '1',
                'items': {'sazan': 1},
                'pct': 10,
                'prices': {'sazan': 80000},
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)
        sale = response.json()
        self.assertEqual(sale['sub'], '80000.00')
        self.assertEqual(sale['fee'], '8000.00')
        self.assertEqual(sale['total'], '88000.00')
        self.assertFalse(TableState.objects.filter(table_key='1').exists())

        response = self.client.get('/api/v1/stats/summary/?period=all')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['receipts'], 1)
        self.assertEqual(data['revenue'], 88000.0)

        response = self.client.get('/api/v1/stats/fish/?period=all')
        self.assertEqual(response.json()['results'][0]['key'], 'sazan')

    def test_table_state_crud(self):
        response = self.client.post(
            '/api/v1/table-states/',
            {'table_key': 'S1', 'items': {'sazan': 1}, 'address': 'Chilonzor', 'saboy': True},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.content)

        response = self.client.patch(
            '/api/v1/table-states/S1/', {'address': 'Yunusobod'}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()['address'], 'Yunusobod')

        response = self.client.patch(
            '/api/v1/table-states/S1/', {'items': {'oq': 2}}, format='json'
        )
        self.assertEqual(response.json()['items'], {'oq': 2})

        response = self.client.delete('/api/v1/table-states/S1/')
        self.assertEqual(response.status_code, 204)
        self.assertFalse(TableState.objects.filter(table_key='S1').exists())

    def test_settings_and_reset(self):
        response = self.client.get('/api/v1/settings/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('seqS', response.json())

        response = self.client.patch(
            '/api/v1/settings/', {'service': 12, 'prices': {'sazan': 85000}}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.content)
        settings = response.json()
        self.assertEqual(settings['service'], 12)
        self.assertEqual(settings['prices']['sazan'], 85000)
        self.assertEqual(settings['prices']['non'], 3000)

        Sale.objects.create(
            id=1, time=1, table_key='1', items={'sazan': 1},
            sub=1, pct=0, fee=0, total=1, prices={},
        )
        Ticket.objects.create(id=1, table_key='1', items={}, time=1)
        TableState.objects.create(table_key='1', items={'sazan': 1})

        response = self.client.post('/api/v1/settings/reset/', {}, format='json')
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()['seq'], 1)
        self.assertEqual(Sale.objects.count(), 0)
        self.assertEqual(Ticket.objects.count(), 0)
        self.assertEqual(TableState.objects.count(), 0)

    def test_state_snapshot_health_and_revision(self):
        response = self.client.get('/api/v1/state/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['rev'], 0)
        self.assertIn('tables', response.json()['state'])

        response = self.client.get('/api/v1/health/')
        self.assertEqual(response.json()['status'], 'ok')

        self.client.post('/api/v1/categories/', {'name': 'Baliq'}, format='json')
        self.assertEqual(AppState.get_state()._rev, 1)

    def test_validation_errors_return_400(self):
        response = self.client.post('/api/v1/categories/', {}, format='json')
        self.assertEqual(response.status_code, 400)

        response = self.client.post(
            '/api/v1/sales/', {'table': '1', 'items': {'sazan': 1}, 'pct': 150}, format='json'
        )
        self.assertEqual(response.status_code, 400)

        response = self.client.post(
            '/api/v1/orders/', {'items': [{'product': 999, 'quantity': 1}]}, format='json'
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Order.objects.count(), 0)
