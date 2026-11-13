import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format/date_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/auth/presentation/forgot_password_page.dart';
import 'package:mobile/features/dashboard/data/dashboard_models.dart';
import 'package:mobile/features/health/data/health_api.dart';
import 'package:mobile/features/health/data/health_models.dart';
import 'package:mobile/features/weight/data/weight_api.dart';
import 'package:mobile/features/weight/data/weight_models.dart';
import 'package:mobile/features/weight/presentation/weight_page.dart';

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => Authenticated(const AuthUser(
        id: 'u1',
        email: 'u1@example.com',
        fullName: 'Minh',
        role: 'USER',
        hasHealthProfile: true,
      ));
}

WeightLog _log(String id, DateTime date, double kg, [String? note]) =>
    WeightLog(id: id, logDate: date, weightKg: kg, note: note);

class _FakeWeightApi implements WeightApi {
  _FakeWeightApi(this.logs);

  List<WeightLog> logs;
  final saves = <({DateTime date, double kg, String? note})>[];
  final deletes = <String>[];
  final ranges = <String>[];

  @override
  Future<List<WeightLog>> list(DateTime from, DateTime to) async {
    ranges.add('${isoDate(from)}..${isoDate(to)}');
    return [...logs]..sort((a, b) => a.logDate.compareTo(b.logDate));
  }

  @override
  Future<WeightLog> save(
      {required DateTime logDate, required double weightKg, String? note}) async {
    saves.add((date: logDate, kg: weightKg, note: note));
    final saved = _log('new-${saves.length}', logDate, weightKg, note);
    logs = [...logs.where((l) => l.logDate != logDate), saved];
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    deletes.add(id);
    logs = logs.where((l) => l.id != id).toList();
  }
}

class _FakeHealthApi implements HealthApi {
  _FakeHealthApi(this.weightKg);

  double? weightKg;
  final saved = <HealthProfileInput>[];

  HealthProfileData _data(double kg) => HealthProfileData.fromJson({
        'profile': {
          'sex': 'MALE',
          'dateOfBirth': '2004-05-10',
          'age': 22,
          'heightCm': 170,
          'weightKg': kg,
          'activityLevel': 'MODERATE',
          'goal': 'LOSE_WEIGHT',
        },
        'targets': {
          'bmi': 22.49,
          'bmrKcal': 1607.5,
          'tdeeKcal': 2491.6,
          'targetKcal': 2084.6,
          'proteinG': 117,
          'carbsG': 300,
          'fatG': 60,
          'kcalFloorApplied': false,
          'formulaVersion': 'MSJ-v1',
        },
      });

  @override
  Future<HealthProfileData?> fetch() async =>
      weightKg == null ? null : _data(weightKg!);

  @override
  Future<HealthProfileData> save(HealthProfileInput input) async {
    saved.add(input);
    weightKg = input.weightKg;
    return _data(input.weightKg);
  }
}

class _FakeAuthApi implements AuthApi {
  final forgot = <String>[];
  final resets = <({String email, String code, String password})>[];
  Object? resetError;

  @override
  Future<void> forgotPassword(String email) async => forgot.add(email);

  @override
  Future<void> resetPassword(
      {required String email,
      required String code,
      required String newPassword}) async {
    resets.add((email: email, code: code, password: newPassword));
    final error = resetError;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpWeight(WidgetTester tester, _FakeWeightApi api,
    [_FakeHealthApi? health]) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      weightApiProvider.overrideWithValue(api),
      healthApiProvider.overrideWithValue(health ?? _FakeHealthApi(null)),
    ],
    child: const MaterialApp(home: WeightPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final t = today();

  group('Model', () {
    test('W01: fixture 70 → 69,5 → 69,8 cho chênh lệch -0,2 kg', () {
      final logs = [
        _log('a', addDays(t, -6), 70),
        _log('b', addDays(t, -4), 69.5),
        _log('c', t, 69.8),
      ];
      final change = WeightChange.of(logs)!;
      expect(change.deltaKg, -0.2);
      expect(change.first.id, 'a');
      expect(change.last.id, 'c');
      expect(WeightChange.of(logs.take(1).toList()), isNull);
    });

    test('JSON số nguyên vẫn đọc được', () {
      final log = WeightLog.fromJson(
          {'id': 'x', 'logDate': '2026-11-12', 'weightKg': 65, 'note': null});
      expect(log.weightKg, 65.0);
      expect(log.logDate, DateTime.utc(2026, 11, 12));
    });

    test('Dashboard đọc latestWeightLog', () {
      final h = DashboardHealth.fromJson({
        'hasProfile': true,
        'weightKg': 65.0,
        'heightCm': 170,
        'bmi': 22.49,
        'goal': 'GAIN_MUSCLE',
        'latestWeightLog': {'logDate': '2026-11-12', 'weightKg': 63},
      });
      expect(h.latestWeightKg, 63.0);
      expect(h.latestWeightDate, DateTime.utc(2026, 11, 12));
      expect(
          DashboardHealth.fromJson({'hasProfile': false}).latestWeightKg, isNull);
    });
  });

  group('Màn cân nặng', () {
    testWidgets('chưa có dữ liệu → lời mời ghi, không vẽ biểu đồ', (tester) async {
      final api = _FakeWeightApi([]);
      await _pumpWeight(tester, api);
      expect(find.byKey(const Key('weight-empty')), findsOneWidget);
      expect(find.byKey(const Key('weight-change')), findsNothing);
      // Mặc định 90 ngày, kết thúc hôm nay.
      expect(api.ranges.single, '${isoDate(addDays(t, -89))}..${isoDate(t)}');
    });

    testWidgets('fixture: biểu đồ + chênh lệch có nêu khoảng ngày', (tester) async {
      await _pumpWeight(
          tester,
          _FakeWeightApi([
            _log('a', addDays(t, -6), 70),
            _log('b', addDays(t, -4), 69.5, 'Sau khi ngủ dậy'),
            _log('c', t, 69.8),
          ]));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
          find.text('Từ ${viDate(addDays(t, -6))} đến ${viDate(t)}: -0,2 kg'),
          findsOneWidget);
      expect(find.text('69,5 kg'), findsOneWidget);
      expect(find.textContaining('Sau khi ngủ dậy'), findsOneWidget);
    });

    testWidgets('một lần cân: vẫn hiện, báo cần 2 lần để so sánh', (tester) async {
      await _pumpWeight(tester, _FakeWeightApi([_log('a', t, 65)]));
      expect(find.text('Cần ít nhất 2 lần cân để so sánh.'), findsOneWidget);
      expect(find.text('65 kg'), findsOneWidget);
    });

    testWidgets('đổi khoảng 1 năm gọi lại API với from lùi 364 ngày', (tester) async {
      final api = _FakeWeightApi([]);
      await _pumpWeight(tester, api);
      await tester.tap(find.text('1 năm'));
      await tester.pumpAndSettle();
      expect(api.ranges.last, '${isoDate(addDays(t, -364))}..${isoDate(t)}');
    });

    testWidgets('kiểm tra ô cân nặng trước khi gửi', (tester) async {
      final api = _FakeWeightApi([]);
      await _pumpWeight(tester, api);
      await tester.tap(find.byKey(const Key('weight-add')));
      await tester.pumpAndSettle();
      for (final bad in ['301', '29,9', '65,55', 'abc']) {
        await tester.enterText(find.byKey(const Key('weight-kg')), bad);
        await tester.tap(find.byKey(const Key('weight-save')));
        await tester.pumpAndSettle();
      }
      expect(api.saves, isEmpty);
    });

    testWidgets('BR-H02: ghi lần cân mới nhất → hỏi, đồng ý mới cập nhật hồ sơ',
        (tester) async {
      final api = _FakeWeightApi([_log('a', addDays(t, -2), 70)]);
      final health = _FakeHealthApi(70);
      await _pumpWeight(tester, api, health);

      await tester.tap(find.byKey(const Key('weight-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('weight-kg')), '69,8');
      await tester.tap(find.byKey(const Key('weight-save')));
      await tester.pumpAndSettle();

      expect(api.saves.single.kg, 69.8);
      expect(api.saves.single.date, t);
      expect(find.text('Cập nhật hồ sơ?'), findsOneWidget);
      expect(health.saved, isEmpty);
      await tester.tap(find.byKey(const Key('weight-profile-update')));
      await tester.pumpAndSettle();
      expect(health.saved.single.weightKg, 69.8);
      expect(health.saved.single.goal, Goal.loseWeight);
      expect(find.text('Từ ${viDate(addDays(t, -2))} đến ${viDate(t)}: -0,2 kg'),
          findsOneWidget);
    });

    testWidgets('chọn "Để sau" thì hồ sơ giữ nguyên', (tester) async {
      final health = _FakeHealthApi(70);
      await _pumpWeight(tester, _FakeWeightApi([]), health);
      await tester.tap(find.byKey(const Key('weight-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('weight-kg')), '68');
      await tester.tap(find.byKey(const Key('weight-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weight-profile-skip')));
      await tester.pumpAndSettle();
      expect(health.saved, isEmpty);
    });

    testWidgets('sửa lần cân cũ không hỏi cập nhật hồ sơ', (tester) async {
      final api = _FakeWeightApi(
          [_log('old', addDays(t, -5), 71), _log('new', t, 70)]);
      final health = _FakeHealthApi(70);
      await _pumpWeight(tester, api, health);
      await tester.tap(find.byKey(const Key('weight-item-old')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('weight-kg')), '71,5');
      await tester.tap(find.byKey(const Key('weight-save')));
      await tester.pumpAndSettle();
      expect(api.saves.single.date, addDays(t, -5));
      expect(find.text('Cập nhật hồ sơ?'), findsNothing);
    });

    testWidgets('xóa cần xác nhận', (tester) async {
      final api = _FakeWeightApi([_log('a', t, 65)]);
      await _pumpWeight(tester, api);
      await tester.tap(find.byKey(const Key('weight-delete-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(api.deletes, isEmpty);
      await tester.tap(find.byKey(const Key('weight-delete-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weight-delete-confirm')));
      await tester.pumpAndSettle();
      expect(api.deletes, ['a']);
      expect(find.byKey(const Key('weight-empty')), findsOneWidget);
    });
  });

  group('Quên mật khẩu', () {
    Future<_FakeAuthApi> pumpForgot(WidgetTester tester,
        {List<String?>? popped}) async {
      final api = _FakeAuthApi();
      await tester.pumpWidget(ProviderScope(
        overrides: [authApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final email = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage(
                            initialEmail: 'minh@example.com')));
                popped?.add(email);
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('gửi mã → thông báo chung → đặt lại → về đăng nhập với email',
        (tester) async {
      final popped = <String?>[];
      final api = await pumpForgot(tester, popped: popped);
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pumpAndSettle();
      expect(api.forgot, ['minh@example.com']);
      expect(find.byKey(const Key('forgot-sent')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('reset-code')), '48291');
      await tester.enterText(find.byKey(const Key('reset-password')), 'Matkhau456');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'Matkhau456');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(api.resets, isEmpty, reason: 'mã thiếu chữ số bị chặn ở app');

      await tester.enterText(find.byKey(const Key('reset-code')), '482913');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'Matkhau999');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('reset-confirm')), 'Matkhau456');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(api.resets.single,
          (email: 'minh@example.com', code: '482913', password: 'Matkhau456'));
      expect(popped, ['minh@example.com']);
    });

    testWidgets('mã sai → báo lỗi, ở lại màn để nhập lại', (tester) async {
      final api = await pumpForgot(tester);
      api.resetError = ApiException(
          'Mã không đúng hoặc đã hết hạn. Hãy kiểm tra lại hoặc yêu cầu mã mới.',
          statusCode: 400,
          code: 'INVALID_RESET_CODE');
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('reset-code')), '000000');
      await tester.enterText(find.byKey(const Key('reset-password')), 'Matkhau456');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'Matkhau456');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot-error')), findsOneWidget);
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
    });

    testWidgets('mật khẩu mới yếu bị chặn ở app', (tester) async {
      final api = await pumpForgot(tester);
      await tester.tap(find.byKey(const Key('forgot-send')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('reset-code')), '123456');
      await tester.enterText(find.byKey(const Key('reset-password')), 'matkhau');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'matkhau');
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(api.resets, isEmpty);
      expect(find.text('Mật khẩu từ 8 đến 72 ký tự'), findsOneWidget);
    });
  });
}
