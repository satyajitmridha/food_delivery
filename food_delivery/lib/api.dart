import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  ApiException(this.message, {this.unauthorized = false});

  @override
  String toString() => message;
}

/// Thin JSON client for api/v1. Always returns a decoded map or throws [ApiException].
class Api {
  static String? token;

  /// Called when the server says the login is no longer valid.
  static void Function()? onUnauthorized;

  static Future<Map<String, dynamic>> get(String route, {Map<String, String>? query}) =>
      _send('GET', route, query: query);

  static Future<Map<String, dynamic>> post(String route, [Map<String, dynamic>? body]) =>
      _send('POST', route, body: body ?? <String, dynamic>{});

  static Future<Map<String, dynamic>> _send(
    String method,
    String route, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final base = Uri.parse(AppConfig.apiBase);
    final params = <String, String>{...base.queryParameters, 'route': route, ...?query};
    final uri = base.replace(queryParameters: params);

    final headers = <String, String>{'Accept': 'application/json'};
    final t = token;
    if (t != null) {
      headers['X-Auth-Token'] = t;
      headers['Authorization'] = 'Bearer $t';
    }

    http.Response res;
    try {
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      } else {
        headers['Content-Type'] = 'application/json';
        res = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
            .timeout(const Duration(seconds: 20));
      }
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } on SocketException {
      throw ApiException('No internet connection.');
    } on http.ClientException {
      throw ApiException('Could not reach the server.');
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      throw ApiException('The server sent an unexpected response (${res.statusCode}).');
    }

    if (res.statusCode == 401) {
      final hadToken = token != null;
      if (hadToken) {
        token = null;
        onUnauthorized?.call();
      }
      throw ApiException((data['error'] as String?) ?? 'Please log in again.', unauthorized: hadToken);
    }
    if (data['success'] == false || res.statusCode >= 400) {
      throw ApiException((data['error'] as String?) ?? 'Something went wrong (${res.statusCode}).');
    }
    return data;
  }
}
