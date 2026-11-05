import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../auth/data/auth_repository.dart';
import 'meal_models.dart';

/// /api/v1/meal-plans (docs/05 §10). Mọi thao tác ghi trả cả thực đơn ngày sau khi ghi.
class MealApi {
  MealApi(this._auth);

  final AuthRepository _auth;

  static const _base = '/api/v1/meal-plans';

  Future<MealPlan> get(DateTime date) async => MealPlan.fromJson(
    (await _auth.authorizedRequest('GET', '$_base?date=${isoDate(date)}'))!,
  );

  /// Không tự gửi lại: mỗi lần thêm là một mục riêng (NUT-BR08).
  Future<MealPlan> add({
    required DateTime date,
    required MealType mealType,
    required String foodId,
    required double servings,
  }) async => MealPlan.fromJson(
    (await _auth.authorizedRequest(
      'POST',
      '$_base/entries',
      body: {
        'date': isoDate(date),
        'mealType': mealType.code,
        'foodId': foodId,
        'servings': servings,
      },
    ))!,
  );

  Future<MealPlan> update(
    String entryId, {
    MealType? mealType,
    double? servings,
  }) async => MealPlan.fromJson(
    (await _auth.authorizedRequest(
      'PUT',
      '$_base/entries/${Uri.encodeComponent(entryId)}',
      body: {'mealType': ?mealType?.code, 'servings': ?servings},
    ))!,
  );

  Future<MealPlan> delete(String entryId) async => MealPlan.fromJson(
    (await _auth.authorizedRequest(
      'DELETE',
      '$_base/entries/${Uri.encodeComponent(entryId)}',
    ))!,
  );
}

final mealApiProvider = Provider<MealApi>(
  (ref) => MealApi(ref.watch(authRepositoryProvider)),
);
