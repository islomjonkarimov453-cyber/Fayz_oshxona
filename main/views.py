from functools import wraps

from django.conf import settings
from django.contrib.auth import authenticate, login as auth_login, logout as auth_logout
from django.contrib.auth.decorators import login_required
from django.http import FileResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.cache import never_cache
from django.views.static import serve as static_serve

from .models import Category, Order, Product, Table
from .state import bump_revision

# Har bir login o'z sahifasiga ega — boshqalariga kira olmaydi.
ROLE_PAGES = {'admin': 'admin', 'admin2': 'cook', 'admin3': 'waiter'}
ROLE_URLS = {'admin': 'main:main', 'cook': 'main:cook_panel', 'waiter': 'main:waiter'}
ROLE_LABELS = {'admin': 'Admin', 'cook': 'Oshpaz', 'waiter': 'Ofitsiant'}


def role_required(role):
    def decorator(view):
        @wraps(view)
        @login_required
        def wrapper(request, *args, **kwargs):
            user_role = ROLE_PAGES.get(request.user.username)
            if user_role is None:
                auth_logout(request)
                return redirect('main:login')
            if user_role != role:
                return redirect(ROLE_URLS[user_role])
            return view(request, *args, **kwargs)
        return wrapper
    return decorator


@never_cache
def service_worker(request):
    response = FileResponse(
        open(settings.BASE_DIR / 'static' / 'sw.js', 'rb'),
        content_type='application/javascript',
    )
    response['Service-Worker-Allowed'] = '/'
    response['Cache-Control'] = 'no-cache'
    return response


def flutter_app(request, path=''):
    root = settings.BASE_DIR / 'static' / 'app'
    if not path:
        path = 'index.html'
    return static_serve(request, path, document_root=str(root))


def login_view(request):
    if request.user.is_authenticated:
        return redirect(ROLE_URLS.get(ROLE_PAGES.get(request.user.username), 'main:main'))
    from django.contrib.auth.models import User
    users = [
        {'username': u.username, 'name': u.get_full_name() or u.username,
         'role': ROLE_LABELS[ROLE_PAGES[u.username]]}
        for u in User.objects.filter(is_active=True, username__in=ROLE_PAGES)
        .order_by('username')
    ]
    error = None
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '')
        user = authenticate(request, username=username, password=password)
        if user is not None and username in ROLE_PAGES:
            auth_login(request, user)
            return redirect(ROLE_URLS[ROLE_PAGES[username]])
        error = "Login yoki parol noto'g'ri"
    return render(request, 'login.html', {'error': error, 'users': users})


def logout_view(request):
    auth_logout(request)
    return redirect('main:login')


@role_required('waiter')
def waiter_view(request):
    tables = Table.objects.order_by('number')
    products = Product.objects.select_related('category').order_by('id')
    categories = Category.objects.prefetch_related('products').order_by('id')
    order_type = request.GET.get('order_type')
    return render(
        request,
        'waiter.html',
        {
            'tables': tables,
            'products': products,
            'categories': categories,
            'order_type': order_type,
        },
    )


@role_required('cook')
def cook_view(request):
    orders = Order.objects.filter(status='Yangi').select_related('table').prefetch_related('items__product')
    return render(request, 'cook.html', {'orders': orders})


@role_required('admin')
def admin_view(request):
    orders = Order.objects.select_related('table').prefetch_related('items__product').order_by('-created_at')
    tables = Table.objects.order_by('number')
    return render(request, 'admin.html', {'orders': orders, 'tables': tables})


@login_required
def complete_order(request, order_id):
    order = get_object_or_404(Order, id=order_id)
    order.status = 'Tayyor'
    order.save(update_fields=['status'])
    bump_revision()
    return redirect('main:cook_panel')


@login_required
def close_table(request, table_id):
    table = get_object_or_404(Table, id=table_id)
    table.is_busy = False
    table.save(update_fields=['is_busy'])
    bump_revision()
    return redirect('main:admin_panel')
