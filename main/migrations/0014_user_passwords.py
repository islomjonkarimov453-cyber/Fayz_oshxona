from django.contrib.auth import get_user_model
from django.db import migrations


# Har bir foydalanuvchiga alohida parol va ism.
USER_SETTINGS = {
    'admin': {'password': 'admin123', 'first_name': 'Admin'},
    'admin2': {'password': 'oshpaz123', 'first_name': 'Oshpaz'},
    'admin3': {'password': 'ofitsant123', 'first_name': 'Ofitsiant'},
}


def set_user_passwords(apps, schema_editor):
    User = get_user_model()
    for username, data in USER_SETTINGS.items():
        user = User.objects.filter(username=username).first()
        if user is None:
            user = User.objects.create_user(username=username)
        user.set_password(data['password'])
        user.first_name = data['first_name']
        user.save()


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0013_appstate_stock'),
    ]

    operations = [
        migrations.RunPython(set_user_passwords, migrations.RunPython.noop),
    ]
