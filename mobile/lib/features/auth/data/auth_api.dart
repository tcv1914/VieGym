import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_models.dart';

/// Các endpoint /auth/*; không giữ trạng thái.
class AuthApi {
  AuthApi(this._api);

  final ApiClient _api;

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _api.request('POST', '/api/v1/auth/register', body: {
        'email': email,
        'password': password,
        'fullName': fullName,
      });

  Future<TokenPair> login(String email, String password) async =>
      TokenPair.fromJson((await _api.request('POST', '/api/v1/auth/login',
          body: {'email': email, 'password': password}))!);

  Future<TokenPair> refresh(String refreshToken) async =>
      TokenPair.fromJson((await _api.request('POST', '/api/v1/auth/refresh',
          body: {'refreshToken': refreshToken}))!);

  Future<void> logout(String refreshToken) => _api.request(
      'POST', '/api/v1/auth/logout',
      body: {'refreshToken': refreshToken});

  /// Luôn 204 dù email có tồn tại hay không (BR-A06).
  Future<void> forgotPassword(String email) => _api.request(
      'POST', '/api/v1/auth/forgot-password',
      body: {'email': email});

  /// Không cấp token: đặt lại xong phải đăng nhập lại.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _api.request('POST', '/api/v1/auth/reset-password', body: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
}

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));
