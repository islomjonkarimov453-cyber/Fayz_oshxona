// Orzu Baliqxonasi — API modellari.
//
// Barcha raqamlar API'dan `num` yoki `String` ko'rinishida kelishi mumkin,
// shuning uchun maydonlarni xavfsiz o'giruvchi yordamchilar ishlatiladi.

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return const {'1', 'true', 'yes', 'on'}.contains(value.toLowerCase());
  }
  return fallback;
}

Map<String, double> itemsFrom(dynamic raw) {
  final result = <String, double>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      final quantity = asDouble(value);
      if (quantity > 0) result[key.toString()] = quantity;
    });
  }
  return result;
}

class TableData {
  const TableData({
    required this.items,
    this.address = '',
    this.saboy = false,
  });

  final Map<String, double> items;
  final String address;
  final bool saboy;

  factory TableData.fromJson(Map<String, dynamic> json) => TableData(
        items: itemsFrom(json['items']),
        address: (json['address'] ?? '').toString(),
        saboy: asBool(json['saboy']),
      );
}

class Ticket {
  const Ticket({
    required this.id,
    required this.table,
    required this.items,
    required this.time,
    required this.done,
    required this.accepted,
    required this.seen,
    this.doneAt,
  });

  final int id;
  final String table;
  final Map<String, double> items;
  final int time;
  final bool done;
  final bool accepted;
  final bool seen;
  final int? doneAt;

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: asInt(json['id']),
        table: (json['table'] ?? '').toString(),
        items: itemsFrom(json['items']),
        time: asInt(json['time']),
        done: asBool(json['done']),
        accepted: asBool(json['acc']),
        seen: asBool(json['seen']),
        doneAt: json['doneAt'] == null ? null : asInt(json['doneAt']),
      );

  bool get readyForWaiter => done && !seen;
}

class Sale {
  const Sale({
    required this.id,
    required this.time,
    required this.table,
    required this.items,
    required this.sub,
    required this.pct,
    required this.fee,
    required this.total,
    required this.address,
    required this.prices,
  });

  final int id;
  final int time;
  final String table;
  final Map<String, double> items;
  final double sub;
  final double pct;
  final double fee;
  final double total;
  final String address;
  final Map<String, double> prices;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: asInt(json['id']),
        time: asInt(json['time']),
        table: (json['table'] ?? '').toString(),
        items: itemsFrom(json['items']),
        sub: asDouble(json['sub']),
        pct: asDouble(json['pct']),
        fee: asDouble(json['fee']),
        total: asDouble(json['total']),
        address: (json['address'] ?? '').toString(),
        prices: itemsFrom(json['prices']),
      );
}

/// Bitta umumiy holat surati: `GET /api/v1/state/` javobi.
class AppSnapshot {
  const AppSnapshot({
    required this.prices,
    required this.service,
    required this.tables,
    required this.tickets,
    required this.sales,
    required this.seq,
    required this.seqS,
    required this.rev,
  });

  final Map<String, double> prices;
  final double service;
  final Map<String, TableData> tables;
  final List<Ticket> tickets;
  final List<Sale> sales;
  final int seq;
  final int seqS;
  final int rev;

  static const empty = AppSnapshot(
    prices: {},
    service: 10,
    tables: {},
    tickets: [],
    sales: [],
    seq: 1,
    seqS: 0,
    rev: 0,
  );

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'];
    final tables = <String, TableData>{};
    if (rawTables is Map) {
      rawTables.forEach((key, value) {
        if (value is Map) {
          tables[key.toString()] =
              TableData.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    final rawTickets = json['tickets'];
    final tickets = <Ticket>[];
    if (rawTickets is List) {
      for (final entry in rawTickets) {
        if (entry is Map) {
          tickets.add(Ticket.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    final rawSales = json['sales'];
    final sales = <Sale>[];
    if (rawSales is List) {
      for (final entry in rawSales) {
        if (entry is Map) {
          sales.add(Sale.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return AppSnapshot(
      prices: itemsFrom(json['prices']),
      service: asDouble(json['service'], 10),
      tables: tables,
      tickets: tickets,
      sales: sales,
      seq: asInt(json['seq'], 1),
      seqS: asInt(json['seqS']),
      rev: asInt(json['_rev'] ?? json['rev']),
    );
  }

  double price(String key) => prices[key] ?? 0;

  double money(Map<String, double> items) {
    var sum = 0.0;
    items.forEach((key, quantity) {
      sum += quantity * price(key);
    });
    return sum;
  }

  TableData? table(String key) => tables[key];

  bool get hasUnacceptedTickets =>
      tickets.any((ticket) => !ticket.done && !ticket.accepted);

  List<Ticket> get readyTickets =>
      tickets.where((ticket) => ticket.readyForWaiter).toList();
}
