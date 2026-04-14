from django.urls import path
from . import views
from django.conf.urls.static import static
from .views import contact_view
from .views import Blogs, blog_detail

urlpatterns = [
    path('', views.index, name='index'),
    path('about/', views.about, name='about'),
    path('courses/', views.courses, name='courses'),
    path('contact/', views.contact, name='contact'),
    path('service/<slug:slug>/', views.service_detail, name='service_detail'),
    path('contact/', contact_view, name='contact'),
    path('blog/<int:pk>/', views.blog_detail, name='blog_detail'),
    path('services/', views.all_services, name='all_services'),
]
