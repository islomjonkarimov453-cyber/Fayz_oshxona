from django.contrib import admin
from .models import (
    Banners, Service, Categories,
    Blogs, AboutSections, ContactInfo, Contact
)
admin.site.register(Banners)
admin.site.register(Service)
admin.site.register(Categories)
admin.site.register(Blogs)
admin.site.register(AboutSections)
admin.site.register(ContactInfo)
admin.site.register(Contact)

