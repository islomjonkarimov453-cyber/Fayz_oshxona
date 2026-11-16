from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0019_delivery_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='appstate',
            name='costs',
            field=models.JSONField(default=dict),
        ),
    ]
