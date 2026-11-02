import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../auth/data/auth_repository.dart';
import 'schedule_models.dart';

/// /api/v1/workout-schedules (docs/05 §7). Không có API hoàn thành buổi:
/// COMPLETED chỉ qua ghi nhận buổi tập (ngày 8, BR-W04).
class ScheduleApi {
  ScheduleApi(this._auth);

  final AuthRepository _auth;

  static const _base = '/api/v1/workout-schedules';

  /// Khoảng đóng [from, to] theo ngày.
  Future<ScheduleList> range(DateTime from, DateTime to) async {
    final path = Uri(
      path: _base,
      queryParameters: {'from': isoDate(from), 'to': isoDate(to)},
    ).toString();
    return ScheduleList.fromJson((await _auth.authorizedRequest('GET', path))!);
  }

  Future<ScheduleDetail> detail(String id) async => ScheduleDetail.fromJson(
    (await _auth.authorizedRequest('GET', '$_base/${Uri.encodeComponent(id)}'))!,
  );

  Future<ScheduleDetail> create({
    required String workoutDayId,
    required DateTime date,
    String? startTime,
    String? note,
  }) async => ScheduleDetail.fromJson(
    (await _auth.authorizedRequest(
      'POST',
      _base,
      body: {
        'workoutDayId': workoutDayId,
        'scheduledDate': isoDate(date),
        'startTime': startTime,
        'note': note,
      },
    ))!,
  );

  /// Thay ngày/giờ/ghi chú (status SCHEDULED) hoặc hủy (CANCELLED).
  Future<ScheduleDetail> update(
    String id, {
    required DateTime date,
    String? startTime,
    String? note,
    required ScheduleStatus status,
  }) async => ScheduleDetail.fromJson(
    (await _auth.authorizedRequest(
      'PUT',
      '$_base/${Uri.encodeComponent(id)}',
      body: {
        'scheduledDate': isoDate(date),
        'startTime': startTime,
        'note': note,
        'status': status.code,
      },
    ))!,
  );
}

final scheduleApiProvider = Provider<ScheduleApi>(
  (ref) => ScheduleApi(ref.watch(authRepositoryProvider)),
);
