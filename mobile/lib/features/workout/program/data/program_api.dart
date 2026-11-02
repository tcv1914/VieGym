import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import 'program_models.dart';

/// /api/v1/workout-programs (docs/05 §6). Không tự gửi lại POST/PUT khi lỗi mạng:
/// server có thể đã ghi, gửi lại sẽ tạo bản trùng (docs/16 §6).
class ProgramApi {
  ProgramApi(this._auth);

  final AuthRepository _auth;

  static const _base = '/api/v1/workout-programs';

  Future<List<ProgramSummary>> list({bool templates = false}) async {
    final json = (await _auth.authorizedRequest(
      'GET',
      '$_base?scope=${templates ? 'templates' : 'mine'}',
    ))!;
    return (json['items'] as List)
        .map((e) => ProgramSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProgramDetail> detail(String id) async => ProgramDetail.fromJson(
    (await _auth.authorizedRequest('GET', '$_base/${Uri.encodeComponent(id)}'))!,
  );

  Future<ProgramDetail> copyTemplate(String templateId) async =>
      ProgramDetail.fromJson(
        (await _auth.authorizedRequest(
          'POST',
          _base,
          body: {'templateId': templateId},
        ))!,
      );

  /// [body] từ `ProgramDraft.toJson()`.
  Future<ProgramDetail> create(Map<String, dynamic> body) async =>
      ProgramDetail.fromJson(
        (await _auth.authorizedRequest('POST', _base, body: body))!,
      );

  Future<ProgramDetail> update(String id, Map<String, dynamic> body) async =>
      ProgramDetail.fromJson(
        (await _auth.authorizedRequest(
          'PUT',
          '$_base/${Uri.encodeComponent(id)}',
          body: body,
        ))!,
      );

  Future<ProgramDetail> activate(String id) async => ProgramDetail.fromJson(
    (await _auth.authorizedRequest(
      'POST',
      '$_base/${Uri.encodeComponent(id)}/activate',
    ))!,
  );
}

final programApiProvider = Provider<ProgramApi>(
  (ref) => ProgramApi(ref.watch(authRepositoryProvider)),
);
