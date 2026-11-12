import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'auth_models.dart';
import 'token_store.dart';

/// Giữ access token trong bộ nhớ, refresh token trong [TokenStore], và gắn Bearer
/// cho mọi request riêng tư.
class AuthRepository {
  AuthRepository(this._authApi, this._api, this._store);

  final AuthApi _authApi;
  final ApiClient _api;
  final TokenStore _store;

  String? _accessToken;
  // Single-flight: mọi request gặp 401 cùng lúc chờ chung một lần refresh.
  Future<void>? _refreshing;

  /// Gọi khi backend từ chối refresh (phiên bị thu hồi, hết hạn, tài khoản khóa).
  void Function(String message)? onSessionExpired;

  Future<AuthUser> login(String email, String password) async {
    final pair = await _authApi.login(email, password);
    // Chỉ coi là đã đăng nhập sau khi refresh token đã ghi xong.
    await _store.saveRefresh(pair.refreshToken);
    _accessToken = pair.accessToken;
    return pair.user;
  }

  /// App mở lại: dùng refresh token đã lưu để lấy phiên mới. null = chưa đăng nhập.
  /// Lỗi mạng ném [NetworkException] và giữ nguyên refresh token để thử lại.
  Future<AuthUser?> restore() async {
    if (await _store.readRefresh() == null) return null;
    await _refreshShared();
    return me();
  }

  Future<AuthUser> me() async =>
      AuthUser.fromJson((await authorizedRequest('GET', '/api/v1/users/me'))!);

  /// Gặp 401 thì refresh một lần rồi gửi lại tối đa một lần. Backend trả 401 trước
  /// khi xử lý nghiệp vụ nên gửi lại không tạo bản ghi trùng.
  Future<Map<String, dynamic>?> authorizedRequest(
    String method,
    String path, {
    Object? body,
    Duration timeout = apiTimeout,
  }) async {
    if (_accessToken == null) await _refreshShared();
    final usedToken = _accessToken;
    try {
      return await _api.request(method, path,
          body: body, accessToken: usedToken, timeout: timeout);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
    }
    // Request khác có thể đã refresh xong trong lúc chờ; khi đó dùng luôn token mới.
    if (_accessToken == usedToken) await _refreshShared();
    try {
      return await _api.request(method, path,
          body: body, accessToken: _accessToken, timeout: timeout);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _expire(const SessionExpiredException());
      }
      rethrow;
    }
  }

  /// Trả false nếu máy chủ chưa xác nhận thu hồi (mất mạng); phiên local vẫn bị xóa.
  Future<bool> logout() async {
    final refresh = await _store.readRefresh();
    var confirmed = true;
    if (refresh != null) {
      try {
        await _authApi.logout(refresh);
      } on NetworkException {
        confirmed = false;
      } on ApiException {
        confirmed = false;
      }
    }
    await _clearLocal();
    return confirmed;
  }

  Future<void> _refreshShared() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final refresh = await _store.readRefresh();
    if (refresh == null) {
      await _expire(const SessionExpiredException());
    }
    final TokenPair pair;
    try {
      pair = await _authApi.refresh(refresh);
    } on ApiException catch (e) {
      // 401 token không hợp lệ, 403 tài khoản khóa. 5xx: giữ refresh để thử lại.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _expire(SessionExpiredException(
            e.statusCode == 403 ? e.message : const SessionExpiredException().message));
      }
      rethrow;
    }
    try {
      await _store.saveRefresh(pair.refreshToken);
    } catch (_) {
      // Token cũ đã bị tiêu thụ ở backend; không thể tiếp tục dùng nó.
      await _expire(const SessionExpiredException(
          'Không lưu được phiên đăng nhập trên máy, vui lòng đăng nhập lại.'));
    }
    _accessToken = pair.accessToken;
  }

  Future<Never> _expire(SessionExpiredException error) async {
    await _clearLocal();
    onSessionExpired?.call(error.message);
    throw error;
  }

  Future<void> _clearLocal() async {
    _accessToken = null;
    try {
      await _store.clear();
    } catch (_) {
      // Không xóa được thì refresh cũ cũng đã bị thu hồi/tiêu thụ ở backend.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(authApiProvider),
      ref.watch(apiClientProvider),
      ref.watch(tokenStoreProvider),
    ));
