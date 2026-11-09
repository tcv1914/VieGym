import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../auth/data/auth_repository.dart';
import 'dashboard_models.dart';

/// GET /api/v1/dashboard (docs/05 §11). Không gửi userId: server lấy từ token.
class DashboardApi {
  DashboardApi(this._auth);

  final AuthRepository _auth;

  Future<Dashboard> get(DateTime date) async => Dashboard.fromJson(
    (await _auth.authorizedRequest(
      'GET',
      '/api/v1/dashboard?date=${isoDate(date)}',
    ))!,
  );
}

final dashboardApiProvider = Provider<DashboardApi>(
  (ref) => DashboardApi(ref.watch(authRepositoryProvider)),
);
