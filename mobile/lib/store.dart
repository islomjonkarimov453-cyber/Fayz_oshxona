import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'constants.dart';
import 'models.dart';
import 'sound.dart';

/// Ilovaning yagona holat do'koni.
///
/// Har 2 sekundda `/api/v1/state/` dan yangilanadi (veb-versiyadagi kabi)
/// va barcha ekranlarga `ChangeNotifier` orqali xabar beradi.
class AppStore extends ChangeNotifier {
  AppStore({ApiClient? api}) : _api = api ?? ApiClient();

  static const _prefsKey = 'api_base_url';

  final ApiClient _api;

  AppSnapshot snapshot = AppSnapshot.empty;

  bool ready = false;
  bool online = true;
  bool mutating = false;
  String? lastError;

  Timer? _timer;
  Set<int> _readyTicketIds = <int>{};
  bool _loadedOnce = false;

  String get baseUrl => _api.baseUrl;

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String defaultBaseUrl() {
    if (kIsWeb) return Uri.base.origin;
    return isAndroid
        ? 'http://10.144.82.22:8000'
        : 'http://127.0.0.1:8000';
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _api.baseUrl = prefs.getString(_prefsKey) ?? defaultBaseUrl();
    } catch (_) {
      _api.baseUrl = defaultBaseUrl();
    }
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> setBaseUrl(String url) async {
    _api.baseUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _api.baseUrl);
    } catch (_) {
      // Sozlamani saqlab bo'lmasa ham davom etamiz.
    }
    notifyListeners();
    await refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (mutating) return;
    try {
      final data = await _api.get('/state/');
      _apply(data);
      online = true;
    } catch (error) {
      online = false;
      if (!silent) lastError = error.toString();
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  void _apply(dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    final rawState = payload['state'];
    if (rawState is! Map) return;

    final next = AppSnapshot.fromJson(Map<String, dynamic>.from(rawState));
    snapshot = next;

    final readyIds = next.readyTickets.map((ticket) => ticket.id).toSet();
    if (_loadedOnce && readyIds.difference(_readyTicketIds).isNotEmpty) {
      // Yangi tayyor taom — ofitsiantga ovozli signal.
      SoundFx.beep();
    }
    _readyTicketIds = readyIds;
    _loadedOnce = true;
  }

  /// O'zgartirish amali: bajarib, so'ng holatni darhol yangilaydi.
  Future<void> mutate(Future<void> Function() action) async {
    if (mutating) {
      throw ApiException('Oldingi amal hali tugamadi, biroz kuting.');
    }
    mutating = true;
    lastError = null;
    notifyListeners();
    try {
      await action();
      final data = await _api.get('/state/');
      _apply(data);
      online = true;
    } catch (error) {
      lastError = error.toString();
      if (error is ApiException && error.offline) online = false;
      rethrow;
    } finally {
      mutating = false;
      notifyListeners();
    }
  }

  // ---------------- Hisob-kitob ----------------

  double price(String key) => snapshot.price(key);

  double servicePercentFor(String tableKey) =>
      isSaboyKey(tableKey) ? 0 : snapshot.service;

  double serviceFee(String tableKey, double subtotal) =>
      (subtotal * servicePercentFor(tableKey) / 100).roundToDouble();

  double totalFor(String tableKey, Map<String, double> items) {
    final subtotal = snapshot.money(items);
    return subtotal + serviceFee(tableKey, subtotal);
  }

  /// Mavjud buyurtma + yangi qoralama.
  Map<String, double> mergedItems(
    String tableKey,
    Map<String, double> draft,
  ) {
    final result = <String, double>{...table(tableKey).items};
    draft.forEach((key, quantity) {
      if (quantity <= 0) return;
      result[key] = round2((result[key] ?? 0) + quantity);
    });
    return result;
  }

  TableData table(String key) =>
      snapshot.tables[key] ?? const TableData(items: {});

  // ---------------- Amallar ----------------

  Future<void> saveTableState(
    String tableKey,
    Map<String, double> items, {
    String address = '',
    bool? saboy,
  }) async {
    final payload = <String, dynamic>{
      'items': items,
      'address': address,
      'saboy': saboy ?? isSaboyKey(tableKey),
    };
    if (snapshot.tables.containsKey(tableKey)) {
      await _api.patch(
        '/table-states/${Uri.encodeComponent(tableKey)}/',
        payload,
      );
    } else {
      await _api.post('/table-states/', {
        'table_key': tableKey,
        ...payload,
      });
    }
  }

  Future<void> saveAddress(String tableKey, String address) async {
    final exists = snapshot.tables.containsKey(tableKey);
    if (exists) {
      await _api.patch(
        '/table-states/${Uri.encodeComponent(tableKey)}/',
        {'address': address},
      );
    } else {
      await _api.post('/table-states/', {
        'table_key': tableKey,
        'items': <String, double>{},
        'address': address,
        'saboy': isSaboyKey(tableKey),
      });
    }
  }

  Future<void> deleteTableState(String tableKey) async {
    await _api.delete(
      '/table-states/${Uri.encodeComponent(tableKey)}/',
    );
  }

  Future<void> createTicket(
    String tableKey,
    Map<String, double> items,
  ) async {
    await _api.post('/tickets/', {
      'table': tableKey,
      'items': items,
    });
  }

  Future<void> acceptTicket(int id) async {
    await _api.post('/tickets/$id/accept/');
  }

  Future<void> readyTicket(int id) async {
    await _api.post('/tickets/$id/ready/');
  }

  Future<void> seenTicket(int id) async {
    await _api.post('/tickets/$id/seen/');
  }

  Future<Sale> createSale(Map<String, dynamic> body) async {
    late Sale sale;
    await mutate(() async {
      final data = await _api.post('/sales/', body);
      sale = Sale.fromJson(Map<String, dynamic>.from(data as Map));
    });
    return sale;
  }

  Future<String> createSaboy() async {
    var key = '';
    await mutate(() async {
      final data = await _api.get('/settings/');
      final settings = Map<String, dynamic>.from(data as Map);
      final next = asInt(settings['seqS']) + 1;
      await _api.patch('/settings/', {'seqS': next});
      key = 'S$next';
      await _api.post('/table-states/', {
        'table_key': key,
        'items': <String, double>{},
        'saboy': true,
        'address': '',
      });
    });
    return key;
  }

  Future<void> saveSettings({
    required Map<String, double> prices,
    required double service,
  }) async {
    await _api.patch('/settings/', {
      'prices': prices,
      'service': service.round(),
    });
  }

  Future<void> resetAll() async {
    await _api.post('/settings/reset/');
  }
}
