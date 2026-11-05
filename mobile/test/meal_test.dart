import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format/date_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/nutrition/food/data/food_api.dart';
import 'package:mobile/features/nutrition/food/data/food_models.dart';
import 'package:mobile/features/nutrition/meal/application/meal_plan_controller.dart';
import 'package:mobile/features/nutrition/meal/data/meal_api.dart';
import 'package:mobile/features/nutrition/meal/data/meal_models.dart';
import 'package:mobile/features/nutrition/meal/presentation/meal_plan_page.dart';

class _SignedIn extends AuthController {
  @override
  Future<AuthState> build() async => const Authenticated(
    AuthUser(
      id: 'u1',
      email: 'a@example.com',
      fullName: 'A',
      role: 'USER',
      hasHealthProfile: false,
    ),
  );
}

class _SignedOut extends AuthController {
  @override
  Future<AuthState> build() async => const Unauthenticated();
}

Map<String, dynamic> _n(num kcal, num p, num c, num f) => {
  'kcal': kcal,
  'proteinG': p,
  'carbsG': c,
  'fatG': f,
};

Map<String, dynamic> _entryJson(
  String id, {
  String meal = 'LUNCH',
  num servings = 1.5,
}) => {
  'id': id,
  'foodId': 'food-a',
  'foodName': 'Món A',
  'mealType': meal,
  'servingDescription': '1 phần ăn theo nguồn',
  'servingSize': null,
  'servingUnit': null,
  'servings': servings,
  'kcalPerServing': 200,
  'proteinPerServingG': 10,
  'carbsPerServingG': 30,
  'fatPerServingG': 4,
  'kcal': 200 * servings,
  'proteinG': 10 * servings,
  'carbsG': 30 * servings,
  'fatG': 4 * servings,
  'dataQuality': 'SOURCED',
  'createdAt': '2026-11-05T01:00:00Z',
};

MealPlan _plan(
  DateTime date, {
  List<Map<String, dynamic>> entries = const [],
  Map<String, dynamic>? targets,
}) {
  final kcal = entries.fold<num>(0, (s, e) => s + (e['kcal'] as num));
  return MealPlan.fromJson({
    'date': isoDate(date),
    'entryCount': entries.length,
    'meals': {
      for (final t in MealType.values)
        t.code: entries.where((e) => e['mealType'] == t.code).toList(),
    },
    'mealTotals': {for (final t in MealType.values) t.code: _n(0, 0, 0, 0)},
    'totals': _n(kcal, 0, 0, 0),
    'targets': targets,
    'remaining': targets == null
        ? null
        : _n((targets['kcal'] as num) - kcal, 0, 0, 0),
    'targetsCalculatedAt': targets == null ? null : '2026-11-01T03:00:00Z',
  });
}

class _FakeMealApi implements MealApi {
  final gets = <String>[];
  final adds = <Map<String, Object?>>[];
  final updates = <Map<String, Object?>>[];

  /// Ngày (iso) → completer để điều khiển thứ tự response.
  final pending = <String, Completer<MealPlan>>{};
  final plans = <String, MealPlan>{};
  Object? failAdd;

  @override
  Future<MealPlan> get(DateTime date) {
    final key = isoDate(date);
    gets.add(key);
    final c = pending.remove(key);
    if (c != null) return c.future;
    return Future.value(plans[key] ?? _plan(date));
  }

  @override
  Future<MealPlan> add({
    required DateTime date,
    required MealType mealType,
    required String foodId,
    required double servings,
  }) async {
    adds.add({
      'date': isoDate(date),
      'mealType': mealType.code,
      'foodId': foodId,
      'servings': servings,
    });
    final error = failAdd;
    if (error != null) {
      failAdd = null;
      throw error;
    }
    final plan = _plan(
      date,
      entries: [_entryJson('e1', meal: mealType.code, servings: servings)],
    );
    plans[isoDate(date)] = plan;
    return plan;
  }

  @override
  Future<MealPlan> update(
    String entryId, {
    MealType? mealType,
    double? servings,
  }) async {
    updates.add({'id': entryId, 'mealType': mealType, 'servings': servings});
    return _plan(
      today(),
      entries: [_entryJson(entryId, servings: servings ?? 1.5)],
    );
  }

  @override
  Future<MealPlan> delete(String entryId) async => _plan(today());
}

class _FakeFoodApi implements FoodApi {
  @override
  Future<FoodPage> search(
    FoodQuery query, {
    required int page,
    int size = FoodApi.pageSize,
  }) async => FoodPage(
    items: [
      FoodSummary.fromJson({
        'id': 'food-a',
        'code': 'VPF-1',
        'name': 'Món A',
        'category': {'code': 'C', 'name': 'Danh mục'},
        'region': null,
        'servingDescription': '1 phần ăn theo nguồn',
        'servingSize': null,
        'servingUnit': null,
        'kcalPerServing': 200,
        'proteinPerServing': 10,
        'carbsPerServing': 30,
        'fatPerServing': 4,
        'dataQuality': 'SOURCED',
        'imageUrl': null,
      }),
    ],
    totalItems: 1,
    hasNext: false,
  );

  @override
  Future<FoodDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<FoodFilters> filters() async =>
      FoodFilters.fromJson({'categories': [], 'regions': []});
}

List<Override> _overrides(_FakeMealApi api, {bool signedIn = true}) => [
  authControllerProvider.overrideWith(
    signedIn ? _SignedIn.new : _SignedOut.new,
  ),
  mealApiProvider.overrideWithValue(api),
  foodApiProvider.overrideWithValue(_FakeFoodApi()),
];

Widget _app(_FakeMealApi api) => ProviderScope(
  overrides: _overrides(api),
  child: const MaterialApp(home: MealPlanPage()),
);

/// Màn đủ cao để thấy cả bốn bữa (ListView chỉ dựng phần đang hiện).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(ProviderContainer c) async {
  await c.read(authControllerProvider.future);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('Dữ liệu thực đơn', () {
    test('đọc response, targets null khi chưa có hồ sơ', () {
      final plan = _plan(
        DateTime.utc(2026, 11, 5),
        entries: [_entryJson('e1')],
      );
      expect(plan.date, DateTime.utc(2026, 11, 5));
      expect(plan.meals[MealType.lunch]!.single.servings, 1.5);
      expect(plan.meals[MealType.lunch]!.single.total.kcal, 300);
      expect(plan.meals[MealType.lunch]!.single.perServing.kcal, 200);
      expect(plan.meals[MealType.breakfast], isEmpty);
      expect(plan.targets, isNull);
      expect(plan.remaining, isNull);
    });

    test('khẩu phần: > 0, ≤ 20, tối đa 2 chữ số lẻ, nhận dấu phẩy', () {
      expect(parseServings('1,5'), 1.5);
      expect(parseServings('0.25'), 0.25);
      expect(parseServings('20'), 20);
      expect(parseServings(' 2 '), 2);
      for (final bad in [
        '0',
        '0,00',
        '20,01',
        '21',
        '1,234',
        '-1',
        'abc',
        '',
        '1e1',
      ]) {
        expect(parseServings(bad), isNull, reason: bad);
      }
      expect(previewKcal(1.5, 200), 300);
      expect(previewKcal(0.33, 314), 103.62);
    });
  });

  group('MealPlanController', () {
    test(
      'đổi ngày nhanh: response ngày cũ về muộn không ghi đè ngày mới',
      () async {
        final api = _FakeMealApi();
        final c = ProviderContainer(overrides: _overrides(api));
        addTearDown(c.dispose);
        c.listen(mealPlanProvider, (_, _) {});
        await _settle(c);

        final d1 = addDays(today(), -1);
        final d2 = addDays(today(), -2);
        final slow = api.pending[isoDate(d1)] = Completer();
        final fast = api.pending[isoDate(d2)] = Completer();
        final controller = c.read(mealPlanProvider.notifier);
        controller.setDate(d1);
        controller.setDate(d2);
        fast.complete(_plan(d2));
        await _settle(c);
        slow.complete(_plan(d1, entries: [_entryJson('old')]));
        await _settle(c);

        final state = c.read(mealPlanProvider);
        expect(state.date, d2);
        expect(state.plan!.date, d2);
        expect(state.plan!.entryCount, 0);
      },
    );

    test('kết quả ghi của ngày khác không thay thực đơn đang xem', () async {
      final api = _FakeMealApi();
      final c = ProviderContainer(overrides: _overrides(api));
      addTearDown(c.dispose);
      c.listen(mealPlanProvider, (_, _) {});
      await _settle(c);
      final controller = c.read(mealPlanProvider.notifier);

      final yesterday = addDays(today(), -1);
      await controller.add(
        date: yesterday,
        mealType: MealType.lunch,
        foodId: 'food-a',
        servings: 1,
      );
      expect(c.read(mealPlanProvider).date, today());
      expect(c.read(mealPlanProvider).plan!.entryCount, 0);
      expect(api.adds.single['date'], isoDate(yesterday));
    });

    test('chưa đăng nhập: không gọi API, không có dữ liệu cũ', () async {
      final api = _FakeMealApi();
      final c = ProviderContainer(overrides: _overrides(api, signedIn: false));
      addTearDown(c.dispose);
      c.listen(mealPlanProvider, (_, _) {});
      await _settle(c);
      final state = c.read(mealPlanProvider);
      expect(state.plan, isNull);
      expect(state.error, isA<SessionExpiredException>());
      expect(api.gets, isEmpty);
    });

    test('canWrite: tối đa 7 ngày tới', () async {
      final api = _FakeMealApi();
      final c = ProviderContainer(overrides: _overrides(api));
      addTearDown(c.dispose);
      final controller = c.read(mealPlanProvider.notifier);
      expect(controller.canWrite(addDays(today(), 7)), isTrue);
      expect(controller.canWrite(addDays(today(), 8)), isFalse);
      expect(controller.canWrite(addDays(today(), -400)), isTrue);
    });
  });

  group('Màn thực đơn', () {
    testWidgets('chưa có mục tiêu: không hiện 0 kcal như mục tiêu thật', (
      tester,
    ) async {
      _tall(tester);
      final api = _FakeMealApi();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.text('Đã ăn 0 kcal'), findsOneWidget);
      expect(find.textContaining('Chưa có mục tiêu'), findsOneWidget);
      expect(find.byKey(const Key('meal-remaining')), findsNothing);
      for (final t in MealType.values) {
        expect(find.text(t.label), findsOneWidget);
      }
    });

    testWidgets('vượt mục tiêu: hiện lượng vượt, ghi rõ mục tiêu hiện tại', (
      tester,
    ) async {
      final api = _FakeMealApi();
      api.plans[isoDate(today())] = _plan(
        today(),
        entries: [_entryJson('e1', servings: 10)],
        targets: _n(1800, 100, 200, 60),
      );
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.text('Đã ăn 2.000 kcal / 1.800 kcal'), findsOneWidget);
      expect(find.text('Vượt 200 kcal so với mục tiêu'), findsOneWidget);
      expect(find.textContaining('So với mục tiêu hiện tại'), findsOneWidget);
    });

    testWidgets('thêm món: chọn món, nhập 1,5 phần, gửi đúng một lần', (
      tester,
    ) async {
      _tall(tester);
      final api = _FakeMealApi();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('meal-add-LUNCH')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn món'), findsOneWidget);
      await tester.tap(find.byKey(const Key('food-food-a')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('meal-servings')), '1,5');
      await tester.pump();
      expect(find.text('Xem trước: 300 kcal'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meal-submit')));
      await tester.pumpAndSettle();

      expect(api.adds, hasLength(1));
      expect(api.adds.single['servings'], 1.5);
      expect(api.adds.single['mealType'], 'LUNCH');
      expect(api.adds.single['date'], isoDate(today()));
      expect(find.byKey(const Key('meal-submit')), findsNothing);
      expect(find.byKey(const Key('meal-entry-e1')), findsOneWidget);
      expect(find.text('Đã ăn 300 kcal'), findsOneWidget);
    });

    testWidgets('mất mạng khi thêm: giữ form, báo kiểm tra, tải lại thực đơn', (
      tester,
    ) async {
      final api = _FakeMealApi()..failAdd = const NetworkException();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      final getsBefore = api.gets.length;

      await tester.tap(find.byKey(const Key('meal-add-DINNER')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-food-a')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('meal-servings')), '2');
      await tester.tap(find.byKey(const Key('meal-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('meal-entry-error')), findsOneWidget);
      expect(find.textContaining('kiểm tra trước khi gửi lại'), findsOneWidget);
      expect(find.byKey(const Key('meal-submit')), findsOneWidget);
      expect(api.gets.length, greaterThan(getsBefore));
      expect(api.adds, hasLength(1));
    });

    testWidgets('khẩu phần sai: nút lưu bị khóa, không gửi', (tester) async {
      _tall(tester);
      final api = _FakeMealApi();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meal-add-SNACK')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-food-a')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('meal-servings')), '0');
      await tester.pump();
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('meal-submit')),
      );
      expect(button.onPressed, isNull);
      expect(api.adds, isEmpty);
    });

    testWidgets('sửa mục: chỉ gửi số phần đã đổi', (tester) async {
      final api = _FakeMealApi();
      api.plans[isoDate(today())] = _plan(today(), entries: [_entryJson('e1')]);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('meal-entry-e1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('meal-servings')), '1');
      await tester.tap(find.byKey(const Key('meal-submit')));
      await tester.pumpAndSettle();

      expect(api.updates.single, {
        'id': 'e1',
        'mealType': null,
        'servings': 1.0,
      });
      expect(find.byKey(const Key('meal-submit')), findsNothing);
    });
  });
}
