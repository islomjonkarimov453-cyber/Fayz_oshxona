from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0012_create_default_users'),
    ]

    operations = [
        migrations.AddField(
            model_name='appstate',
            name='stock',
            field=models.JSONField(default=dict),
        ),
    ]
