from django.db import transaction
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .api import _current_price, _sales_for_period, _sale_price, _sale_quantity
from .drf_serializers import (
    AppStateSerializer,
    CategorySerializer,
    OrderSerializer,
    ProductSerializer,
    SaleSerializer,
    TableSerializer,
    TableStateSerializer,
    TicketSerializer,
    _normalize_order_items,
    _recalculate_order_total,
    now_ms,
)
from .models import (
    AppState,
    Category,
    Order,
    Product,
    Sale,
    Table,
    TableState,
    Ticket,
)
from .state import (
    DEFAULT_PRICES,
    FISH_KEYS,
    OTHER_KEYS,
    PRODUCT_LABELS,
    bump_revision,
    consume_fish_list,
    consume_stock,
    load_state_from_db,
    notify_subscribers,
)


class RevisionMixin:
    """Har bir yozish amalidan keyin umumiy revision'ni oshiradi."""

    def perform_create(self, serializer):
        serializer.save()
        bump_revision()

    def perform_update(self, serializer):
        serializer.save()
        bump_revision()

    def perform_destroy(self, instance):
        instance.delete()
        bump_revision()


class CategoryViewSet(RevisionMixin, viewsets.ModelViewSet):
    queryset = Category.objects.order_by('id')
    serializer_class = CategorySerializer


class ProductViewSet(RevisionMixin, viewsets.ModelViewSet):
    serializer_class = ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.select_related('category').order_by('id')
        category_id = self.request.query_params.get('category')
        if category_id:
            queryset = queryset.filter(category_id=category_id)
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(name__icontains=search)
        return queryset


class TableViewSet(RevisionMixin, viewsets.ModelViewSet):
    queryset = Table.objects.order_by('number')
    serializer_class = TableSerializer

    @action(detail=True, methods=['post'])
    def open(self, request, pk=None):
        table = self.get_object()
        table.is_busy = True
        table.save(update_fields=['is_busy'])
        bump_revision()
        return Response(self.get_serializer(table).data)

    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        table = self.get_object()
        table.is_busy = False
        table.save(update_fields=['is_busy'])
        bump_revision()
        return Response(self.get_serializer(table).data)


class OrderViewSet(RevisionMixin, viewsets.ModelViewSet):
    serializer_class = OrderSerializer

    def get_queryset(self):
        queryset = (
            Order.objects
            .select_related('table')
            .prefetch_related('items__product')
            .order_by('-created_at')
        )
        status_value = self.request.query_params.get('status')
        if status_value:
            queryset = queryset.filter(status=status_value)
        order_type = self.request.query_params.get('order_type')
        if order_type:
            queryset = queryset.filter(order_type=order_type)
        table_id = self.request.query_params.get('table')
        if table_id:
            queryset = queryset.filter(table_id=table_id)
        return queryset

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        order = self.get_object()
        order.status = str(request.data.get('status') or 'Tayyor').strip()
        order.save(update_fields=['status'])
        bump_revision()
        return Response(self.get_serializer(order).data)

    @action(detail=True, methods=['post'], url_path='items')
    def add_items(self, request, pk=None):
        order = self.get_object()
        rows = _normalize_order_items(request.data.get('items'))
        with transaction.atomic():
            for product, quantity in rows:
                order.items.create(product=product, quantity=quantity)
            _recalculate_order_total(order)
        bump_revision()
        return Response(self.get_serializer(order).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['delete'], url_path=r'items/(?P<item_id>\d+)')
    def remove_item(self, request, pk=None, item_id=None):
        order = self.get_object()
        item = order.items.filter(pk=item_id).first()
        if item is None:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        item.delete()
        _recalculate_order_total(order)
        bump_revision()
        return Response(self.get_serializer(order).data)


class TicketViewSet(RevisionMixin, viewsets.ModelViewSet):
    serializer_class = TicketSerializer

    def perform_create(self, serializer):
        ticket = serializer.save()
        consume_fish_list(ticket.items)
        bump_revision()

    def get_queryset(self):
        queryset = Ticket.objects.order_by('id')
        for key in ('done', 'acc', 'seen'):
            value = self.request.query_params.get(key)
            if value is not None:
                queryset = queryset.filter(**{key: value.lower() in ('1', 'true', 'yes', 'on')})
        table_key = self.request.query_params.get('table')
        if table_key:
            queryset = queryset.filter(table_key=table_key)
        return queryset

    @action(detail=True, methods=['post'])
    def accept(self, request, pk=None):
        ticket = self.get_object()
        ticket.acc = True
        ticket.save(update_fields=['acc'])
        bump_revision()
        return Response(self.get_serializer(ticket).data)

    @action(detail=True, methods=['post'])
    def ready(self, request, pk=None):
        ticket = self.get_object()
        ticket.done = True
        ticket.seen = False
        ticket.done_at = now_ms()
        ticket.save(update_fields=['done', 'seen', 'done_at'])
        bump_revision()
        return Response(self.get_serializer(ticket).data)

    @action(detail=True, methods=['post'])
    def seen(self, request, pk=None):
        ticket = self.get_object()
        ticket.seen = True
        ticket.save(update_fields=['seen'])
        bump_revision()
        return Response(self.get_serializer(ticket).data)


class SaleViewSet(RevisionMixin, viewsets.ModelViewSet):
    serializer_class = SaleSerializer

    def perform_create(self, serializer):
        sale = serializer.save()
        consume_fish_list(sale.items)
        consume_stock(sale.items)
        bump_revision()

    def get_queryset(self):
        queryset = Sale.objects.order_by('id')
        period = self.request.query_params.get('period')
        if period:
            try:
                queryset = _sales_for_period(period)
            except ValueError as exc:
                raise ValidationError({'period': str(exc)})
        start = self.request.query_params.get('from')
        if start:
            queryset = queryset.filter(time__gte=start)
        end = self.request.query_params.get('to')
        if end:
            queryset = queryset.filter(time__lte=end)
        return queryset


class TableStateViewSet(RevisionMixin, viewsets.ModelViewSet):
    queryset = TableState.objects.order_by('table_key')
    serializer_class = TableStateSerializer
    lookup_field = 'table_key'


class SettingsAPIView(APIView):
    def get(self, request):
        app_state = AppState.get_state()
        return Response(AppStateSerializer(app_state).data)

    def put(self, request):
        return self._save(request, partial=False)

    def patch(self, request):
        return self._save(request, partial=True)

    def _save(self, request, partial):
        app_state = AppState.get_state()
        serializer = AppStateSerializer(app_state, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        bump_revision()
        app_state.refresh_from_db()
        return Response(AppStateSerializer(app_state).data)


class SettingsResetAPIView(APIView):
    def post(self, request):
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
        return Response(AppStateSerializer(app_state).data)


def _period(request):
    period = request.query_params.get('period', 'all')
    try:
        return period, _sales_for_period(period)
    except ValueError as exc:
        raise ValidationError({'period': str(exc)})


class StatsSummaryAPIView(APIView):
    def get(self, request):
        period, sales = _period(request)
        sales = list(sales)
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
        return Response({
            'period': period,
            'receipts': len(sales),
            'revenue': round(revenue, 2),
            'items_total': round(items_total, 2),
            'service_fee': round(service_fee, 2),
            'fish_kg': round(fish_kg, 2),
            'busy_tables': busy_tables,
            'total_tables': total_tables,
        })


class StatsFishAPIView(APIView):
    def get(self, request):
        period, sales = _period(request)
        sales = list(sales)
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
        return Response({
            'period': period,
            'results': results,
            'total_kg': round(total_kg, 2),
            'total_amount': round(total_amount, 2),
        })


class StatsOtherAPIView(APIView):
    def get(self, request):
        period, sales = _period(request)
        sales = list(sales)
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
        return Response({
            'period': period,
            'results': results,
            'total_amount': round(total_amount, 2),
        })


class StateAPIView(APIView):
    """Read-only snapshot (frontend polling uchun)."""

    def get(self, request):
        state = load_state_from_db()
        return Response({'rev': state['_rev'], 'state': state})


class LoginAPIView(APIView):
    """Mobil ilova login: username + password -> rol."""

    ROLE_BY_USERNAME = {'admin': 'admin', 'admin2': 'cook', 'admin3': 'waiter'}

    def post(self, request):
        from django.contrib.auth import authenticate

        username = (request.data.get('username') or '').strip()
        password = request.data.get('password') or ''
        role = self.ROLE_BY_USERNAME.get(username)
        if role is None:
            return Response({'error': "Login yoki parol noto'g'ri"},
                            status=status.HTTP_401_UNAUTHORIZED)
        user = authenticate(request, username=username, password=password)
        if user is None:
            return Response({'error': "Login yoki parol noto'g'ri"},
                            status=status.HTTP_401_UNAUTHORIZED)
        return Response({'role': role, 'name': user.get_full_name() or username})


class HealthAPIView(APIView):
    def get(self, request):
        from django.utils import timezone

        return Response({
            'status': 'ok',
            'rev': AppState.get_state()._rev,
            'time': int(timezone.now().timestamp() * 1000),
        })
