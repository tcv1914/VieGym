import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_models.dart';
import '../data/schedule_api.dart';
import '../data/schedule_models.dart';

ScheduleApi _api(Ref ref) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth is! Authenticated) throw const SessionExpiredException();
  return ref.read(scheduleApiProvider);
}

/// Lịch tuần bắt đầu từ [monday] (thứ Hai–Chủ nhật). Phụ thuộc phiên đăng nhập.
final weekSchedulesProvider = FutureProvider.autoDispose
    .family<ScheduleList, DateTime>(
      (ref, monday) => _api(ref).range(monday, addDays(monday, 6)),
      retry: (retryCount, error) => null,
    );

final scheduleDetailProvider = FutureProvider.autoDispose
    .family<ScheduleDetail, String>(
      (ref, id) => _api(ref).detail(id),
      retry: (retryCount, error) => null,
    );
