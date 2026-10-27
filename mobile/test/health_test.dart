import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/format/number_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/token_store.dart';
import 'package:mobile/features/health/application/health_profile_controller.dart';
import 'package:mobile/features/health/data/health_api.dart';
import 'package:mobile/features/health/data/health_models.dart';
import 'package:mobile/features/health/presentation/health_home_page.dart';

class _MemoryTokenStore implements TokenStore {
  String? refresh;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveRefresh(String token) async => refresh = token;

  @override
  Future<void> clear() async => refresh = null;
}

http.Response _json(int status, Object? body) => http.Response(
    body == null ? '' : jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

// Số nguyên (170) lẫn số lẻ (22.49): JSON từ backend không cố định kiểu.
const _profileJson = {
  'profile': {
    'sex': 'MALE',
    'dateOfBirth': '2004-05-10',
    'age': 22,
    'heightCm': 170,
    'weightKg': 65.0,
    'activityLevel': 'MODERATE',
    'goal': 'GAIN_MUSCLE',
    'updatedAt': '2026-10-27T03:15:00Z',
  },
  'targets': {
    'bmi': 22.49,
    'bmrKcal': 1607.5,
    'tdeeKcal': 2491.6,
    'targetKcal': 2791.6,
    'proteinG': 117,
    'carbsG': 406.4,
    'fatG': 77.5,
    'kcalFloorApplied': false,
    'formulaVersion': 'MSJ-v1',
    'calculatedAt': '2026-10-27T03:15:00Z',
  },
};

/// Đăng nhập với backend giả rồi trả HealthApi dùng chung phiên đó.
Future<HealthApi> _healthApi(
    Future<http.Response> Function(http.Request) handler) async {
  final client = MockClient((request) async {
    if (request.url.path == '/api/v1/auth/login') {
      return _json(200, {
        'tokenType': 'Bearer',
        'accessToken': 'access-1',
        'accessTokenExpiresIn': 900,
        'refreshToken': 'refresh-1',
        'user': {
          'id': 'u1',
          'email': 'a@example.com',
          'fullName': 'A',
          'role': 'USER',
          'hasHealthProfile': false,
        },
      });
    }
    return handler(request);
  });
  final api = ApiClient(client);
  final auth = AuthRepository(AuthApi(api), api, _MemoryTokenStore());
  await auth.login('a@example.com', 'Matkhau123');
  return HealthApi(auth);
}

void main() {
  group('Định dạng số vi-VN', () {
    test('Nhóm nghìn bằng dấu chấm, thập phân bằng dấu phẩy', () {
      expect(formatVi(2791.6), '2.791,6');
      expect(formatVi(22.49, decimals: 2), '22,49');
      expect(formatVi(117), '117,0');
      expect(formatVi(250, decimals: 0), '250');
    });

    test('Nhận dấu phẩy hoặc chấm, tối đa 1 chữ số lẻ', () {
      expect(parseViDecimal('170,5'), 170.5);
      expect(parseViDecimal(' 65.0 '), 65.0);
      expect(parseViDecimal('170'), 170.0);
      expect(parseViDecimal('170,25'), isNull);
      expect(parseViDecimal('1.000'), isNull);
      expect(parseViDecimal('-5'), isNull);
      expect(parseViDecimal('abc'), isNull);
    });
  });

  test('Đọc hồ sơ với số nguyên và số lẻ', () {
    final data = HealthProfileData.fromJson(_profileJson);
    expect(data.profile.heightCm, 170.0);
    expect(data.profile.activityLevel, ActivityLevel.moderate);
    expect(data.profile.goal, Goal.gainMuscle);
    expect(data.targets.proteinG, 117.0);
    expect(data.targets.targetKcal, 2791.6);
  });

  group('HealthApi', () {
    test('404 HEALTH_PROFILE_REQUIRED nghĩa là chưa có hồ sơ', () async {
      final api = await _healthApi((_) async => _json(404,
          {'code': 'HEALTH_PROFILE_REQUIRED', 'message': 'Bạn chưa có hồ sơ'}));
      expect(await api.fetch(), isNull);
    });

    test('Mất mạng không bị hiểu là chưa có hồ sơ', () async {
      final api = await _healthApi((_) async => throw http.ClientException('offline'));
      expect(api.fetch(), throwsA(isA<NetworkException>()));
    });

    test('Lưu gửi mã enum API, ngày YYYY-MM-DD và Bearer', () async {
      late http.Request sent;
      final api = await _healthApi((request) async {
        sent = request;
        return _json(200, _profileJson);
      });
      await api.save(HealthProfileInput(
        sex: Sex.female,
        dateOfBirth: DateTime(2004, 5, 9),
        heightCm: 160.5,
        weightKg: 50,
        activityLevel: ActivityLevel.veryActive,
        goal: Goal.loseWeight,
      ));
      expect(sent.method, 'PUT');
      expect(sent.headers['Authorization'], 'Bearer access-1');
      expect(jsonDecode(sent.body), {
        'sex': 'FEMALE',
        'dateOfBirth': '2004-05-09',
        'heightCm': 160.5,
        'weightKg': 50.0,
        'activityLevel': 'VERY_ACTIVE',
        'goal': 'LOSE_WEIGHT',
      });
    });
  });

  group('Màn hồ sơ', () {
    Widget app(Future<HealthProfileData?> Function(Ref ref) profile) =>
        ProviderScope(
          overrides: [healthProfileProvider.overrideWith(profile)],
          child: const MaterialApp(home: HealthHomePage()),
        );

    testWidgets('Chưa có hồ sơ: hiện form, bấm lưu khi trống báo lỗi từng trường',
        (tester) async {
      await tester.pumpWidget(app((ref) async => null));
      await tester.pumpAndSettle();

      expect(find.text('Tạo hồ sơ sức khỏe'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('health-submit')));
      await tester.tap(find.byKey(const Key('health-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn giới tính'), findsOneWidget);
      expect(find.text('Vui lòng chọn ngày sinh'), findsOneWidget);
      expect(find.text('Vui lòng nhập chiều cao'), findsOneWidget);
    });

    testWidgets('Có hồ sơ: hiện mục tiêu do backend tính', (tester) async {
      await tester.pumpWidget(
          app((ref) async => HealthProfileData.fromJson(_profileJson)));
      await tester.pumpAndSettle();

      expect(find.text('2.791,6 kcal'), findsOneWidget);
      expect(find.text('22,49'), findsOneWidget);
      expect(find.text('117,0 g'), findsOneWidget);
    });

    testWidgets('Lỗi tải hồ sơ: không hiện form tạo mới, có nút thử lại',
        (tester) async {
      await tester.pumpWidget(
          app((ref) async => throw const NetworkException()));
      await tester.pumpAndSettle();

      expect(find.text('Tạo hồ sơ sức khỏe'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
