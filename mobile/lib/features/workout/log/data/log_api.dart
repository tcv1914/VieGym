import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../auth/data/auth_repository.dart';
import 'log_models.dart';

/// /api/v1/workout-logs (docs/05 §8). Đây là cách duy nhất để lịch thành COMPLETED (BR-W04).
class LogApi {
  LogApi(this._auth);

  final AuthRepository _auth;

  static const _base = '/api/v1/workout-logs';

  /// Không tự gửi lại. Gửi lặp cho cùng lịch → 409 WORKOUT_ALREADY_LOGGED kèm `workoutLogId`.
  Future<LogDetail> create(Map<String, dynamic> payload) async =>
      LogDetail.fromJson(
        (await _auth.authorizedRequest('POST', _base, body: payload))!,
      );

  Future<LogDetail> detail(String id) async => LogDetail.fromJson(
    (await _auth.authorizedRequest(
      'GET',
      '$_base/${Uri.encodeComponent(id)}',
    ))!,
  );

  /// Khoảng đóng [from, to] theo ngày tập; null = không giới hạn.
  Future<LogPage> list({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final path = Uri(
      path: _base,
      queryParameters: {
        'from': ?(from == null ? null : isoDate(from)),
        'to': ?(to == null ? null : isoDate(to)),
        'page': '$page',
        'size': '$size',
      },
    ).toString();
    return LogPage.fromJson((await _auth.authorizedRequest('GET', path))!);
  }
}

final logApiProvider = Provider<LogApi>(
  (ref) => LogApi(ref.watch(authRepositoryProvider)),
);
