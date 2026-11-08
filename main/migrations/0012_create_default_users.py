from django.contrib.auth import get_user_model
from django.db import migrations


DEFAULT_PASSWORD = 'admin123'


def create_default_users(apps, schema_editor):
    User = get_user_model()
    for username in ('admin', 'admin2', 'admin3'):
        if not User.objects.filter(username=username).exists():
            User.objects.create_user(
                username=username,
                password=DEFAULT_PASSWORD,
                first_name=username,
            )


def remove_default_users(apps, schema_editor):
    User = get_user_model()
    User.objects.filter(username__in=('admin', 'admin2', 'admin3')).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0011_appstate_fish_list'),
    ]

    operations = [
        migrations.RunPython(create_default_users, remove_default_users),
    ]
