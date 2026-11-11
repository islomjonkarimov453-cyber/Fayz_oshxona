// Fayz Baliqxonasi — API modellari.
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
    this.linkedTable = '',
    this.fishOrders = const [],
  });

  final Map<String, double> items;
  final String address;
  final bool saboy;
  final String linkedTable;
  final List<FishOrder> fishOrders;

  factory TableData.fromJson(Map<String, dynamic> json) {
    final fishOrders = <FishOrder>[];
    final rawItems = json['items'];
    if (rawItems is Map && rawItems['_fish'] is List) {
      for (final entry in rawItems['_fish'] as List) {
        if (entry is Map) {
          fishOrders.add(FishOrder.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return TableData(
      items: itemsFrom(json['items']),
      address: (json['address'] ?? '').toString(),
      saboy: asBool(json['saboy']),
      linkedTable: (json['linked_table'] ?? json['linkedTable'] ?? '').toString(),
      fishOrders: fishOrders,
    );
  }
}

/// Admin tomonidan kiritilgan baliq og'irligi (kg).
class FishStock {
  const FishStock({required this.id, required this.key, required this.kg});

  final int id;
  final String key;
  final double kg;

  factory FishStock.fromJson(Map<String, dynamic> json) => FishStock(
        id: asInt(json['id']),
        key: (json['key'] ?? '').toString(),
        kg: asDouble(json['kg']),
      );
}

/// Oshpazga boradigan baliq tafsiloti: turi, og'irligi va piyoz turi.
class FishOrder {
  const FishOrder({
    required this.key,
    required this.kg,
    required this.onion,
    this.cut = 'butun',
  });

  final String key;
  final double kg;
  final String onion;
  final String cut;

  factory FishOrder.fromJson(Map<String, dynamic> json) => FishOrder(
        key: (json['key'] ?? '').toString(),
        kg: asDouble(json['kg']),
        onion: (json['onion'] ?? '').toString(),
        cut: (json['cut'] ?? 'butun').toString(),
      );

  String get onionLabel => onion == 'sovusli' ? 'Sovusli' : 'Sovussiz';
  String get cutLabel => cut == 'kusok' ? 'Kusok' : 'Butun';
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
    this.fishOrders = const [],
  });

  final int id;
  final String table;
  final Map<String, double> items;
  final int time;
  final bool done;
  final bool accepted;
  final bool seen;
  final int? doneAt;
  final List<FishOrder> fishOrders;

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final fishOrders = <FishOrder>[];
    final rawItems = json['items'];
    if (rawItems is Map && rawItems['_fish'] is List) {
      for (final entry in rawItems['_fish'] as List) {
        if (entry is Map) {
          fishOrders.add(FishOrder.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return Ticket(
      id: asInt(json['id']),
      table: (json['table'] ?? '').toString(),
      items: itemsFrom(json['items']),
      time: asInt(json['time']),
      done: asBool(json['done']),
      accepted: asBool(json['acc']),
      seen: asBool(json['seen']),
      doneAt: json['doneAt'] == null ? null : asInt(json['doneAt']),
      fishOrders: fishOrders,
    );
  }

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
    this.linkedTable = '',
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
  final String linkedTable;

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
        linkedTable: (json['linked_table'] ?? json['linkedTable'] ?? '').toString(),
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
    required this.fishList,
    required this.stock,
    required this.closedDates,
    required this.retentionDays,
  });

  final Map<String, double> prices;
  final double service;
  final Map<String, TableData> tables;
  final List<Ticket> tickets;
  final List<Sale> sales;
  final int seq;
  final int seqS;
  final int rev;
  final List<FishStock> fishList;
  final Map<String, double> stock;
  final List<String> closedDates;
  final int retentionDays;

  static const empty = AppSnapshot(
    prices: {},
    service: 10,
    tables: {},
    tickets: [],
    sales: [],
    seq: 1,
    seqS: 0,
    rev: 0,
    fishList: [],
    stock: {},
    closedDates: [],
    retentionDays: 10,
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

    final rawFishList = json['fishList'];
    final fishList = <FishStock>[];
    if (rawFishList is List) {
      for (final entry in rawFishList) {
        if (entry is Map) {
          fishList.add(FishStock.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    final rawClosedDates = json['closedDates'];
    final closedDates = <String>[
      if (rawClosedDates is List)
        for (final entry in rawClosedDates) entry.toString(),
    ];

    return AppSnapshot(
      prices: itemsFrom(json['prices']),
      service: asDouble(json['service'], 10),
      tables: tables,
      tickets: tickets,
      sales: sales,
      seq: asInt(json['seq'], 1),
      seqS: asInt(json['seqS']),
      rev: asInt(json['_rev'] ?? json['rev']),
      fishList: fishList,
      stock: itemsFrom(json['stock']),
      closedDates: closedDates,
      retentionDays: asInt(json['retentionDays'], 10),
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
