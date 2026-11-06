import json

from django.core.cache import cache

try:
    from celery import shared_task
    HAS_CELERY = True
except ImportError:
    HAS_CELERY = False

    def shared_task(func):
        return func


@shared_task
def update_order_state(order_id, status):
    cache_key = f'order_{order_id}'
    cache.set(cache_key, json.dumps({'status': status}), timeout=3600)
    return f'Order {order_id} updated to {status}'


@shared_task
def process_order_notification(order_id):
    cache_key = f'notification_{order_id}'
    cache.set(cache_key, json.dumps({'order_id': order_id, 'notified': True}), timeout=3600)
    return f'Notification sent for order {order_id}'


@shared_task
def cleanup_old_orders():
    cache.clear()
    return 'Cleanup completed'
