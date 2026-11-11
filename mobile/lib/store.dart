import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'constants.dart';
import 'models.dart';

/// Ilovaning yagona holat do'koni.
///
/// Har 2 sekundda `/api/v1/state/` dan yangilanadi (veb-versiyadagi kabi)
/// va barcha ekranlarga `ChangeNotifier` orqali xabar beradi.
class AppStore extends ChangeNotifier {
  AppStore({ApiClient? api}) : _api = api ?? ApiClient();

  static const _prefsKey = 'api_base_url';
  static const _sessionKey = 'saved_session';

  final ApiClient _api;

  AppSnapshot snapshot = AppSnapshot.empty;

  bool ready = false;
  bool online = true;
  bool mutating = false;
  String? lastError;

  Timer? _timer;

  String get baseUrl => _api.baseUrl;

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String defaultBaseUrl() {
    if (kIsWeb) return Uri.base.origin;
    return 'https://fayz-baliqhona.uz';
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var saved = prefs.getString(_prefsKey);
      // Eski Render manzili saqlanib qolgan bo'lsa — yangi domen bilan almashtiramiz.
      if (saved != null && saved.contains('onrender.com')) {
        saved = null;
        await prefs.remove(_prefsKey);
      }
      _api.baseUrl = saved ?? defaultBaseUrl();
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

  /// Login: username + password -> rol ('admin' | 'cook' | 'waiter').
  Future<String> login(String username, String password) async {
    final data = await _api.post('/login/', {
      'username': username.trim(),
      'password': password,
    });
    if (data is Map && data['role'] != null) {
      return data['role'].toString();
    }
    throw ApiException('Kirish xatosi');
  }

  /// Login sessiyasini eslab qoladi (keyingi ochilishda auto-login).
  Future<void> saveSession(String username, String password, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({'username': username, 'password': password, 'role': role}),
      );
    } catch (_) {
      // Saqlab bo'lmasa ham davom etamiz.
    }
  }

  /// Saqlangan sessiyani o'qiydi.
  Future<Map<String, String>?> savedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is Map && data['username'] != null && data['password'] != null) {
        return {
          'username': data['username'].toString(),
          'password': data['password'].toString(),
          'role': (data['role'] ?? 'admin').toString(),
        };
      }
    } catch (_) {
      // Xato bo'lsa sessiya yo'q deb hisoblaymiz.
    }
    return null;
  }

  /// Sessiyani o'chiradi (chiqish).
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {
      // e'tiborsiz
    }
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
    Map<String, dynamic> items, {
    String address = '',
    bool? saboy,
    String? linkedTable,
  }) async {
    final payload = <String, dynamic>{
      'items': items,
      'address': address,
      'saboy': saboy ?? isSaboyKey(tableKey),
      if (linkedTable != null) 'linked_table': linkedTable,
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
    Map<String, double> items, {
    List<Map<String, dynamic>>? fishOrders,
  }) async {
    final payloadItems = <String, dynamic>{...items};
    if (fishOrders != null && fishOrders.isNotEmpty) {
      payloadItems['_fish'] = fishOrders;
    }
    await _api.post('/tickets/', {
      'table': tableKey,
      'items': payloadItems,
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

  Future<String> createSaboy({String linkedTable = ''}) async {
    var key = '';
    await mutate(() async {
      final data = await _api.get('/settings/');
      final settings = Map<String, dynamic>.from(data as Map);
      final next = asInt(settings['seqS']) + 1;
      await _api.patch('/settings/', {'seqS': next});
      key = 'S$next';
      await _api.post('/table-states/', {
        'table_key': key,
        'items': <String, dynamic>{},
        'saboy': true,
        'address': '',
        'linked_table': linkedTable,
      });
    });
    return key;
  }

  Future<void> saveSettings({
    required Map<String, double> prices,
    required double service,
    List<Map<String, dynamic>>? fishList,
    Map<String, double>? stock,
  }) async {
    final body = <String, dynamic>{
      'prices': prices,
      'service': service.round(),
    };
    if (fishList != null) body['fishList'] = fishList;
    if (stock != null) body['stock'] = stock;
    await _api.patch('/settings/', body);
  }

  Future<void> resetAll() async {
    await _api.post('/settings/reset/');
  }

  Future<void> reopenSale(Sale sale) async {
    await _api.post('/sales/${sale.id}/reopen/');
  }

  Future<void> clearSales() async {
    await _api.delete('/sales/clear/');
  }
}
