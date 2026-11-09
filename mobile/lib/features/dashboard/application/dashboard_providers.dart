import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../data/dashboard_api.dart';
import '../data/dashboard_models.dart';

/// Ngày đang xem trên Tổng quan. Đổi tài khoản/đăng xuất → về hôm nay.
class DashboardDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    ref.watch(authControllerProvider);
    return today();
  }

  void set(DateTime date) => state = dateOnly(date);
}

final dashboardDateProvider =
    NotifierProvider.autoDispose<DashboardDate, DateTime>(DashboardDate.new);

/// Khóa gồm cả user và ngày: dữ liệu tài khoản trước không bao giờ là "giá trị cũ" của tài
/// khoản sau, và response của ngày khác không ghi nhầm vào ngày đang xem.
typedef DashboardKey = ({String userId, DateTime date});

/// Các màn ghi dữ liệu (thực đơn, ghi buổi, lịch, hồ sơ) gọi `ref.invalidate(dashboardProvider)`
/// để mọi ngày đã tải được tính lại. Khi tải lại lỗi, AsyncValue vẫn giữ số cũ → UI báo "dữ liệu cũ".
final dashboardProvider = FutureProvider.autoDispose
    .family<Dashboard, DashboardKey>((ref, key) {
      final auth = ref.watch(authControllerProvider).value;
      if (auth is! Authenticated || auth.user.id != key.userId) {
        throw const SessionExpiredException();
      }
      return ref.read(dashboardApiProvider).get(key.date);
    }, retry: (retryCount, error) => null);
