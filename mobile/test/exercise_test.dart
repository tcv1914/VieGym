import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/token_store.dart';
import 'package:mobile/features/exercise/application/exercise_list_controller.dart';
import 'package:mobile/features/exercise/data/exercise_api.dart';
import 'package:mobile/features/exercise/data/exercise_models.dart';
import 'package:mobile/features/exercise/presentation/exercise_list_page.dart';

class _MemoryTokenStore implements TokenStore {
  String? refresh;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveRefresh(String token) async => refresh = token;

  @override
  Future<void> clear() async => refresh = null;
}

/// Đã đăng nhập sẵn, không gọi backend khi khôi phục phiên.
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

http.Response _json(int status, Object? body) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _item(String id, {String? thumb}) => {
  'id': id,
  'name': 'Bài $id',
  'muscleGroup': 'CHEST',
  'equipment': 'DUMBBELL',
  'difficulty': 'BEGINNER',
  'thumbnailUrl': thumb,
};

Map<String, dynamic> _page(
  List<String> ids, {
  int page = 0,
  int total = 0,
  bool hasNext = false,
}) => {
  'items': [for (final id in ids) _item(id)],
  'page': page,
  'size': 20,
  'totalItems': total == 0 ? ids.length : total,
  'totalPages': 1,
  'hasNext': hasNext,
};

const _filtersJson = {
  'muscleGroups': [
    {'code': 'CHEST', 'name': 'Ngực'},
    {'code': 'BACK', 'name': 'Lưng'},
  ],
  'equipment': [
    {'code': 'DUMBBELL', 'name': 'Tạ đơn'},
  ],
  'difficulties': [
    {'code': 'BEGINNER', 'name': 'Cơ bản'},
  ],
};

/// Đăng nhập với backend giả rồi trả ExerciseApi dùng chung phiên đó.
Future<ExerciseApi> _exerciseApi(
  Future<http.Response> Function(http.Request) handler,
) async {
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
  return ExerciseApi(auth);
}

ProviderContainer _container(ExerciseApi api) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_SignedIn.new),
      exerciseApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Chờ đăng nhập giả xong và controller tải xong trang đầu.
Future<ProviderContainer> _ready(ExerciseApi api) async {
  final container = _container(api);
  await container.read(authControllerProvider.future);
  container.listen(exerciseListProvider, (_, _) {});
  await pumpEventQueue();
  return container;
}

void main() {
  test('Chi tiết tách mỗi dòng thành một bước, bỏ dòng trống', () {
    final d = ExerciseDetail.fromJson({
      ..._item('e1'),
      'instructions': 'Bước 1\n\n  Bước 2  \n',
      'commonMistakes': 'Lỗi A',
      'mediaType': 'GIF',
      'mediaUrl': 'http://127.0.0.1:8080/media/exercises/a.gif',
      'contentSource': 'VieGym',
      'mediaLicense': '© Gym visual',
    });
    expect(d.steps, ['Bước 1', 'Bước 2']);
    expect(d.commonMistakes, ['Lỗi A']);
    expect(d.hasImageMedia, isTrue);
    expect(
      ExerciseDetail.fromJson({..._item('e2'), 'instructions': 'x'})
          .hasImageMedia,
      isFalse,
    );
  });

  test(
    'Query encode keyword có dấu và ký tự đặc biệt, bỏ tham số trống',
    () async {
      late Uri sent;
      final api = await _exerciseApi((request) async {
        sent = request.url;
        return _json(200, _page([]));
      });
      await api.search(
        const ExerciseQuery(keyword: '  đẩy ngực & 50% ', muscleGroup: 'CHEST'),
        page: 2,
      );
      expect(sent.path, '/api/v1/exercises');
      expect(sent.queryParameters, {
        'keyword': 'đẩy ngực & 50%',
        'muscleGroup': 'CHEST',
        'page': '2',
        'size': '20',
      });
    },
  );

  test('Response của truy vấn cũ về muộn không ghi đè truy vấn mới', () async {
    final slow = Completer<http.Response>();
    final api = await _exerciseApi((request) {
      final keyword = request.url.queryParameters['keyword'];
      if (keyword == 'cu') return slow.future;
      return Future.value(
        _json(200, _page(keyword == 'moi' ? ['moi'] : ['all'])),
      );
    });
    final container = await _ready(api);
    final controller = container.read(exerciseListProvider.notifier);

    controller.setKeyword('cu');
    controller.setKeyword('moi');
    await pumpEventQueue();
    slow.complete(_json(200, _page(['cu'])));
    await pumpEventQueue();

    final state = container.read(exerciseListProvider);
    expect(state.query.keyword, 'moi');
    expect(state.items.map((e) => e.id), ['moi']);
  });

  test('Lỗi tải trang sau giữ bài cũ; thử lại không nhân đôi', () async {
    var failNext = true;
    final api = await _exerciseApi((request) async {
      final page = int.parse(request.url.queryParameters['page']!);
      if (page == 0) {
        return _json(200, _page(['a', 'b'], total: 3, hasNext: true));
      }
      if (failNext) {
        failNext = false;
        throw http.ClientException('offline');
      }
      return _json(200, _page(['c'], page: 1, total: 3));
    });
    final container = await _ready(api);
    final controller = container.read(exerciseListProvider.notifier);

    await controller.loadMore();
    var state = container.read(exerciseListProvider);
    expect(state.items.map((e) => e.id), ['a', 'b']);
    expect(state.moreError, isA<NetworkException>());

    // Gọi hai lần liền: lần thứ hai bị chặn vì đang tải.
    await Future.wait([controller.loadMore(), controller.loadMore()]);
    state = container.read(exerciseListProvider);
    expect(state.items.map((e) => e.id), ['a', 'b', 'c']);
    expect(state.moreError, isNull);
    expect(state.hasNext, isFalse);
  });

  test('Đổi bộ lọc tải lại từ trang 0 và bỏ danh sách cũ', () async {
    final pages = <String>[];
    final api = await _exerciseApi((request) async {
      final q = request.url.queryParameters;
      pages.add('${q['muscleGroup']}:${q['page']}');
      return _json(200, _page([q['muscleGroup'] ?? 'all'], hasNext: true));
    });
    final container = await _ready(api);
    final controller = container.read(exerciseListProvider.notifier);
    await controller.loadMore();

    controller.setQuery(const ExerciseQuery().withFilters(muscleGroup: 'BACK'));
    expect(container.read(exerciseListProvider).items, isEmpty);
    await pumpEventQueue();

    expect(pages, ['null:0', 'null:1', 'BACK:0']);
    expect(container.read(exerciseListProvider).items.map((e) => e.id), [
      'BACK',
    ]);
  });

  group('Màn thư viện', () {
    Widget app(
      Future<http.Response> Function(http.Request) handler,
      ExerciseApi api,
    ) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        exerciseApiProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: ExerciseListPage()),
    );

    testWidgets('Gõ tìm chỉ gọi API sau khi ngừng gõ; rỗng có nút xóa lọc', (
      tester,
    ) async {
      final keywords = <String?>[];
      late ExerciseApi api;
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path == '/api/v1/exercise-filters') {
          return _json(200, _filtersJson);
        }
        final keyword = request.url.queryParameters['keyword'];
        keywords.add(keyword);
        return _json(200, _page(keyword == null ? ['e1'] : []));
      }

      await tester.runAsync(() async => api = await _exerciseApi(handler));
      await tester.pumpWidget(app(handler, api));
      await tester.pumpAndSettle();
      expect(find.text('Bài e1'), findsOneWidget);
      expect(find.text('Ngực · Tạ đơn · Cơ bản'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('exercise-search')), 'd');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('exercise-search')), 'day');
      await tester.pump(ExerciseListPage.searchDebounce);
      await tester.pumpAndSettle();

      expect(keywords, [null, 'day']);
      expect(find.text('Không tìm thấy bài tập phù hợp.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exercise-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('Bài e1'), findsOneWidget);
    });

    testWidgets(
      'Mở chi tiết: hiện các bước; không có media thì có thông báo thay thế',
      (tester) async {
        late ExerciseApi api;
        Future<http.Response> handler(http.Request request) async {
          if (request.url.path == '/api/v1/exercise-filters') {
            return _json(200, _filtersJson);
          }
          if (request.url.path == '/api/v1/exercises/e1') {
            return _json(200, {
              ..._item('e1'),
              'instructions': 'Nằm ngửa\nĐẩy tạ lên',
              'commonMistakes': 'Nảy tạ',
              'mediaType': null,
              'mediaUrl': null,
            });
          }
          return _json(200, _page(['e1']));
        }

        await tester.runAsync(() async => api = await _exerciseApi(handler));
        await tester.pumpWidget(app(handler, api));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bài e1'));
        await tester.pumpAndSettle();
        expect(find.text('Đẩy tạ lên'), findsOneWidget);
        expect(find.text('Nảy tạ'), findsOneWidget);
        expect(find.text('Bài này chưa có hình minh họa'), findsOneWidget);

        // Quay lại vẫn còn danh sách, không tải lại từ đầu.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Bài e1'), findsOneWidget);
      },
    );

    testWidgets('Bài đã ẩn khi mở chi tiết: báo không còn khả dụng', (
      tester,
    ) async {
      late ExerciseApi api;
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path == '/api/v1/exercise-filters') {
          return _json(200, _filtersJson);
        }
        if (request.url.path == '/api/v1/exercises/e1') {
          return _json(404, {
            'code': 'NOT_FOUND',
            'message': 'Bài tập không tồn tại hoặc đã ngừng hiển thị',
          });
        }
        return _json(200, _page(['e1']));
      }

      await tester.runAsync(() async => api = await _exerciseApi(handler));
      await tester.pumpWidget(app(handler, api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài e1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bài tập không tồn tại hoặc đã ngừng hiển thị'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
