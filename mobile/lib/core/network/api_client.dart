import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._client);

  final http.Client _client;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl$path'))
        .timeout(apiTimeout);
    if (response.statusCode != 200) {
      throw ApiException('Backend trả mã ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiClient(client);
});
