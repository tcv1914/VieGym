import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.refresh]);

  String? refresh;
  bool failWrites = false;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveRefresh(String token) async {
    if (failWrites) throw Exception('keystore lỗi');
    refresh = token;
  }

  @override
  Future<void> clear() async => refresh = null;
}

/// Backend giả: access hợp lệ là "access-N" mới nhất; refresh "refresh-N" dùng một lần.
class FakeBackend {
  int generation = 1;
  int refreshCalls = 0;
  int meCalls = 0;
  int? refreshStatus;
  bool offline = false;

  http.Response _json(int status, Object? body) => http.Response(
      body == null ? '' : jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

  Map<String, Object> _tokens() => {
        'tokenType': 'Bearer',
        'accessToken': 'access-$generation',
        'accessTokenExpiresIn': 900,
        'refreshToken': 'refresh-$generation',
        'user': _user,
      };

  static const _user = {
    'id': 'u1',
    'email': 'a@example.com',
    'fullName': 'A',
    'role': 'USER',
    'hasHealthProfile': false,
  };

  late final client = MockClient((request) async {
    if (offline) throw http.ClientException('offline');
    final path = request.url.path;
    if (path == '/api/v1/auth/refresh') {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshStatus != null) {
        return _json(refreshStatus!, {'code': 'INVALID_REFRESH_TOKEN', 'message': 'hết hạn'});
      }
      final sent = (jsonDecode(request.body) as Map)['refreshToken'];
      if (sent != 'refresh-$generation') {
        return _json(401, {'code': 'INVALID_REFRESH_TOKEN', 'message': 'đã dùng'});
      }
      generation++;
      return _json(200, _tokens());
    }
    if (path == '/api/v1/auth/login') return _json(200, _tokens());
    if (path == '/api/v1/auth/logout') return _json(204, null);
    if (path == '/api/v1/users/me') {
      meCalls++;
      if (request.headers['Authorization'] != 'Bearer access-$generation') {
        return _json(401, {'code': 'UNAUTHORIZED', 'message': 'hết hạn'});
      }
      return _json(200, _user);
    }
    return _json(404, null);
  });
}

AuthRepository _repository(FakeBackend backend, TokenStore store) {
  final api = ApiClient(backend.client);
  return AuthRepository(AuthApi(api), api, store);
}

void main() {
  test('Nhiều request gặp access hết hạn cùng lúc chỉ refresh một lần', () async {
    final backend = FakeBackend();
    final store = MemoryTokenStore();
    final repo = _repository(backend, store);
    await repo.login('a@example.com', 'Matkhau123');
    backend.generation++; // access-1 hết hạn; backend chỉ nhận access mới.
    store.refresh = 'refresh-2';

    final users = await Future.wait([repo.me(), repo.me(), repo.me()]);

    expect(users.map((u) => u.id), everyElement('u1'));
    expect(backend.refreshCalls, 1);
    expect(store.refresh, 'refresh-3');
  });

  test('Mở lại app: refresh token đã lưu khôi phục phiên', () async {
    final backend = FakeBackend();
    final store = MemoryTokenStore('refresh-1');
    final user = await _repository(backend, store).restore();

    expect(user?.email, 'a@example.com');
    expect(store.refresh, 'refresh-2');
  });

  test('Mất mạng khi khôi phục phiên không xóa refresh token', () async {
    final backend = FakeBackend()..offline = true;
    final store = MemoryTokenStore('refresh-1');

    await expectLater(_repository(backend, store).restore(),
        throwsA(isA<NetworkException>()));
    expect(store.refresh, 'refresh-1');
  });

  test('Máy chủ lỗi 5xx khi refresh không xóa refresh token', () async {
    final backend = FakeBackend()..refreshStatus = 503;
    final store = MemoryTokenStore('refresh-1');

    await expectLater(_repository(backend, store).restore(),
        throwsA(isA<ApiException>()));
    expect(store.refresh, 'refresh-1');
  });

  test('Refresh bị từ chối 401: xóa phiên và báo hết hạn', () async {
    final backend = FakeBackend()..refreshStatus = 401;
    final store = MemoryTokenStore('refresh-1');
    final repo = _repository(backend, store);
    String? expired;
    repo.onSessionExpired = (message) => expired = message;

    await expectLater(repo.restore(), throwsA(isA<SessionExpiredException>()));
    expect(store.refresh, isNull);
    expect(expired, isNotNull);
  });

  test('Không lưu được refresh mới thì buộc đăng nhập lại', () async {
    final backend = FakeBackend();
    final store = MemoryTokenStore('refresh-1')..failWrites = true;

    await expectLater(_repository(backend, store).restore(),
        throwsA(isA<SessionExpiredException>()));
    expect(store.refresh, isNull);
    expect(backend.meCalls, 0);
  });

  test('Logout khi mất mạng vẫn xóa phiên local nhưng báo chưa xác nhận', () async {
    final backend = FakeBackend();
    final store = MemoryTokenStore();
    final repo = _repository(backend, store);
    await repo.login('a@example.com', 'Matkhau123');
    backend.offline = true;

    expect(await repo.logout(), isFalse);
    expect(store.refresh, isNull);
  });

  test('Logout thành công gửi refresh hiện tại', () async {
    final backend = FakeBackend();
    final store = MemoryTokenStore();
    final repo = _repository(backend, store);
    await repo.login('a@example.com', 'Matkhau123');

    expect(await repo.logout(), isTrue);
    expect(store.refresh, isNull);
  });
}
