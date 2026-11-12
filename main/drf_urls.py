from django.urls import path
from rest_framework.routers import DefaultRouter

from . import drf_views

router = DefaultRouter()
router.register('categories', drf_views.CategoryViewSet, basename='category')
router.register('products', drf_views.ProductViewSet, basename='product')
router.register('tables', drf_views.TableViewSet, basename='table')
router.register('orders', drf_views.OrderViewSet, basename='order')
router.register('tickets', drf_views.TicketViewSet, basename='ticket')
router.register('sales', drf_views.SaleViewSet, basename='sale')
router.register('table-states', drf_views.TableStateViewSet, basename='table-state')

urlpatterns = [
    path('settings/', drf_views.SettingsAPIView.as_view(), name='v1_settings'),
    path('settings/fish/', drf_views.FishWeightAPIView.as_view(), name='v1_settings_fish'),
    path('settings/reset/', drf_views.SettingsResetAPIView.as_view(), name='v1_settings_reset'),
    path('settings/close-day/', drf_views.CloseDayAPIView.as_view(), name='v1_settings_close_day'),
    path('stats/summary/', drf_views.StatsSummaryAPIView.as_view(), name='v1_stats_summary'),
    path('stats/fish/', drf_views.StatsFishAPIView.as_view(), name='v1_stats_fish'),
    path('stats/other/', drf_views.StatsOtherAPIView.as_view(), name='v1_stats_other'),
    path('state/', drf_views.StateAPIView.as_view(), name='v1_state'),
    path('login/', drf_views.LoginAPIView.as_view(), name='v1_login'),
    path('health/', drf_views.HealthAPIView.as_view(), name='v1_health'),
] + router.urls
