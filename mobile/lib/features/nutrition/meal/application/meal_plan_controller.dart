import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_models.dart';
import '../data/meal_api.dart';
import '../data/meal_models.dart';

/// BR-N07: ghi được ngày quá khứ và tối đa 7 ngày tới.
const maxDaysAhead = 7;
final firstPlanDate = DateTime.utc(2000);

class MealPlanState {
  const MealPlanState({
    required this.date,
    this.plan,
    this.loading = true,
    this.error,
  });

  final DateTime date;

  /// Luôn là thực đơn của [date]; null khi đang tải lần đầu hoặc lỗi.
  final MealPlan? plan;
  final bool loading;
  final Object? error;
}

/// Thực đơn của ngày đang chọn. Mỗi lần đổi ngày tăng [_generation]; response của ngày cũ về
/// muộn bị bỏ qua (A11). Đổi tài khoản/đăng xuất → build lại, không còn dữ liệu người trước.
class MealPlanController extends Notifier<MealPlanState> {
  int _generation = 0;

  MealApi get _api => ref.read(mealApiProvider);

  @override
  MealPlanState build() {
    final auth = ref.watch(authControllerProvider).value;
    _generation++;
    final day = today();
    if (auth is! Authenticated) {
      return MealPlanState(
        date: day,
        loading: false,
        error: const SessionExpiredException(),
      );
    }
    final generation = _generation;
    Future.microtask(() => _load(generation, day));
    return MealPlanState(date: day);
  }

  bool canWrite(DateTime date) =>
      !dateOnly(date).isAfter(addDays(today(), maxDaysAhead));

  void setDate(DateTime date) {
    final day = dateOnly(date);
    if (day == state.date && state.error == null) return;
    final generation = ++_generation;
    state = MealPlanState(date: day);
    _load(generation, day);
  }

  /// Giữ thực đơn đang hiện trong lúc tải lại (kéo để làm mới).
  Future<void> refresh() {
    final generation = ++_generation;
    final day = state.date;
    state = MealPlanState(date: day, plan: state.plan);
    return _load(generation, day);
  }

  /// Lỗi ném cho form xử lý (giữ dữ liệu đã nhập). Không tự gửi lại.
  Future<void> add({
    required MealType mealType,
    required String foodId,
    required double servings,
    DateTime? date,
  }) async => _apply(
    await _api.add(
      date: date ?? state.date,
      mealType: mealType,
      foodId: foodId,
      servings: servings,
    ),
  );

  Future<void> updateEntry(
    String entryId, {
    MealType? mealType,
    double? servings,
  }) async => _apply(
    await _api.update(entryId, mealType: mealType, servings: servings),
  );

  Future<void> deleteEntry(String entryId) async =>
      _apply(await _api.delete(entryId));

  /// Kết quả ghi của ngày khác (người dùng đã đổi ngày khi đang gửi) không ghi đè ngày đang xem.
  void _apply(MealPlan plan) {
    if (!ref.mounted || plan.date != state.date) return;
    ++_generation;
    state = MealPlanState(date: plan.date, plan: plan, loading: false);
  }

  Future<void> _load(int generation, DateTime day) async {
    try {
      final plan = await _api.get(day);
      if (!_isCurrent(generation)) return;
      state = MealPlanState(date: day, plan: plan, loading: false);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      state = MealPlanState(
        date: day,
        plan: state.plan,
        loading: false,
        error: e,
      );
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final mealPlanProvider =
    NotifierProvider.autoDispose<MealPlanController, MealPlanState>(
      MealPlanController.new,
    );
