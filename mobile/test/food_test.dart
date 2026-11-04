import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/format/number_format.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/nutrition/food/application/food_list_controller.dart';
import 'package:mobile/features/nutrition/food/data/food_api.dart';
import 'package:mobile/features/nutrition/food/data/food_models.dart';
import 'package:mobile/features/nutrition/food/presentation/food_detail_page.dart';
import 'package:mobile/features/nutrition/food/presentation/food_list_page.dart';
import 'package:mobile/features/nutrition/food/presentation/food_widgets.dart';

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

Map<String, dynamic> _foodJson(
  String id, {
  String name = 'Phở bò tái 24h',
  Object kcal = 314,
  Object? servingSize,
  String? image = 'https://viendinhduong.vn/storage/a.webp',
}) => {
  'id': id,
  'code': 'VPF-$id',
  'name': name,
  'category': {'code': 'BANH_DA_BUN_PHO', 'name': 'Bánh đa, bún, phở'},
  'region': {'code': 'VPF', 'name': 'Toàn quốc'},
  'servingDescription': '1 phần ăn theo nguồn',
  'servingSize': servingSize,
  'servingUnit': servingSize == null ? null : 'g',
  'kcalPerServing': kcal,
  'proteinPerServing': 20.5,
  'carbsPerServing': 40,
  'fatPerServing': 6.25,
  'dataQuality': 'SOURCED',
  'imageUrl': image,
};

FoodPage _page(List<String> ids, {bool hasNext = false, int total = 0}) =>
    FoodPage(
      items: [for (final id in ids) FoodSummary.fromJson(_foodJson(id))],
      totalItems: total == 0 ? ids.length : total,
      hasNext: hasNext,
    );

class _FakeFoodApi implements FoodApi {
  final calls = <String>[];

  /// Nếu có, request với keyword tương ứng chờ completer này.
  final pending = <String, Completer<FoodPage>>{};
  Object? failPage;

  @override
  Future<FoodPage> search(
    FoodQuery query, {
    required int page,
    int size = FoodApi.pageSize,
  }) async {
    calls.add('${query.keyword}|${query.category}|${query.region}|$page');
    final c = pending[query.keyword];
    if (c != null) return c.future;
    if (failPage == page) {
      failPage = null;
      throw const NetworkException();
    }
    if (query.keyword == 'khong co') return _page([]);
    return _page(
      ['${query.keyword}$page-a', '${query.keyword}$page-b'],
      hasNext: page < 1,
      total: 4,
    );
  }

  @override
  Future<FoodDetail> detail(String id) async => FoodDetail.fromJson({
    ..._foodJson(id),
    'nameEn': 'Rare beef pho',
    'source': 'Viện Dinh dưỡng Quốc gia — Tra cứu giá trị dinh dưỡng món ăn, mã VPF-000272',
    'sourceUrl': 'https://viendinhduong.vn/vi/cong-cu',
    'revision': 1,
  });

  @override
  Future<FoodFilters> filters() async => FoodFilters.fromJson({
    'categories': [
      {'code': 'BANH_DA_BUN_PHO', 'name': 'Bánh đa, bún, phở'},
    ],
    'regions': [
      {'code': 'VPF', 'name': 'Toàn quốc'},
      {'code': 'HAN', 'name': 'Hà Nội'},
    ],
  });
}

ProviderContainer _container(_FakeFoodApi api) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_SignedIn.new),
    foodApiProvider.overrideWithValue(api),
  ],
);

Widget _app(_FakeFoodApi api, Widget home) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_SignedIn.new),
    foodApiProvider.overrideWithValue(api),
  ],
  child: MaterialApp(home: home),
);

void main() {
  group('Dữ liệu món', () {
    test('Đọc số nguyên/số lẻ, khẩu phần không có gram', () {
      final f = FoodSummary.fromJson(_foodJson('1', kcal: 355.3));
      expect(f.kcal, 355.3);
      expect(f.servingSize, isNull);
      expect(kcalText(f.kcal), '355,3 kcal');
      expect(servingText(f), '1 phần ăn theo nguồn');
      expect(macroLine(f), 'Đạm 20,5 g · Bột đường 40 g · Béo 6,25 g');
      final withGrams = FoodSummary.fromJson(_foodJson('2', servingSize: 500));
      expect(servingText(withGrams), '1 phần ăn theo nguồn (500 g)');
      expect(
        FoodSummary.fromJson(_foodJson('3', image: null)).imageUrl,
        isNull,
      );
    });

    test('Định dạng số gọn', () {
      expect(formatViCompact(314), '314');
      expect(formatViCompact(355.3), '355,3');
      expect(formatViCompact(12.25), '12,25');
      expect(formatViCompact(1200.5, maxDecimals: 1), '1.200,5');
    });

    test('Query bỏ tham số trống, so sánh bỏ khoảng trắng', () {
      const q = FoodQuery(keyword: ' pho ', region: 'HAN');
      expect(q.toQueryParameters(page: 0, size: 20), {
        'keyword': 'pho',
        'region': 'HAN',
        'page': '0',
        'size': '20',
      });
      expect(q == const FoodQuery(keyword: 'pho', region: 'HAN'), isTrue);
    });
  });

  group('Danh sách món', () {
    test(
      'Response của truy vấn cũ về muộn không ghi đè truy vấn mới',
      () async {
        final api = _FakeFoodApi();
        final slow = Completer<FoodPage>();
        api.pending['cu'] = slow;
        final c = _container(api);
        addTearDown(c.dispose);
        final sub = c.listen(foodListProvider, (_, _) {});
        addTearDown(sub.close);
        await Future<void>.delayed(Duration.zero);

        c.read(foodListProvider.notifier).setKeyword('cu');
        c.read(foodListProvider.notifier).setKeyword('moi');
        await Future<void>.delayed(Duration.zero);
        slow.complete(_page(['cu-x']));
        await Future<void>.delayed(Duration.zero);

        final s = c.read(foodListProvider);
        expect(s.query.keyword, 'moi');
        expect(s.items.map((e) => e.id), ['moi0-a', 'moi0-b']);
      },
    );

    test('Lỗi trang sau giữ món cũ; thử lại không nhân đôi', () async {
      final api = _FakeFoodApi()..failPage = 1;
      final c = _container(api);
      addTearDown(c.dispose);
      final sub = c.listen(foodListProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final ctrl = c.read(foodListProvider.notifier);

      await ctrl.loadMore();
      expect(c.read(foodListProvider).items, hasLength(2));
      expect(c.read(foodListProvider).moreError, isA<NetworkException>());

      await ctrl.loadMore();
      final s = c.read(foodListProvider);
      expect(s.items.map((e) => e.id), ['0-a', '0-b', '1-a', '1-b']);
      expect(s.hasNext, isFalse);
    });

    testWidgets(
      'Gõ tìm sau debounce; thẻ ghi rõ kcal theo khẩu phần; rỗng có nút xóa',
      (tester) async {
        final api = _FakeFoodApi();
        await tester.pumpWidget(_app(api, const FoodListPage()));
        await tester.pumpAndSettle();
        expect(
          find.text('314 kcal / 1 phần ăn theo nguồn\nToàn quốc · VPF-0-a'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('food-basis-note')), findsOneWidget);

        await tester.enterText(find.byKey(const Key('food-search')), 'kh');
        await tester.enterText(
          find.byKey(const Key('food-search')),
          'khong co',
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(api.calls.where((c) => c.startsWith('kh')), isEmpty);
        await tester.pump(FoodListPage.searchDebounce);
        await tester.pumpAndSettle();
        expect(api.calls.where((c) => c.startsWith('kh')), [
          'khong co|null|null|0',
        ]);
        expect(find.byKey(const Key('food-empty')), findsOneWidget);

        await tester.tap(find.byKey(const Key('food-clear-all')));
        await tester.pumpAndSettle();
        expect(find.text('Phở bò tái 24h'), findsWidgets);
      },
    );

    testWidgets('Lọc vùng: gọi lại trang 0 với region, có chip bỏ lọc', (
      tester,
    ) async {
      final api = _FakeFoodApi();
      await tester.pumpWidget(_app(api, const FoodListPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-region-HAN')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('food-filter-apply')));
      await tester.pumpAndSettle();
      expect(api.calls.last, '|null|HAN|0');
      expect(find.widgetWithText(InputChip, 'Hà Nội'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Hà Nội'),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls.last, '|null|null|0');
    });
  });

  group('Chi tiết món', () {
    testWidgets('Ảnh lỗi vẫn hiện đủ khẩu phần, P/C/F, nguồn, nhãn dữ liệu', (
      tester,
    ) async {
      // Trong test, mọi Image.network đều lỗi (HTTP 400) → kiểm tra fallback (F08).
      await tester.pumpWidget(
        _app(_FakeFoodApi(), const FoodDetailPage(id: '1', title: 'Phở')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('food-image-placeholder')), findsOneWidget);
      expect(find.text('Khẩu phần: 1 phần ăn theo nguồn'), findsOneWidget);
      expect(find.text('314 kcal'), findsOneWidget);
      expect(find.text('20,5 g'), findsOneWidget);
      expect(find.text('6,25 g'), findsOneWidget);
      expect(find.textContaining('không ghi khối lượng'), findsOneWidget);
      expect(
        find.text('Chất lượng dữ liệu: Theo nguồn công bố'),
        findsOneWidget,
      );
      expect(find.textContaining('mã VPF-000272'), findsOneWidget);
    });
  });
}
