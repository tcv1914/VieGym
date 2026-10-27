import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../data/health_api.dart';
import '../data/health_models.dart';

/// Hồ sơ của user đang đăng nhập; null = chưa có. Phụ thuộc trạng thái đăng nhập nên
/// đổi tài khoản hay logout là tính lại, không còn hồ sơ của tài khoản trước.
final healthProfileProvider = FutureProvider.autoDispose<HealthProfileData?>(
  (ref) {
    final auth = ref.watch(authControllerProvider).value;
    if (auth is! Authenticated) {
      throw const SessionExpiredException();
    }
    return ref.read(healthApiProvider).fetch();
  },
  retry: (retryCount, error) => null,
);
