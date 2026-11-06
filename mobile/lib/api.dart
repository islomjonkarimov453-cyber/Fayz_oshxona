import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Foydalanuvchiga ko'rsatish uchun qulay xato xabari.
class ApiException implements Exception {
  ApiException(this.message, {this.offline = false});

  final String message;

  /// `true` — serverga umuman ulanib bo'lmadi (tarmoq xatosi).
  final bool offline;

  @override
  String toString() => message;
}

/// Django REST Framework backend bilan aloqa.
class ApiClient {
  ApiClient({String baseUrl = ''}) : _baseUrl = baseUrl;

  String _baseUrl;
  final http.Client _client = http.Client();

  String get baseUrl => _baseUrl;

  void dispose() => _client.close();

  set baseUrl(String value) {
    var cleaned = value.trim();
    if (cleaned.isEmpty) cleaned = 'http://127.0.0.1:8000';
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    _baseUrl = cleaned;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl/api/v1$path');

  static const _timeout = Duration(seconds: 12);

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = _uri(path);
    final headers = <String, String>{'Content-Type': 'application/json'};

    late http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Server javob bermadi (timeout).\nManzil: $_baseUrl',
        offline: true,
      );
    } catch (e) {
      throw ApiException(
        'Server bilan aloqa yo\'q.\nManzil: $_baseUrl\nXato: $e',
        offline: true,
      );
    }

    dynamic data;
    if (response.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorText(data, response.statusCode));
    }
    return data;
  }

  String _errorText(dynamic data, int statusCode) {
    if (data is String && data.trim().isNotEmpty) return data;
    if (data is Map) {
      final direct = data['error'] ?? data['detail'];
      if (direct != null) return direct.toString();
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List) return '${entry.key}: ${value.join(', ')}';
        if (value != null) return '${entry.key}: $value';
      }
    }
    return 'HTTP xatolik ($statusCode)';
  }
}
