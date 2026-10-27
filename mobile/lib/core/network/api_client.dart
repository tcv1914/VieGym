import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Backend trả lỗi có mã (docs/05-api-contract.md §1.1).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
  });

  factory ApiException.fromResponse(int statusCode, Object? body) {
    if (body is Map<String, dynamic>) {
      final fields = body['fieldErrors'];
      return ApiException(
        body['message'] as String? ?? 'Lỗi máy chủ ($statusCode)',
        statusCode: statusCode,
        code: body['code'] as String?,
        fieldErrors: fields is Map
            ? fields.map((k, v) => MapEntry(k as String, v.toString()))
            : const {},
      );
    }
    return ApiException('Backend trả mã $statusCode', statusCode: statusCode);
  }

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

/// Không tới được máy chủ (mất mạng, timeout). Khác lỗi do backend trả về:
/// không được coi là phiên đăng nhập hết hạn.
class NetworkException implements Exception {
  const NetworkException();

  @override
  String toString() => 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
}

class ApiClient {
  ApiClient(this._client);

  final http.Client _client;

  Future<Map<String, dynamic>> getJson(String path) async =>
      (await request('GET', path))!;

  /// Trả body JSON (null nếu 204). Không tự thử lại; việc đó do lớp gọi quyết định.
  Future<Map<String, dynamic>?> request(
    String method,
    String path, {
    Object? body,
    String? accessToken,
  }) async {
    final req = http.Request(method, Uri.parse('$apiBaseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    if (accessToken != null) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }

    final http.Response response;
    try {
      response = await _client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(apiTimeout);
    } on TimeoutException {
      throw const NetworkException();
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    final text = utf8.decode(response.bodyBytes);
    final Object? json = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json as Map<String, dynamic>?;
    }
    throw ApiException.fromResponse(response.statusCode, json);
  }
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(httpClientProvider)),
);
