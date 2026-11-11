from django.shortcuts import redirect
from django.urls import path

from . import api, views

app_name = 'main'

urlpatterns = [
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('', views.admin_view, name='main'),
    path('sw.js', views.service_worker, name='service_worker'),
    path('app/', views.flutter_app, name='flutter_app'),
    path('app/<path:path>', views.flutter_app, name='flutter_app_path'),
    path('waiter/', views.waiter_view, name='waiter'),
    path('cook/', views.cook_view, name='cook_panel'),
    path('admin-panel/', lambda request: redirect('/#admin'), name='admin_panel'),

    path('order/create/', api.order_create_legacy, name='create_order'),
    path('order/complete/<int:order_id>/', views.complete_order, name='complete_order'),
    path('table/close/<int:table_id>/', views.close_table, name='close_table'),

    path('api/state', api.api_state, name='api_state'),
    path('api/state/', api.api_state, name='api_state_slash'),
    path('api/events', api.api_events, name='api_events'),
    path('api/events/', api.api_events, name='api_events_slash'),
    path('api/we wish/', api.health, name='health'),
    path('api/health/', api.health, name='health_alias'),

    path('api/categories/', api.category_list, name='category_list'),
    path('api/categories/<int:pk>/', api.category_detail, name='category_detail'),

    path('api/products/', api.product_list, name='product_list'),
    path('api/products/<int:pk>/', api.product_detail, name='product_detail'),

    path('api/tables/', api.table_list, name='table_list'),
    path('api/tables/<int:pk>/', api.table_detail, name='table_detail'),
    path('api/tables/<int:pk>/close/', api.table_close, name='table_close'),
    path('api/tables/<int:pk>/open/', api.table_open, name='table_open'),

    path('api/orders/', api.order_list, name='order_list'),
    path('api/orders/<int:pk>/', api.order_detail, name='order_detail'),
    path('api/orders/<int:pk>/complete/', api.order_complete, name='order_complete'),
    path('api/orders/<int:pk>/items/', api.order_item_add, name='order_item_add'),
    path('api/orders/<int:pk>/items/<int:item_id>/', api.order_item_delete, name='order_item_delete'),

    path('api/tickets/', api.ticket_list, name='ticket_list'),
    path('api/tickets/<int:pk>/', api.ticket_detail, name='ticket_detail'),
    path('api/tickets/<int:pk>/accept/', api.ticket_accept, name='ticket_accept'),
    path('api/tickets/<int:pk>/ready/', api.ticket_ready, name='ticket_ready'),
    path('api/tickets/<int:pk>/seen/', api.ticket_seen, name='ticket_seen'),

    path('api/sales/', api.sale_list, name='sale_list'),
    path('api/sales/<int:pk>/', api.sale_detail, name='sale_detail'),

    path('api/table-states/', api.table_state_list, name='table_state_list'),
    path('api/table-states/<str:table_key>/', api.table_state_detail, name='table_state_detail'),

    path('api/settings/', api.settings, name='settings'),
    path('api/settings/reset/', api.settings_reset, name='settings_reset'),

    path('api/stats/summary/', api.stats_summary, name='stats_summary'),
    path('api/stats/fish/', api.stats_fish, name='stats_fish'),
    path('api/stats/other/', api.stats_other, name='stats_other'),
    path('api/legacy/cook-orders/', api.legacy_cook_orders, name='legacy_cook_orders'),
    path('api/legacy/admin-orders/', api.legacy_admin_orders, name='legacy_admin_orders'),
]