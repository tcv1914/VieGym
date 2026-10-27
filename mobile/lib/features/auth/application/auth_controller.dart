import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_models.dart';
import '../data/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.message});

  /// Lý do quay về màn đăng nhập (phiên hết hạn, logout chưa xác nhận...).
  final String? message;
}

class Authenticated extends AuthState {
  const Authenticated(this.user);

  final AuthUser user;
}

/// Khôi phục phiên thất bại vì mạng/máy chủ; refresh token vẫn còn, cho thử lại.
class RestoreFailed extends AuthState {
  const RestoreFailed(this.message);

  final String message;
}

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    _repository.onSessionExpired = (message) {
      // Chỉ đổi khi đang đăng nhập; lúc khôi phục, build() tự trả kết quả.
      if (state.value is Authenticated) {
        state = AsyncData(Unauthenticated(message: message));
      }
    };
    try {
      final user = await _repository.restore();
      return user == null ? const Unauthenticated() : Authenticated(user);
    } on SessionExpiredException catch (e) {
      return Unauthenticated(message: e.message);
    } catch (e) {
      return RestoreFailed(e.toString());
    }
  }

  /// Ném lỗi cho màn đăng nhập hiển thị; trạng thái chỉ đổi khi thành công.
  Future<void> login(String email, String password) async {
    final user = await _repository.login(email.trim(), password);
    state = AsyncData(Authenticated(user));
  }

  Future<void> logout() async {
    final confirmed = await _repository.logout();
    state = AsyncData(Unauthenticated(
      message: confirmed
          ? null
          : 'Đã đăng xuất trên máy này, nhưng chưa xác nhận được với máy chủ.',
    ));
  }

  void retryRestore() => ref.invalidateSelf();
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

/// Dữ liệu cá nhân phụ thuộc người dùng hiện tại: đổi tài khoản hay logout là tính lại,
/// không còn dữ liệu của tài khoản trước.
final meProvider = FutureProvider.autoDispose<AuthUser>(
  (ref) {
    final auth = ref.watch(authControllerProvider).value;
    if (auth is! Authenticated) {
      throw const SessionExpiredException();
    }
    return ref.read(authRepositoryProvider).me();
  },
  retry: (retryCount, error) => null,
);
