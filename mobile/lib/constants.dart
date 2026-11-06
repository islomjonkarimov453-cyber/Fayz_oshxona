// Ilovada ishlatiladigan doimiy qiymatlar va formatlash yordamchilari.

/// Mahsulot tavsifi: kalit, nomi, o'lchov birligi, qadam.
class ProductDef {
  const ProductDef(this.key, this.name, this.unit, this.step);

  final String key;
  final String name;
  final String unit;
  final double step;
}

const fishKeys = ['sazan', 'oq', 'buxarski', 'ilonbosh'];
const otherKeys = ['non', 'sous', 'fanta', 'cola'];

const products = <ProductDef>[
  ProductDef('sazan', 'Sazan', 'kg', 0.5),
  ProductDef('oq', 'Oq baliq', 'kg', 0.5),
  ProductDef('buxarski', 'Buxarski', 'kg', 0.5),
  ProductDef('ilonbosh', 'Ilonbosh', 'kg', 0.5),
  ProductDef('non', 'Non', 'dona', 1),
  ProductDef('sous', 'Sous', 'dona', 1),
  ProductDef('fanta', 'Fanta', 'dona', 1),
  ProductDef('cola', 'Cola', 'dona', 1),
];

ProductDef productByKey(String key) => products.firstWhere(
      (product) => product.key == key,
      orElse: () => ProductDef(key, key, 'dona', 1),
    );

String productName(String key) => productByKey(key).name;

const defaultPrices = <String, double>{
  'sazan': 80000,
  'oq': 90000,
  'buxarski': 100000,
  'ilonbosh': 110000,
  'non': 3000,
  'sous': 5000,
  'fanta': 12000,
  'cola': 12000,
};

const roomCount = 7;

bool isSaboyKey(String key) => key.startsWith('S');

/// "Hona 3" yoki "Saboy 2".
String tableLabel(String key) =>
    isSaboyKey(key) ? 'Saboy ${key.substring(1)}' : 'Hona $key';

double round2(double value) => (value * 100).round() / 100;

/// 1234567 -> "1 234 567"
String groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Pul summasi: 80000 -> "80 000".
String money(double value) => groupDigits(value.round().abs().toString());

/// Miqdor: 0.5 -> "0,5" emas, balki "0.5" (kg uchun qulay).
String quantityText(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String timeText(int milliseconds) {
  if (milliseconds <= 0) return '--:--';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${two(date.hour)}:${two(date.minute)}';
}

String dateTimeText(int milliseconds) {
  if (milliseconds <= 0) return '--';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String two(int value) => value.toString().padLeft(2, '0');
