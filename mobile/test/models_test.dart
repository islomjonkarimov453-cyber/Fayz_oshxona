import 'package:fayz_baliqxona/constants.dart';
import 'package:fayz_baliqxona/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('state snapshot API javobini o\'qiydi', () {
    final snapshot = AppSnapshot.fromJson({
      'prices': {'sazan': 80000, 'non': '3000'},
      'service': '10',
      'tables': {
        '1': {
          'items': {'sazan': 0.5, 'non': 2},
          'address': '',
          'saboy': false,
        },
        'S1': {
          'items': <String, dynamic>{},
          'address': 'Chilonzor 5',
          'saboy': true,
        },
      },
      'tickets': [
        {
          'id': 3,
          'table': '1',
          'items': {'sazan': 0.5},
          'time': 1700000000000,
          'done': true,
          'acc': true,
          'seen': false,
          'doneAt': 1700000010000,
        },
      ],
      'sales': [
        {
          'id': 7,
          'time': 1700000000000,
          'table': '1',
          'items': {'sazan': 1.5},
          'sub': '120000.00',
          'pct': 10,
          'fee': '12000.00',
          'total': '132000.00',
          'prices': {'sazan': 80000},
        },
      ],
      'seq': 4,
      'seqS': 1,
      '_rev': 12,
    });

    expect(snapshot.price('sazan'), 80000);
    expect(snapshot.price('non'), 3000);
    expect(snapshot.service, 10);
    expect(snapshot.tables['1']!.items['sazan'], 0.5);
    expect(snapshot.tables['S1']!.address, 'Chilonzor 5');
    expect(snapshot.readyTickets.single.id, 3);
    expect(snapshot.sales.single.total, 132000);
    expect(snapshot.rev, 12);
    expect(snapshot.hasUnacceptedTickets, isFalse);

    // Xizmat haqi: 1.5 kg * 80 000 = 120 000 + 10% = 132 000.
    final items = {'sazan': 1.5};
    expect(snapshot.money(items), 120000);
  });

  test('saboy uchun xizmat haqi olinmaydi', () {
    expect(isSaboyKey('S2'), isTrue);
    expect(tableLabel('3'), 'Hona 3');
    expect(tableLabel('S2'), 'Saboy 2');
  });

  test('sonlarni formatlash', () {
    expect(money(1234567.4), '1 234 567');
    expect(quantityText(0.5), '0.5');
    expect(quantityText(2), '2');
  });
}
