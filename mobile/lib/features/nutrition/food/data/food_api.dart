import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import 'food_models.dart';

/// /api/v1/foods, /food-filters (docs/05 §9). Dữ liệu tra trong PostgreSQL nội bộ.
class FoodApi {
  FoodApi(this._auth);

  final AuthRepository _auth;

  static const pageSize = 20;

  Future<FoodPage> search(
    FoodQuery query, {
    required int page,
    int size = pageSize,
  }) async {
    final path = Uri(
      path: '/api/v1/foods',
      queryParameters: query.toQueryParameters(page: page, size: size),
    ).toString();
    return FoodPage.fromJson((await _auth.authorizedRequest('GET', path))!);
  }

  Future<FoodDetail> detail(String id) async => FoodDetail.fromJson(
    (await _auth.authorizedRequest(
      'GET',
      '/api/v1/foods/${Uri.encodeComponent(id)}',
    ))!,
  );

  Future<FoodFilters> filters() async => FoodFilters.fromJson(
    (await _auth.authorizedRequest('GET', '/api/v1/food-filters'))!,
  );
}

final foodApiProvider = Provider<FoodApi>(
  (ref) => FoodApi(ref.watch(authRepositoryProvider)),
);
