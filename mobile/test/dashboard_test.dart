import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/home_tab.dart';
import 'package:mobile/core/format/date_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:mobile/features/dashboard/data/dashboard_api.dart';
import 'package:mobile/features/dashboard/data/dashboard_models.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:mobile/features/nutrition/meal/application/meal_plan_controller.dart';
import 'package:mobile/features/nutrition/meal/data/meal_api.dart';
import 'package:mobile/features/nutrition/meal/data/meal_models.dart';

AuthUser _user(String id) => AuthUser(
  id: id,
  email: '$id@example.com',
  fullName: 'Minh',
  role: 'USER',
  hasHealthProfile: true,
);

/// Đăng nhập được đổi tài khoản giữa chừng (D07).
class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => Authenticated(_user('u1'));

  void switchTo(String id) => state = AsyncData(Authenticated(_user(id)));
}

Map<String, dynamic> _n(num kcal, num p, num c, num f) => {
  'kcal': kcal,
  'proteinG': p,
  'carbsG': c,
  'fatG': f,
};

Map<String, dynamic> _schedule(
  String id,
  DateTime date, {
  String status = 'SCHEDULED',
  String? logId,
}) => {
  'scheduleId': id,
  'scheduledDate': isoDate(date),
  'startTime': '18:00',
  'name': 'Buổi A',
  'programName': 'Full Body',
  'status': status,
  'workoutLogId': logId,
};

Map<String, dynamic> _json(
  DateTime date, {
  bool hasProfile = true,
  int entryCount = 2,
  Map<String, dynamic>? totals,
  Map<String, dynamic>? targets,
  Map<String, dynamic>? remaining,
  List<Map<String, dynamic>> today = const [],
  Map<String, dynamic>? next,
  int scheduled = 3,
  int completed = 1,
  int cancelled = 0,
}) {
  final monday = weekStart(date);
  return {
    'date': isoDate(date),
    'timezone': 'Asia/Ho_Chi_Minh',
    'health': {
      'hasProfile': hasProfile,
      'weightKg': hasProfile ? 65.0 : null,
      'heightCm': hasProfile ? 170 : null,
      'bmi': hasProfile ? 22.49 : null,
      'goal': hasProfile ? 'GAIN_MUSCLE' : null,
      'latestWeightLog': null,
    },
    'nutrition': {
      'entryCount': entryCount,
      'totals': totals ?? _n(500, 25, 75, 10),
      'targets': targets,
      'remaining': remaining,
      'targetsCalculatedAt': targets == null ? null : '2026-11-01T03:00:00Z',
    },
    'training': {
      'today': today,
      'week': {
        'from': isoDate(monday),
        'to': isoDate(addDays(monday, 6)),
        'scheduled': scheduled,
        'completed': completed,
        'cancelled': cancelled,
      },
      'next': next,
    },
    'generatedAt': '2026-11-09T03:15:00Z',
  };
}

Map<String, dynamic> _newUser(DateTime date) => _json(
  date,
  hasProfile: false,
  entryCount: 0,
  totals: _n(0, 0, 0, 0),
  scheduled: 0,
  completed: 0,
);

class _FakeDashboardApi implements DashboardApi {
  final gets = <String>[];
  final pending = <String, Completer<Dashboard>>{};
  Map<String, dynamic> Function(DateTime date) respond = (d) => _json(d);
  Object? fail;

  @override
  Future<Dashboard> get(DateTime date) {
    final key = isoDate(date);
    gets.add(key);
    final error = fail;
    if (error != null) return Future.error(error);
    final c = pending.remove(key);
    if (c != null) return c.future;
    return Future.value(Dashboard.fromJson(respond(date)));
  }
}

class _FakeMealApi implements MealApi {
  final gets = <String>[];

  MealPlan _plan(DateTime date) => MealPlan.fromJson({
    'date': isoDate(date),
    'entryCount': 0,
    'meals': {for (final t in MealType.values) t.code: []},
    'mealTotals': {for (final t in MealType.values) t.code: _n(0, 0, 0, 0)},
    'totals': _n(0, 0, 0, 0),
    'targets': null,
    'remaining': null,
    'targetsCalculatedAt': null,
  });

  @override
  Future<MealPlan> get(DateTime date) async {
    gets.add(isoDate(date));
    return _plan(date);
  }

  @override
  Future<MealPlan> add({
    required DateTime date,
    required MealType mealType,
    required String foodId,
    required double servings,
  }) async => _plan(date);

  @override
  Future<MealPlan> update(
    String entryId, {
    MealType? mealType,
    double? servings,
  }) async => throw UnimplementedError();

  @override
  Future<MealPlan> delete(String entryId) async => throw UnimplementedError();
}

List<Override> _overrides(_FakeDashboardApi api, [_FakeMealApi? meal]) => [
  authControllerProvider.overrideWith(_Auth.new),
  dashboardApiProvider.overrideWithValue(api),
  mealApiProvider.overrideWithValue(meal ?? _FakeMealApi()),
];

ProviderContainer _container(_FakeDashboardApi api, [_FakeMealApi? meal]) {
  final c = ProviderContainer(overrides: _overrides(api, meal));
  addTearDown(c.dispose);
  return c;
}

Future<void> _pumpPage(
  WidgetTester tester,
  ProviderContainer c,
) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: DashboardPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Model', () {
    test('Tuần không có lịch → progress null (không chia 0)', () {
      final d = Dashboard.fromJson(_newUser(today()));
      expect(d.training.week.progress, isNull);
      expect(d.nutrition.targets, isNull);
      expect(d.nutrition.remaining, isNull);
      expect(d.health.weightKg, isNull);
    });

    test('Có lịch: 2/3', () {
      final d = Dashboard.fromJson(
        _json(today(), scheduled: 3, completed: 2, cancelled: 1),
      );
      expect(d.training.week.progress, closeTo(2 / 3, 1e-9));
    });
  });

  group('Màn Tổng quan', () {
    testWidgets('D01: user mới có CTA từng thẻ, không mục tiêu 0 giả', (
      tester,
    ) async {
      final api = _FakeDashboardApi()..respond = _newUser;
      await _pumpPage(tester, _container(api));

      expect(find.text('Xin chào, Minh'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-no-meal')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-no-target')), findsOneWidget);
      expect(find.text('0 kcal'), findsOneWidget);
      expect(find.textContaining('/ 0 kcal'), findsNothing);
      expect(find.byKey(const Key('dashboard-remaining')), findsNothing);
      expect(find.byKey(const Key('dashboard-add-meal')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-no-schedule')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-add-schedule')), findsOneWidget);
      expect(find.textContaining('chưa có lịch'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-no-next')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-complete-profile')), findsOneWidget);
    });

    testWidgets('D02: số server trả, kcal số nguyên, BMI không diễn giải', (
      tester,
    ) async {
      final api = _FakeDashboardApi()
        ..respond = (d) => _json(
          d,
          targets: _n(2791.6, 117, 406.4, 77.5),
          remaining: _n(2291.6, 92, 331.4, 67.5),
          today: [_schedule('s1', d, status: 'COMPLETED', logId: 'log-1')],
          completed: 1,
        );
      await _pumpPage(tester, _container(api));

      expect(find.text('500 / 2.792 kcal'), findsOneWidget);
      expect(find.text('Còn lại 2.292 kcal'), findsOneWidget);
      expect(find.text('25,0 / 117,0 g'), findsOneWidget);
      expect(find.textContaining('1/3 buổi hoàn thành'), findsOneWidget);
      expect(find.text('Đã xong'), findsOneWidget);
      expect(find.text('Cân nặng 65 kg (theo hồ sơ)'), findsOneWidget);
      expect(find.text('BMI 22,49 · Mục tiêu: Tăng cơ'), findsOneWidget);
      expect(find.textContaining('thừa cân'), findsNothing);
      expect(find.textContaining('bình thường'), findsNothing);
    });

    testWidgets('Vượt mục tiêu: thanh giới hạn, số vượt hiện đúng', (
      tester,
    ) async {
      final api = _FakeDashboardApi()
        ..respond = (d) => _json(
          d,
          totals: _n(2500, 100, 300, 80),
          targets: _n(2000, 100, 250, 60),
          remaining: _n(-500, 0, -50, -20),
        );
      await _pumpPage(tester, _container(api));

      expect(find.text('2.500 / 2.000 kcal'), findsOneWidget);
      expect(find.text('Vượt 500 kcal'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('dashboard-nutrition')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, 1.0);
    });

    testWidgets('Tải lại lỗi: giữ số cũ và báo dữ liệu cũ', (tester) async {
      final api = _FakeDashboardApi();
      final c = _container(api);
      await _pumpPage(tester, c);
      expect(find.text('500 kcal'), findsOneWidget);

      api.fail = const NetworkException();
      c.invalidate(dashboardProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-stale')), findsOneWidget);
      expect(find.text('500 kcal'), findsOneWidget);

      api.fail = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-stale')), findsNothing);
    });

    testWidgets('Lỗi lần đầu: nút thử lại', (tester) async {
      final api = _FakeDashboardApi()..fail = const NetworkException();
      await _pumpPage(tester, _container(api));
      expect(find.text('Thử lại'), findsOneWidget);
      api.fail = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('500 kcal'), findsOneWidget);
    });

    testWidgets('Thêm món: sang tab Thực đơn đúng ngày đang xem', (
      tester,
    ) async {
      final api = _FakeDashboardApi();
      final meal = _FakeMealApi();
      final c = _container(api, meal);
      c.listen(homeTabProvider, (_, _) {});
      c.listen(mealPlanProvider, (_, _) {});
      await _pumpPage(tester, c);

      await tester.tap(find.byKey(const Key('dashboard-prev-day')));
      await tester.pumpAndSettle();
      final yesterday = addDays(today(), -1);
      expect(api.gets.last, isoDate(yesterday));

      await tester.tap(find.byKey(const Key('dashboard-add-meal')));
      await tester.pumpAndSettle();
      expect(c.read(homeTabProvider), HomeTab.mealPlan);
      expect(c.read(mealPlanProvider).date, yesterday);
    });

    testWidgets('Hoàn thiện hồ sơ: sang tab Sức khỏe', (tester) async {
      final api = _FakeDashboardApi()..respond = _newUser;
      final c = _container(api);
      c.listen(homeTabProvider, (_, _) {});
      await _pumpPage(tester, c);
      await tester.tap(find.byKey(const Key('dashboard-complete-profile')));
      await tester.pump();
      expect(c.read(homeTabProvider), HomeTab.health);
    });
  });

  group('Provider', () {
    test('Đổi ngày khi đang tải: response ngày cũ không ghi vào ngày mới', () async {
      final api = _FakeDashboardApi();
      final c = _container(api);
      final d1 = addDays(today(), -1);
      final d2 = addDays(today(), -2);
      final slow = api.pending[isoDate(d1)] = Completer();
      c.listen(dashboardProvider((userId: 'u1', date: d1)), (_, _) {});
      await c.read(authControllerProvider.future);
      final second = c.read(dashboardProvider((userId: 'u1', date: d2)).future);
      expect((await second).date, d2);

      slow.complete(Dashboard.fromJson(_json(d1)));
      final first = await c.read(
        dashboardProvider((userId: 'u1', date: d1)).future,
      );
      expect(first.date, d1);
      expect(
        c.read(dashboardProvider((userId: 'u1', date: d2))).value!.date,
        d2,
      );
    });

    test('D07: đổi tài khoản → khóa cũ không còn trả dữ liệu, ngày về hôm nay', () async {
      final api = _FakeDashboardApi();
      final c = _container(api);
      await c.read(authControllerProvider.future);
      c.listen(dashboardDateProvider, (_, _) {});
      c.read(dashboardDateProvider.notifier).set(addDays(today(), -3));

      final oldKey = (userId: 'u1', date: today());
      c.listen(dashboardProvider(oldKey), (_, _) {});
      await c.read(dashboardProvider(oldKey).future);

      (c.read(authControllerProvider.notifier) as _Auth).switchTo('u2');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(dashboardDateProvider), today());
      await expectLater(
        c.read(dashboardProvider(oldKey).future),
        throwsA(isA<SessionExpiredException>()),
      );
      final b = await c.read(
        dashboardProvider((userId: 'u2', date: today())).future,
      );
      expect(b.date, today());
    });

    test('D06: thêm món ở thực đơn → Tổng quan tải lại', () async {
      final api = _FakeDashboardApi();
      final c = _container(api);
      await c.read(authControllerProvider.future);
      final key = (userId: 'u1', date: today());
      c.listen(dashboardProvider(key), (_, _) {});
      c.listen(mealPlanProvider, (_, _) {});
      await c.read(dashboardProvider(key).future);
      final before = api.gets.length;

      await c
          .read(mealPlanProvider.notifier)
          .add(mealType: MealType.lunch, foodId: 'f', servings: 1);
      await c.read(dashboardProvider(key).future);
      expect(api.gets.length, before + 1);
    });
  });
}
