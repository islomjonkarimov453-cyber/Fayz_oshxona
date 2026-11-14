from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0018_alter_sale_fee_alter_sale_sub_alter_sale_total'),
    ]

    operations = [
        migrations.AddField(
            model_name='tablestate',
            name='delivery',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='sale',
            name='delivery',
            field=models.BooleanField(default=False),
        ),
    ]
