import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'exercise_models.dart';

/// Thư viện bài tập qua [AuthRepository] để có Bearer + refresh của ngày 4.
class ExerciseApi {
  ExerciseApi(this._auth);

  final AuthRepository _auth;

  static const pageSize = 20;

  /// Query string do [Uri] encode, không nối chuỗi tay (keyword có dấu, &, %...).
  Future<ExercisePage> search(ExerciseQuery query, {required int page}) async {
    final path = Uri(
      path: '/api/v1/exercises',
      queryParameters: query.toQueryParameters(page: page, size: pageSize),
    ).toString();
    return ExercisePage.fromJson((await _auth.authorizedRequest('GET', path))!);
  }

  Future<ExerciseDetail> detail(String id) async => ExerciseDetail.fromJson(
    (await _auth.authorizedRequest(
      'GET',
      '/api/v1/exercises/${Uri.encodeComponent(id)}',
    ))!,
  );

  Future<ExerciseFilters> filters() async => ExerciseFilters.fromJson(
    (await _auth.authorizedRequest('GET', '/api/v1/exercise-filters'))!,
  );
}

final exerciseApiProvider = Provider<ExerciseApi>(
  (ref) => ExerciseApi(ref.watch(authRepositoryProvider)),
);
