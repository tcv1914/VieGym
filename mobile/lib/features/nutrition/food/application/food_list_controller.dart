import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_models.dart';
import '../data/food_api.dart';
import '../data/food_models.dart';

class FoodListState {
  const FoodListState({
    this.query = const FoodQuery(),
    this.items = const [],
    this.totalItems = 0,
    this.nextPage = 0,
    this.hasNext = false,
    this.loadingFirst = true,
    this.firstError,
    this.loadingMore = false,
    this.moreError,
  });

  final FoodQuery query;
  final List<FoodSummary> items;
  final int totalItems;
  final int nextPage;
  final bool hasNext;
  final bool loadingFirst;
  final Object? firstError;

  /// Lỗi tải trang sau không xóa các món đã có.
  final bool loadingMore;
  final Object? moreError;

  FoodListState copyWith({
    List<FoodSummary>? items,
    int? totalItems,
    int? nextPage,
    bool? hasNext,
    bool? loadingFirst,
    Object? firstError,
    bool? loadingMore,
    Object? moreError,
  }) => FoodListState(
    query: query,
    items: items ?? this.items,
    totalItems: totalItems ?? this.totalItems,
    nextPage: nextPage ?? this.nextPage,
    hasNext: hasNext ?? this.hasNext,
    loadingFirst: loadingFirst ?? this.loadingFirst,
    firstError: firstError,
    loadingMore: loadingMore ?? this.loadingMore,
    moreError: moreError,
  );
}

/// Như danh sách bài tập ngày 6: mỗi lần đổi truy vấn tăng [_generation]; response cũ về
/// muộn bị bỏ qua, không ghi đè kết quả mới. Đổi truy vấn → về trang đầu.
class FoodListController extends Notifier<FoodListState> {
  int _generation = 0;

  FoodApi get _api => ref.read(foodApiProvider);

  @override
  FoodListState build() {
    final auth = ref.watch(authControllerProvider).value;
    _generation++;
    if (auth is! Authenticated) {
      return const FoodListState(
        loadingFirst: false,
        firstError: SessionExpiredException(),
      );
    }
    final generation = _generation;
    Future.microtask(() => _loadFirst(generation));
    return const FoodListState();
  }

  void setQuery(FoodQuery query) {
    if (query == state.query && state.firstError == null) return;
    final generation = ++_generation;
    state = FoodListState(query: query);
    _loadFirst(generation);
  }

  void setKeyword(String keyword) => setQuery(state.query.withKeyword(keyword));

  void clearQuery() => setQuery(const FoodQuery());

  Future<void> refresh() {
    final generation = ++_generation;
    state = FoodListState(query: state.query);
    return _loadFirst(generation);
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.loadingFirst || s.loadingMore || !s.hasNext || s.firstError != null) {
      return;
    }
    final generation = _generation;
    state = s.copyWith(loadingMore: true);
    try {
      final page = await _api.search(s.query, page: s.nextPage);
      if (!_isCurrent(generation)) return;
      final seen = state.items.map((e) => e.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...page.items.where((e) => seen.add(e.id))],
        totalItems: page.totalItems,
        nextPage: s.nextPage + 1,
        hasNext: page.hasNext,
        loadingMore: false,
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(loadingMore: false, moreError: e);
    }
  }

  Future<void> _loadFirst(int generation) async {
    try {
      final page = await _api.search(state.query, page: 0);
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        items: page.items,
        totalItems: page.totalItems,
        nextPage: 1,
        hasNext: page.hasNext,
        loadingFirst: false,
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(loadingFirst: false, firstError: e);
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final foodListProvider =
    NotifierProvider.autoDispose<FoodListController, FoodListState>(
      FoodListController.new,
    );

final foodFiltersProvider = FutureProvider.autoDispose<FoodFilters>((ref) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth is! Authenticated) throw const SessionExpiredException();
  return ref.read(foodApiProvider).filters();
}, retry: (retryCount, error) => null);

final foodDetailProvider = FutureProvider.autoDispose
    .family<FoodDetail, String>((ref, id) {
      final auth = ref.watch(authControllerProvider).value;
      if (auth is! Authenticated) throw const SessionExpiredException();
      return ref.read(foodApiProvider).detail(id);
    }, retry: (retryCount, error) => null);
