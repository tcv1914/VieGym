import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_models.dart';
import '../data/log_api.dart';
import '../data/log_models.dart';

/// Phụ thuộc phiên đăng nhập: đổi tài khoản thì tính lại, không còn dữ liệu người trước.
final logDetailProvider = FutureProvider.autoDispose.family<LogDetail, String>((
  ref,
  id,
) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth is! Authenticated) throw const SessionExpiredException();
  return ref.read(logApiProvider).detail(id);
}, retry: (retryCount, error) => null);

/// Tăng mỗi khi có log mới, để màn lịch sử đang mở tải lại từ đầu.
final logHistoryVersionProvider = NotifierProvider<_Counter, int>(_Counter.new);

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
