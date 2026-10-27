import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chỉ refresh token được lưu bền (secure storage). Access token và mật khẩu không ghi xuống máy.
abstract class TokenStore {
  Future<String?> readRefresh();
  Future<void> saveRefresh(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<void> saveRefresh(String token) =>
      _storage.write(key: _refreshKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _refreshKey);
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
