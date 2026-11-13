import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../auth/data/auth_repository.dart';
import 'weight_models.dart';

/// /weight-logs (docs/05 §4). Sửa = gửi lại cùng ngày; backend ghi đè (BR-WL01).
class WeightApi {
  WeightApi(this._auth);

  final AuthRepository _auth;

  static const _path = '/api/v1/weight-logs';

  Future<List<WeightLog>> list(DateTime from, DateTime to) async {
    final body = await _auth.authorizedRequest(
        'GET', '$_path?from=${isoDate(from)}&to=${isoDate(to)}');
    return [
      for (final item in body!['items'] as List)
        WeightLog.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<WeightLog> save({
    required DateTime logDate,
    required double weightKg,
    String? note,
  }) async =>
      WeightLog.fromJson((await _auth.authorizedRequest('POST', _path, body: {
        'logDate': isoDate(logDate),
        'weightKg': weightKg,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }))!);

  Future<void> delete(String id) =>
      _auth.authorizedRequest('DELETE', '$_path/$id');
}

final weightApiProvider =
    Provider<WeightApi>((ref) => WeightApi(ref.watch(authRepositoryProvider)));
