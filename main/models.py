from django.db import models

class Banners(models.Model):
    title = models.CharField(max_length=100)
    description = models.TextField()

    def __str__(self):
        return self.title



class Service(models.Model):
    title = models.CharField(max_length=200)
    slug = models.SlugField(unique=True)
    icon = models.ImageField(upload_to='services/')
    short_description = models.CharField(max_length=200)
    full_content = models.TextField()
    order = models.IntegerField()

    class Meta:
        verbose_name = "Service"
        verbose_name_plural = "Service"
        ordering = ['order']

    def __str__(self):
        return self.title

class Categories(models.Model):
    name = models.CharField(max_length=100)
    def __str__(self):
        return self.name

class Blogs(models.Model):
    category = models.ForeignKey(Categories,on_delete=models.CASCADE)
    title = models.CharField(max_length=100)
    description = models.TextField()
    image = models.ImageField(upload_to='blogs',verbose_name="Image")
    def __str__(self):
        return self.title

class AboutSections(models.Model):
    title = models.CharField(max_length=100)
    description = models.TextField()
    image = models.ImageField(upload_to='about/sections',verbose_name="Image")
    video = models.FileField(upload_to='about/sections',verbose_name="Video")
    def __str__(self):
        return self.title

class ContactInfo(models.Model):
    phone = models.CharField(max_length=100)
    email = models.EmailField()
    location = models.CharField(max_length=100)


class Contact(models.Model):
    name = models.CharField(max_length=150, verbose_name="Ismi")
    phone = models.CharField(max_length=20, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    message = models.TextField()
    def __str__(self):
        return f"{self.name} - {self.phone}"

    class Meta:
        verbose_name = "Xabar"
        verbose_name_plural = "Xabarlar"
