import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format/date_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/exercise/data/exercise_api.dart';
import 'package:mobile/features/exercise/data/exercise_models.dart';
import 'package:mobile/features/workout/program/application/program_draft.dart';
import 'package:mobile/features/workout/program/application/program_providers.dart';
import 'package:mobile/features/workout/program/data/program_api.dart';
import 'package:mobile/features/workout/program/data/program_models.dart';
import 'package:mobile/features/workout/program/presentation/program_form_page.dart';
import 'package:mobile/features/workout/schedule/data/schedule_api.dart';
import 'package:mobile/features/workout/schedule/data/schedule_models.dart';
import 'package:mobile/features/workout/schedule/presentation/schedule_detail_page.dart';
import 'package:mobile/features/workout/schedule/presentation/schedule_week_page.dart';

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

ProgramDetail _program({int version = 0, List<ProgramDay>? days}) =>
    ProgramDetail(
      id: 'p1',
      name: 'Giáo án A',
      isTemplate: false,
      isActive: false,
      version: version,
      days:
          days ??
          [
            const ProgramDay(
              id: 'd1',
              dayOrder: 1,
              name: 'Buổi A',
              exercises: [
                ProgramExercise(
                  id: 'we1',
                  orderNo: 1,
                  exerciseId: 'e1',
                  exerciseName: 'Bài e1',
                  exerciseActive: true,
                  targetSets: 3,
                  targetReps: 10,
                  restSeconds: 90,
                ),
              ],
            ),
          ],
    );

class _FakeProgramApi implements ProgramApi {
  final created = <Map<String, dynamic>>[];
  final updated = <Map<String, dynamic>>[];
  Object? updateError;
  Object? createError;

  @override
  Future<ProgramDetail> create(Map<String, dynamic> body) async {
    created.add(body);
    if (createError != null) throw createError!;
    return _program();
  }

  @override
  Future<ProgramDetail> update(String id, Map<String, dynamic> body) async {
    updated.add(body);
    if (updateError != null) throw updateError!;
    return _program(version: 1);
  }

  @override
  Future<List<ProgramSummary>> list({bool templates = false}) async => [];

  @override
  Future<ProgramDetail> detail(String id) async => _program();

  @override
  Future<ProgramDetail> copyTemplate(String templateId) async => _program();

  @override
  Future<ProgramDetail> activate(String id) async => _program();
}

class _FakeExerciseApi implements ExerciseApi {
  @override
  Future<ExercisePage> search(
    ExerciseQuery query, {
    required int page,
    int size = ExerciseApi.pageSize,
  }) async => const ExercisePage(
    items: [
      ExerciseSummary(
        id: 'e1',
        name: 'Bài e1',
        muscleGroup: 'CHEST',
        equipment: 'DUMBBELL',
        difficulty: 'BEGINNER',
      ),
      ExerciseSummary(
        id: 'e2',
        name: 'Bài e2',
        muscleGroup: 'BACK',
        equipment: 'DUMBBELL',
        difficulty: 'BEGINNER',
      ),
    ],
    page: 0,
    totalItems: 2,
    hasNext: false,
  );

  @override
  Future<ExerciseDetail> detail(String id) => throw UnimplementedError();

  @override
  Future<ExerciseFilters> filters() => throw UnimplementedError();
}

ScheduleItem _schedule(
  String id,
  DateTime date, {
  String? time,
  ScheduleStatus status = ScheduleStatus.scheduled,
}) => ScheduleItem(
  id: id,
  date: date,
  startTime: time,
  status: status,
  workoutDay: const ScheduleDayRef(
    id: 'd1',
    name: 'Buổi A',
    programId: 'p1',
    programName: 'Giáo án A',
    archived: false,
  ),
);

class _FakeScheduleApi implements ScheduleApi {
  _FakeScheduleApi(this.items);

  final List<ScheduleItem> items;
  final ranges = <String>[];
  final updates = <ScheduleStatus>[];

  @override
  Future<ScheduleList> range(DateTime from, DateTime to) async {
    ranges.add('${isoDate(from)}..${isoDate(to)}');
    return ScheduleList(
      from: from,
      to: to,
      items: items
          .where((s) => !s.date.isBefore(from) && !s.date.isAfter(to))
          .toList(),
    );
  }

  @override
  Future<ScheduleDetail> detail(String id) async => ScheduleDetail(
    item: items.firstWhere((s) => s.id == id),
    exercises: _program().days.first.exercises,
  );

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
  }) async {
    updates.add(status);
    final i = items.indexWhere((s) => s.id == id);
    items[i] = _schedule(id, date, time: startTime, status: status);
    return detail(id);
  }
}

void main() {
  group('Ngày lịch', () {
    test('Tuần bắt đầu thứ Hai; Chủ nhật thuộc tuần trước đó', () {
      expect(weekStart(DateTime(2026, 11, 2)), DateTime.utc(2026, 11, 2));
      expect(weekStart(DateTime(2026, 11, 8, 23, 59)), DateTime.utc(2026, 11, 2));
      expect(weekStart(DateTime(2026, 11, 9)), DateTime.utc(2026, 11, 9));
      // Tuần vắt qua năm.
      expect(weekStart(DateTime(2027, 1, 1)), DateTime.utc(2026, 12, 28));
      expect(addDays(DateTime.utc(2026, 12, 28), 6), DateTime.utc(2027, 1, 3));
    });

    test('Định dạng và đọc ngày ISO', () {
      final d = parseIsoDate('2026-03-09');
      expect(isoDate(d), '2026-03-09');
      expect(viDate(d), '09/03/2026');
      expect(viWeekday(d), 'Thứ Hai');
      expect(() => parseIsoDate('2026-3-9'), throwsFormatException);
    });

    test('Nhóm lịch theo ngày, giữ thứ tự server; quá ngày chỉ là hiển thị', () {
      final monday = DateTime.utc(2026, 11, 2);
      final sunday = addDays(monday, 6);
      final list = ScheduleList(
        from: monday,
        to: sunday,
        items: [
          _schedule('a', monday, time: '07:00'),
          _schedule('b', monday, time: '18:00'),
          _schedule('c', sunday),
        ],
      );
      expect(list.on(monday).map((s) => s.id), ['a', 'b']);
      expect(list.on(sunday).map((s) => s.id), ['c']);
      expect(list.on(addDays(monday, 1)), isEmpty);

      final tuesday = addDays(monday, 1);
      expect(list.items[0].isOverdue(tuesday), isTrue);
      expect(
        _schedule('x', monday, status: ScheduleStatus.cancelled)
            .isOverdue(tuesday),
        isFalse,
      );
    });
  });

  group('Bản nháp giáo án', () {
    DraftExercise ex(String id, {bool active = true}) =>
        DraftExercise(exerciseId: id, exerciseName: id, active: active);

    test('Bắt lỗi theo đúng đường dẫn của backend', () {
      final draft = ProgramDraft(
        days: [
          DraftDay(name: ' ', exercises: [ex('e1'), ex('e1')]),
          DraftDay(name: 'B'),
          DraftDay(name: 'C', exercises: [ex('e3', active: false)]),
        ],
      );
      draft.days[0].exercises[0]
        ..sets = '0'
        ..reps = '101'
        ..rest = '';
      final errors = draft.validate();
      expect(errors['name'], 'Vui lòng nhập tên giáo án');
      expect(errors['days[0].name'], 'Vui lòng nhập tên buổi');
      expect(errors['days[0].exercises[1].exerciseId'], 'Bài tập đã có trong buổi này');
      expect(errors['days[0].exercises[0].targetSets'], 'Số hiệp từ 1 đến 10');
      expect(errors['days[0].exercises[0].targetReps'], 'Số lần từ 1 đến 100');
      expect(errors['days[0].exercises[0].restSeconds'], 'Thời gian nghỉ từ 0 đến 600 giây');
      expect(errors['days[1].exercises'], 'Mỗi buổi có từ 1 đến 15 bài');
      expect(errors['days[2].exercises[0].exerciseId'], contains('ngừng sử dụng'));
    });

    test('Body PUT giữ id buổi, version; thứ tự theo mảng, không gửi dayOrder', () {
      final draft = ProgramDraft.fromDetail(
        _program(
          version: 4,
          days: [
            const ProgramDay(id: 'd1', dayOrder: 1, name: 'A', exercises: []),
            const ProgramDay(id: 'd2', dayOrder: 2, name: 'B', exercises: []),
          ],
        ),
      );
      draft.days[0].exercises.add(ex('e1')..sets = '4');
      draft.days[1].exercises.add(ex('e2'));
      draft.addDay().exercises.add(ex('e1'));
      ProgramDraft.move(draft.days, 1, -1);

      expect(draft.validate(), isEmpty);
      final json = draft.toJson();
      expect(json['version'], 4);
      final days = json['days'] as List;
      expect(days.map((d) => d['id']), ['d2', 'd1', null]);
      expect(days.first.containsKey('dayOrder'), isFalse);
      expect(days[1]['exercises'][0], {
        'exerciseId': 'e1',
        'targetSets': 4,
        'targetReps': 10,
        'restSeconds': 60,
      });
      expect(ProgramDraft().toJson().containsKey('version'), isFalse);
    });

    test('Đổi thứ tự: số liệu đi theo dòng (key ổn định)', () {
      final day = DraftDay(exercises: [ex('e1')..reps = '5', ex('e2')..reps = '8']);
      final keys = day.exercises.map((e) => e.key).toList();
      ProgramDraft.move(day.exercises, 0, 1);
      expect(day.exercises.map((e) => e.exerciseId), ['e2', 'e1']);
      expect(day.exercises.map((e) => e.reps), ['8', '5']);
      expect(day.exercises.map((e) => e.key), keys.reversed);
      ProgramDraft.move(day.exercises, 0, -1); // ngoài biên: không đổi
      expect(day.exercises.map((e) => e.exerciseId), ['e2', 'e1']);
    });
  });

  test('Chưa đăng nhập: không gọi API giáo án', () async {
    final api = _FakeProgramApi();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SignedOut.new),
        programApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final sub = container.listen(myProgramsProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      container.read(myProgramsProvider.future),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  group('Form giáo án', () {
    Widget app(_FakeProgramApi api, {ProgramDetail? initial}) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        programApiProvider.overrideWithValue(api),
        exerciseApiProvider.overrideWithValue(_FakeExerciseApi()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProgramFormPage(initial: initial),
                ),
              ),
              child: const Text('mở form'),
            ),
          ),
        ),
      ),
    );

    testWidgets('Chọn bài từ thư viện, chặn số sai, lưu đúng body', (tester) async {
      final api = _FakeProgramApi();
      await tester.pumpWidget(app(api));
      await tester.tap(find.text('mở form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('program-name')), 'Của tôi');
      await tester.tap(find.byKey(const Key('day-add-exercise-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick-e2')));
      await tester.pumpAndSettle();
      expect(find.text('Bài e2'), findsOneWidget);

      // Bài đã có trong buổi thì không chọn lại được.
      await tester.tap(find.byKey(const Key('day-add-exercise-0')));
      await tester.pumpAndSettle();
      expect(find.text('Đã có trong buổi này'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final sets = find.byKey(const Key('days[0].exercises[0].targetSets'));
      await tester.enterText(sets, '0');
      await tester.tap(find.byKey(const Key('program-save')));
      await tester.pumpAndSettle();
      expect(api.created, isEmpty);
      expect(find.text('Số hiệp từ 1 đến 10'), findsWidgets);

      await tester.enterText(sets, '4');
      await tester.tap(find.byKey(const Key('program-save')));
      await tester.pumpAndSettle();
      expect(api.created, hasLength(1));
      final body = api.created.single;
      expect(body['name'], 'Của tôi');
      expect(body.containsKey('version'), isFalse);
      expect(body['days'][0]['exercises'], [
        {'exerciseId': 'e2', 'targetSets': 4, 'targetReps': 10, 'restSeconds': 60},
      ]);
      expect(find.text('mở form'), findsOneWidget); // đã đóng form
    });

    testWidgets('Lỗi trường từ server hiện đúng dòng, giữ bản nháp', (tester) async {
      final api = _FakeProgramApi()
        ..updateError = ApiException(
          'Có bài tập không còn sử dụng được, vui lòng thay bài khác',
          statusCode: 422,
          code: 'EXERCISE_INACTIVE',
          fieldErrors: {
            'days[0].exercises[0].exerciseId':
                'Bài tập không tồn tại hoặc đã ngừng sử dụng',
          },
        );
      await tester.pumpWidget(app(api, initial: _program()));
      await tester.tap(find.text('mở form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('day-name-0')), 'Buổi mới');
      await tester.tap(find.byKey(const Key('program-save')));
      await tester.pumpAndSettle();

      expect(api.updated.single['version'], 0);
      expect(find.text('Bài tập không tồn tại hoặc đã ngừng sử dụng'), findsWidgets);
      expect(find.text('Buổi mới'), findsOneWidget);
      expect(find.text('Sửa giáo án'), findsOneWidget);
    });

    testWidgets('409 VERSION_CONFLICT: hỏi tải bản mới, không tự ghi đè', (tester) async {
      final api = _FakeProgramApi()
        ..updateError = ApiException(
          'Giáo án đã được sửa ở nơi khác. Hãy tải lại bản mới rồi sửa tiếp.',
          statusCode: 409,
          code: 'VERSION_CONFLICT',
        );
      await tester.pumpWidget(app(api, initial: _program(version: 2)));
      await tester.tap(find.text('mở form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('program-name')), 'Tên mới');
      await tester.tap(find.byKey(const Key('program-save')));
      await tester.pumpAndSettle();

      expect(api.updated, hasLength(1));
      expect(find.text('Giáo án đã thay đổi'), findsOneWidget);
      await tester.tap(find.byKey(const Key('program-conflict-reload')));
      await tester.pumpAndSettle();
      expect(api.updated, hasLength(1));
      expect(find.text('mở form'), findsOneWidget);
    });

    testWidgets('Rời form có thay đổi chưa lưu thì hỏi lại', (tester) async {
      await tester.pumpWidget(app(_FakeProgramApi()));
      await tester.tap(find.text('mở form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('program-name')), 'x');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('program-discard')));
      await tester.pumpAndSettle();
      expect(find.text('mở form'), findsOneWidget);
    });
  });

  group('Lịch tuần', () {
    Widget app(_FakeScheduleApi api, Widget home) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        scheduleApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(home: home),
    );

    testWidgets('Tải đúng tuần, nhóm theo ngày, chuyển tuần trước/sau', (tester) async {
      final now = today();
      final monday = weekStart(now);
      final api = _FakeScheduleApi([
        _schedule('s1', now, time: '18:00'),
        _schedule('s2', addDays(monday, 7)),
      ]);
      await tester.pumpWidget(app(api, const ScheduleWeekPage()));
      await tester.pumpAndSettle();

      expect(api.ranges, ['${isoDate(monday)}..${isoDate(addDays(monday, 6))}']);
      expect(find.text('Hôm nay'), findsOneWidget);
      final todaySection = find.byKey(Key('day-${isoDate(now)}'));
      expect(
        find.descendant(of: todaySection, matching: find.text('18:00')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('week-today')), findsNothing);

      await tester.tap(find.byKey(const Key('week-next')));
      await tester.pumpAndSettle();
      expect(api.ranges.last, startsWith(isoDate(addDays(monday, 7))));
      expect(find.byKey(const Key('schedule-s2')), findsOneWidget);
      expect(find.text('Cả ngày'), findsOneWidget);

      await tester.tap(find.byKey(const Key('week-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('week-prev')));
      await tester.pumpAndSettle();
      expect(api.ranges.last, startsWith(isoDate(addDays(monday, -7))));
      expect(find.byKey(const Key('week-empty')), findsOneWidget);
    });

    testWidgets('Hủy lịch có xác nhận; sau hủy không còn nút sửa', (tester) async {
      final api = _FakeScheduleApi([_schedule('s1', addDays(today(), 1))]);
      await tester.pumpWidget(app(api, const ScheduleDetailPage(id: 's1')));
      await tester.pumpAndSettle();
      expect(find.text('Đã xếp'), findsOneWidget);
      expect(find.text('3 hiệp × 10 lần · nghỉ 90 giây'), findsOneWidget);

      await tester.tap(find.byKey(const Key('schedule-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(api.updates, isEmpty);

      await tester.tap(find.byKey(const Key('schedule-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-cancel-confirm')));
      await tester.pumpAndSettle();
      expect(api.updates, [ScheduleStatus.cancelled]);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.byKey(const Key('schedule-cancel')), findsNothing);
      expect(find.byKey(const Key('schedule-reschedule')), findsNothing);
    });
  });
}
