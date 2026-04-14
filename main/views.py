import requests
from django.shortcuts import render, get_object_or_404
from .models import AboutSections, Service, Banners, ContactInfo,Blogs,Contact
from django.shortcuts import render,redirect
from django.contrib import messages
from .models import Blogs
from .models import Service


def contact_view(request):
    success = False
    if request.method == "POST":
        name = request.POST.get('name')
        phone = request.POST.get('phone')
        message_text = request.POST.get('message')

        bot_token = "8743515961:AAG8rJ5_fzIGRvQxGs1H40VCyMo36JhOOF8"
        chat_id = "7644562720"
        text = f"👤 Ism: {name}\n📞 Tel: {phone}\n📝 Xabar: {message_text}"
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage?chat_id={chat_id}&text={text}"

        try:
            requests.get(url)

            Contact.objects.create(
                name=name,
                phone=phone,
                message=message_text
            )
            success = True
        except Exception as e:
            print(f"Xatolik yuz berdi: {e}")

    return render(request, 'contact.html', {'success': success})


def index(request):
    context = {
        'banner': Banners.objects.first(),
        'services': Service.objects.all(),
        'about': AboutSections.objects.first(),
        'contact_info': ContactInfo.objects.first(),
        'blogs': Blogs.objects.all(),

    }
    return render(request, 'index.html', context)

def about(request):
    return render(request, 'about.html')

def courses(request):
    services = Service.objects.all()
    return render(request, 'courses.html', {'services': services})

def contact(request):
    if request.method == "POST":
        name = request.POST.get('name')
        phone = request.POST.get('phone')
        message = request.POST.get('message')

        Contact.objects.create(name=name, phone=phone, message=message)

        return render(request, 'contact.html', {'success': True})

    return render(request, 'contact.html')

def service_detail(request, slug):
    service = get_object_or_404(Service, slug=slug)
    return render(request, 'service_detail.html', {'service': service})
def blog_detail(request, pk):
    post = get_object_or_404(Blogs, pk=pk)
    return render(request, 'blog_detail.html', {'post': post})
def all_services(request):
    services = Service.objects.all()
    return render(request, 'all_services.html', {'services': services})
