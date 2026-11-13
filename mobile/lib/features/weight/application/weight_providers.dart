import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../data/weight_api.dart';
import '../data/weight_models.dart';

/// Khoảng xem biểu đồ, luôn kết thúc hôm nay. 365 ngày nằm trong giới hạn 366 của backend.
enum WeightRange {
  days30(30, '30 ngày'),
  days90(90, '90 ngày'),
  year(365, '1 năm');

  const WeightRange(this.days, this.label);

  final int days;
  final String label;

  DateTime get from => addDays(today(), -(days - 1));
}

class WeightRangeNotifier extends Notifier<WeightRange> {
  @override
  WeightRange build() => WeightRange.days90;

  void set(WeightRange range) => state = range;
}

final weightRangeProvider =
    NotifierProvider.autoDispose<WeightRangeNotifier, WeightRange>(
        WeightRangeNotifier.new);

/// Khóa theo user để không bao giờ hiện cân nặng của tài khoản trước. Màn ghi/xóa gọi
/// `ref.invalidate(weightLogsProvider)`.
typedef WeightLogsKey = ({String userId, WeightRange range});

final weightLogsProvider = FutureProvider.autoDispose
    .family<List<WeightLog>, WeightLogsKey>((ref, key) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth is! Authenticated || auth.user.id != key.userId) {
    throw const SessionExpiredException();
  }
  return ref.read(weightApiProvider).list(key.range.from, today());
}, retry: (retryCount, error) => null);
