import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import 'health_models.dart';

/// /health-profile/me qua [AuthRepository] để có Bearer + refresh của ngày 4.
class HealthApi {
  HealthApi(this._auth);

  final AuthRepository _auth;

  static const _path = '/api/v1/health-profile/me';

  /// null = chưa có hồ sơ. Lỗi mạng/401/khác vẫn ném ra, không coi là "chưa có hồ sơ".
  Future<HealthProfileData?> fetch() async {
    try {
      return HealthProfileData.fromJson(
          (await _auth.authorizedRequest('GET', _path))!);
    } on ApiException catch (e) {
      if (e.statusCode == 404 && e.code == 'HEALTH_PROFILE_REQUIRED') {
        return null;
      }
      rethrow;
    }
  }

  Future<HealthProfileData> save(HealthProfileInput input) async =>
      HealthProfileData.fromJson(
          (await _auth.authorizedRequest('PUT', _path, body: input.toJson()))!);
}

final healthApiProvider =
    Provider<HealthApi>((ref) => HealthApi(ref.watch(authRepositoryProvider)));
