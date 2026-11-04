import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format/date_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/workout/log/application/log_draft.dart';
import 'package:mobile/features/workout/log/data/log_api.dart';
import 'package:mobile/features/workout/log/data/log_models.dart';
import 'package:mobile/features/workout/log/presentation/log_detail_page.dart';
import 'package:mobile/features/workout/log/presentation/log_form_page.dart';
import 'package:mobile/features/workout/log/presentation/log_format.dart';
import 'package:mobile/features/workout/log/presentation/log_history_page.dart';
import 'package:mobile/features/workout/program/data/program_models.dart';
import 'package:mobile/features/workout/schedule/data/schedule_api.dart';
import 'package:mobile/features/workout/schedule/data/schedule_models.dart';
import 'package:mobile/features/workout/schedule/presentation/schedule_detail_page.dart';

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

const _exercises = [
  ProgramExercise(
    id: 'we1',
    orderNo: 1,
    exerciseId: 'e1',
    exerciseName: 'Goblet Squat',
    exerciseActive: true,
    targetSets: 2,
    targetReps: 10,
    restSeconds: 90,
  ),
  ProgramExercise(
    id: 'we2',
    orderNo: 2,
    exerciseId: 'e2',
    exerciseName: 'Chống đẩy',
    exerciseActive: true,
    targetSets: 2,
    targetReps: 12,
    restSeconds: 60,
  ),
];

ScheduleItem _item({
  required DateTime date,
  ScheduleStatus status = ScheduleStatus.scheduled,
  String? logId,
}) => ScheduleItem(
  id: 's1',
  date: date,
  startTime: '18:00',
  status: status,
  workoutDay: const ScheduleDayRef(
    id: 'd1',
    name: 'Buổi A',
    programId: 'p1',
    programName: 'Giáo án A',
    archived: false,
  ),
  workoutLogId: logId,
);

ScheduleDetail _schedule({
  DateTime? date,
  ScheduleStatus status = ScheduleStatus.scheduled,
  String? logId,
}) => ScheduleDetail(
  item: _item(date: date ?? today(), status: status, logId: logId),
  exercises: _exercises,
);

LogDetail _log({String id = 'l1'}) => LogDetail.fromJson({
  'id': id,
  'scheduleId': 's1',
  'workoutDate': '2026-11-04',
  'workoutName': 'Buổi A',
  'programName': 'Giáo án A',
  'startedAt': '2026-11-04T11:00:00Z',
  'endedAt': '2026-11-04T11:45:00Z',
  'note': null,
  'exerciseCount': 2,
  'setCount': 4,
  'totalReps': 40,
  'totalVolumeKg': 380.00,
  'exercises': [
    {
      'orderNo': 1,
      'exerciseId': 'e1',
      'exerciseName': 'Goblet Squat (tên lúc ghi)',
      'sets': [
        {'setNo': 1, 'reps': 10, 'weightKg': 20.00},
        {'setNo': 2, 'reps': 8, 'weightKg': 22.50},
      ],
    },
    {
      'orderNo': 2,
      'exerciseId': 'e2',
      'exerciseName': 'Chống đẩy',
      'sets': [
        {'setNo': 1, 'reps': 12, 'weightKg': 0},
        {'setNo': 2, 'reps': 10, 'weightKg': 0},
      ],
    },
  ],
});

LogSummary _summary(int i) => LogSummary.fromJson({
  'id': 'l$i',
  'scheduleId': 's$i',
  'workoutDate': isoDate(addDays(DateTime.utc(2026, 11, 4), -i)),
  'workoutName': 'Buổi $i',
  'programName': 'Giáo án A',
  'startedAt': null,
  'endedAt': null,
  'exerciseCount': 1,
  'setCount': 2,
  'totalReps': 20,
  'totalVolumeKg': 0,
});

class _FakeLogApi implements LogApi {
  final payloads = <Map<String, dynamic>>[];
  final pages = <int>[];

  /// Lỗi ném ra ở lần gửi tiếp theo (rồi xóa).
  Object? createError;

  /// Lỗi khi tải trang có số này.
  int? failPage;

  @override
  Future<LogDetail> create(Map<String, dynamic> payload) async {
    payloads.add(payload);
    final error = createError;
    if (error != null) {
      createError = null;
      throw error;
    }
    return _log();
  }

  @override
  Future<LogDetail> detail(String id) async => _log(id: id);

  @override
  Future<LogPage> list({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    if (page == failPage) {
      failPage = null;
      throw const NetworkException();
    }
    final items = [for (var i = page * 2; i < page * 2 + 2; i++) _summary(i)];
    return LogPage(items: items, page: page, totalItems: 5, hasNext: page < 2);
  }
}

class _FakeScheduleApi implements ScheduleApi {
  _FakeScheduleApi(this.current);

  ScheduleDetail current;
  int detailCalls = 0;

  @override
  Future<ScheduleDetail> detail(String id) async {
    detailCalls++;
    return current;
  }

  @override
  Future<ScheduleList> range(DateTime from, DateTime to) =>
      throw UnimplementedError();

  @override
  Future<ScheduleDetail> create({
    required String workoutDayId,
    required DateTime date,
    String? startTime,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<ScheduleDetail> update(
    String id, {
    required DateTime date,
    String? startTime,
    String? note,
    required ScheduleStatus status,
  }) => throw UnimplementedError();
}

/// Màn cao để form dài dựng đủ các ô (ListView chỉ dựng phần nhìn thấy).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(
  Widget home, {
  required _FakeLogApi logApi,
  required _FakeScheduleApi scheduleApi,
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_SignedIn.new),
    logApiProvider.overrideWithValue(logApi),
    scheduleApiProvider.overrideWithValue(scheduleApi),
  ],
  child: MaterialApp(home: home),
);

/// Nhập fixture plan §9: Goblet 10×20, 8×22,5; Chống đẩy 12×0, 10×0.
Future<void> _fillFixture(WidgetTester tester) async {
  final values = ['10', '20', '8', '22,5', '12', '0', '10', '0'];
  final fields = find.byType(TextField);
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('log-submit')));
  await tester.tap(find.byKey(const Key('log-submit')));
  await tester.pumpAndSettle();
  if (find.byKey(const Key('log-confirm')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('log-confirm')));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Bản nháp ghi buổi', () {
    final now = DateTime(2026, 11, 4, 18, 5);

    test('Ô trống không phải 0; tạ 0 và số lẻ dấu phẩy hợp lệ', () {
      final draft = LogDraft.fromSchedule(
        _schedule(date: DateTime.utc(2026, 11, 4)),
        now: now,
      );
      expect(draft.exercises.map((e) => e.sets.length), [2, 2]);
      final errors = draft.validate();
      expect(errors['exercises[0].sets[0].reps'], 'Nhập số lần');
      expect(
        errors['exercises[0].sets[0].weightKg'],
        contains('0 nếu không tạ'),
      );

      final sets = draft.exercises[0].sets;
      sets[0]
        ..reps = '10'
        ..weight = '0';
      sets[1]
        ..reps = '8'
        ..weight = '22,5';
      draft.exercises[1].included = false;
      expect(draft.validate(), isEmpty);

      sets[1].weight = '22,555';
      sets[0].reps = '0';
      final bad = draft.validate();
      expect(
        bad.keys,
        containsAll([
          'exercises[0].sets[0].reps',
          'exercises[0].sets[1].weightKg',
        ]),
      );
    });

    test('Bỏ bài: chỉ gửi bài đã chọn, không có hiệp 0 giả; giờ kết thúc giữ nguyên khi gửi lại', () {
      final draft = LogDraft.fromSchedule(
        _schedule(date: DateTime.utc(2026, 11, 4)),
        now: now,
      );
      draft.exercises[0].included = false;
      for (final s in draft.exercises[1].sets) {
        s
          ..reps = '12'
          ..weight = '0';
      }
      final first = draft.toPayload(DateTime(2026, 11, 4, 18, 50));
      final retry = draft.toPayload(DateTime(2026, 11, 4, 19, 30));
      expect(first['exercises'], [
        {
          'exerciseId': 'e2',
          'sets': [
            {'reps': 12, 'weightKg': 0.0},
            {'reps': 12, 'weightKg': 0.0},
          ],
        },
      ]);
      expect(first['startedAt'], now.toUtc().toIso8601String());
      expect(retry['endedAt'], first['endedAt']);
      expect(draft.exerciseForPath(0)!.exerciseId, 'e2');
    });

    test('Không chọn bài nào → lỗi; lịch ngày đã qua không gửi giờ', () {
      final draft = LogDraft.fromSchedule(
        _schedule(date: DateTime.utc(2026, 11, 1)),
        now: now,
      );
      for (final e in draft.exercises) {
        e.included = false;
      }
      expect(draft.validate()['exercises'], isNotNull);
      draft.exercises[0].included = true;
      draft.exercises[0].fillPlannedReps();
      for (final s in draft.exercises[0].sets) {
        s.weight = '16';
      }
      expect(draft.exercises[0].sets.first.reps, '10');
      final payload = draft.toPayload(now);
      expect(payload['startedAt'], isNull);
      expect(payload['endedAt'], isNull);
    });

    test('Định dạng kg', () {
      expect(kgText(20), '20');
      expect(kgText(22.5), '22,5');
      expect(kgText(12.25), '12,25');
      expect(kgText(0), '0');
    });
  });

  group('Form ghi buổi', () {
    testWidgets('Nhập fixture, xác nhận, lưu đúng body rồi mở kết quả', (
      tester,
    ) async {
      _tall(tester);
      final logApi = _FakeLogApi();
      final scheduleApi = _FakeScheduleApi(_schedule());
      await tester.pumpWidget(
        _app(
          LogFormPage(schedule: _schedule()),
          logApi: logApi,
          scheduleApi: scheduleApi,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kế hoạch: 2 hiệp × 10 lần'), findsOneWidget);

      // Chưa nhập gì → không gửi.
      await _submit(tester);
      expect(logApi.payloads, isEmpty);
      expect(find.text('Nhập số lần'), findsWidgets);

      await _fillFixture(tester);
      await _submit(tester);
      expect(logApi.payloads, hasLength(1));
      final exercises = logApi.payloads.single['exercises'] as List;
      expect(exercises[0], {
        'exerciseId': 'e1',
        'sets': [
          {'reps': 10, 'weightKg': 20.0},
          {'reps': 8, 'weightKg': 22.5},
        ],
      });
      expect(find.text('Kết quả buổi tập'), findsOneWidget);
      expect(find.text('1. Goblet Squat (tên lúc ghi)'), findsOneWidget);
      expect(find.text('22,5'), findsOneWidget);
    });

    testWidgets('Gửi lặp → 409 kèm id: giữ nháp, cho mở kết quả đã lưu', (
      tester,
    ) async {
      _tall(tester);
      final logApi = _FakeLogApi()
        ..createError = ApiException(
          'Buổi tập này đã được ghi nhận',
          statusCode: 409,
          code: 'WORKOUT_ALREADY_LOGGED',
          data: const {'workoutLogId': 'l9'},
        );
      await tester.pumpWidget(
        _app(
          LogFormPage(schedule: _schedule()),
          logApi: logApi,
          scheduleApi: _FakeScheduleApi(_schedule()),
        ),
      );
      await _fillFixture(tester);
      await _submit(tester);
      expect(find.text('Đã có kết quả'), findsOneWidget);
      await tester.tap(find.byKey(const Key('log-open-existing')));
      await tester.pumpAndSettle();
      expect(find.text('Kết quả buổi tập'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      // Quay lại form: dữ liệu đang nhập vẫn còn.
      expect(find.byKey(const Key('log-banner')), findsOneWidget);
      expect(find.widgetWithText(TextField, '22,5'), findsOneWidget);
    });

    testWidgets(
      'Mất mạng sau khi gửi, server đã lưu → kiểm tra lịch và mở kết quả, không gửi lại',
      (tester) async {
        _tall(tester);
        final logApi = _FakeLogApi()..createError = const NetworkException();
        final scheduleApi = _FakeScheduleApi(
          _schedule(status: ScheduleStatus.completed, logId: 'l7'),
        );
        await tester.pumpWidget(
          _app(
            LogFormPage(schedule: _schedule()),
            logApi: logApi,
            scheduleApi: scheduleApi,
          ),
        );
        await _fillFixture(tester);
        await _submit(tester);
        expect(scheduleApi.detailCalls, 1);
        expect(logApi.payloads, hasLength(1));
        expect(find.text('Kết quả buổi tập'), findsOneWidget);
      },
    );

    testWidgets('Mất mạng, server chưa lưu → giữ nháp, báo gửi lại', (
      tester,
    ) async {
      _tall(tester);
      final logApi = _FakeLogApi()..createError = const NetworkException();
      await tester.pumpWidget(
        _app(
          LogFormPage(schedule: _schedule()),
          logApi: logApi,
          scheduleApi: _FakeScheduleApi(_schedule()),
        ),
      );
      await _fillFixture(tester);
      await _submit(tester);
      expect(
        find.textContaining('Máy chủ chưa nhận được kết quả'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, '22,5'), findsOneWidget);

      // Gửi lại cùng giờ kết thúc.
      await _submit(tester);
      expect(logApi.payloads, hasLength(2));
      expect(logApi.payloads[1]['endedAt'], logApi.payloads[0]['endedAt']);
      expect(find.text('Kết quả buổi tập'), findsOneWidget);
    });

    testWidgets('Lỗi trường từ server hiện đúng ô của bài đã chọn', (
      tester,
    ) async {
      _tall(tester);
      final logApi = _FakeLogApi()
        ..createError = ApiException(
          'Dữ liệu không hợp lệ',
          statusCode: 400,
          code: 'VALIDATION_ERROR',
          fieldErrors: const {
            'exercises[0].sets[1].weightKg': 'Mức tạ từ 0 đến 999,99 kg',
          },
        );
      await tester.pumpWidget(
        _app(
          LogFormPage(schedule: _schedule()),
          logApi: logApi,
          scheduleApi: _FakeScheduleApi(_schedule()),
        ),
      );
      await _fillFixture(tester);
      await _submit(tester);
      expect(find.text('Mức tạ từ 0 đến 999,99 kg'), findsOneWidget);
      expect(find.text('Kết quả buổi tập'), findsNothing);
    });

    testWidgets('Rời form khi đã nhập thì hỏi lại', (tester) async {
      _tall(tester);
      final scheduleApi = _FakeScheduleApi(_schedule());
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogFormPage(schedule: _schedule()),
                ),
              ),
              child: const Text('mở form'),
            ),
          ),
          logApi: _FakeLogApi(),
          scheduleApi: scheduleApi,
        ),
      );
      await tester.tap(find.text('mở form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '10');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ dữ liệu đang nhập?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Ghi buổi: Buổi A'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('log-discard')));
      await tester.pumpAndSettle();
      expect(find.text('mở form'), findsOneWidget);
    });
  });

  group('Lịch và kết quả', () {
    testWidgets('Lịch tương lai: chưa cho ghi', (tester) async {
      _tall(tester);
      final scheduleApi = _FakeScheduleApi(
        _schedule(date: addDays(today(), 1)),
      );
      await tester.pumpWidget(
        _app(
          const ScheduleDetailPage(id: 's1'),
          logApi: _FakeLogApi(),
          scheduleApi: scheduleApi,
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('schedule-start-log')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Chưa tới ngày tập'), findsOneWidget);
    });

    testWidgets('Lịch đã qua vẫn ghi được (ghi muộn)', (tester) async {
      _tall(tester);
      final scheduleApi = _FakeScheduleApi(
        _schedule(date: addDays(today(), -2)),
      );
      await tester.pumpWidget(
        _app(
          const ScheduleDetailPage(id: 's1'),
          logApi: _FakeLogApi(),
          scheduleApi: scheduleApi,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-start-log')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ghi muộn cho ngày đã qua'), findsOneWidget);
    });

    testWidgets('Lịch đã tập: mở kết quả, không có form', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          const ScheduleDetailPage(id: 's1'),
          logApi: _FakeLogApi(),
          scheduleApi: _FakeScheduleApi(
            _schedule(status: ScheduleStatus.completed, logId: 'l1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-start-log')), findsNothing);
      await tester.tap(find.byKey(const Key('schedule-view-log')));
      await tester.pumpAndSettle();
      expect(find.text('Tổng số lần: 40'), findsOneWidget);
      expect(find.text('Khối lượng tạ ngoài: 380 kg'), findsOneWidget);
    });

    testWidgets('Chi tiết dùng tên snapshot, hiệp theo thứ tự', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          const LogDetailPage(id: 'l1'),
          logApi: _FakeLogApi(),
          scheduleApi: _FakeScheduleApi(_schedule()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1. Goblet Squat (tên lúc ghi)'), findsOneWidget);
      expect(find.text('2. Chống đẩy'), findsOneWidget);
      expect(find.text('Hiệp: 4'), findsOneWidget);
      expect(find.text('22,5'), findsOneWidget);
    });

    testWidgets('Lịch sử: tải thêm; lỗi trang sau giữ các mục đã có', (
      tester,
    ) async {
      _tall(tester);
      final logApi = _FakeLogApi()..failPage = 1;
      await tester.pumpWidget(
        _app(
          const LogHistoryPage(),
          logApi: logApi,
          scheduleApi: _FakeScheduleApi(_schedule()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buổi 0'), findsOneWidget);
      expect(find.text('Buổi 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-more')));
      await tester.pumpAndSettle();
      expect(find.text('Buổi 1'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Buổi 3'), findsOneWidget);
      expect(logApi.pages, [0, 1, 1]);
    });
  });
}
