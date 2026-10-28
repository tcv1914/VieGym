import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../data/exercise_api.dart';
import '../data/exercise_models.dart';

class ExerciseListState {
  const ExerciseListState({
    this.query = const ExerciseQuery(),
    this.items = const [],
    this.totalItems = 0,
    this.nextPage = 0,
    this.hasNext = false,
    this.loadingFirst = true,
    this.firstError,
    this.loadingMore = false,
    this.moreError,
  });

  final ExerciseQuery query;
  final List<ExerciseSummary> items;
  final int totalItems;
  final int nextPage;
  final bool hasNext;

  /// Đang tải trang đầu của [query]; danh sách cũ đã bị bỏ.
  final bool loadingFirst;
  final Object? firstError;

  /// Lỗi tải trang sau không xóa các bài đã có.
  final bool loadingMore;
  final Object? moreError;

  ExerciseListState copyWith({
    List<ExerciseSummary>? items,
    int? totalItems,
    int? nextPage,
    bool? hasNext,
    bool? loadingFirst,
    Object? firstError,
    bool? loadingMore,
    Object? moreError,
  }) => ExerciseListState(
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

/// Danh sách theo truy vấn hiện tại. Mỗi lần đổi truy vấn tăng [_generation]; response
/// của truy vấn cũ về muộn bị bỏ qua thay vì ghi đè kết quả mới.
class ExerciseListController extends Notifier<ExerciseListState> {
  int _generation = 0;

  ExerciseApi get _api => ref.read(exerciseApiProvider);

  @override
  ExerciseListState build() {
    // Đổi tài khoản/đăng xuất: dựng lại từ đầu, request của phiên trước không còn được ghi.
    final auth = ref.watch(authControllerProvider).value;
    _generation++;
    if (auth is! Authenticated) {
      return const ExerciseListState(
        loadingFirst: false,
        firstError: SessionExpiredException(),
      );
    }
    final generation = _generation;
    Future.microtask(() => _loadFirst(generation));
    return const ExerciseListState();
  }

  void setQuery(ExerciseQuery query) {
    if (query == state.query && state.firstError == null) return;
    final generation = ++_generation;
    state = ExerciseListState(query: query);
    _loadFirst(generation);
  }

  void setKeyword(String keyword) => setQuery(state.query.withKeyword(keyword));

  void clearQuery() => setQuery(const ExerciseQuery());

  /// Kéo để làm mới: tải lại trang đầu của truy vấn hiện tại.
  Future<void> refresh() {
    final generation = ++_generation;
    state = ExerciseListState(query: state.query);
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
      // Phòng dữ liệu đổi giữa hai lần tải: không thêm bài đã có.
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

final exerciseListProvider =
    NotifierProvider.autoDispose<ExerciseListController, ExerciseListState>(
      ExerciseListController.new,
    );

/// Danh mục lọc ít đổi; tải một lần mỗi phiên.
final exerciseFiltersProvider = FutureProvider.autoDispose<ExerciseFilters>((
  ref,
) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth is! Authenticated) {
    throw const SessionExpiredException();
  }
  return ref.read(exerciseApiProvider).filters();
}, retry: (retryCount, error) => null);

final exerciseDetailProvider = FutureProvider.autoDispose
    .family<ExerciseDetail, String>((ref, id) {
      final auth = ref.watch(authControllerProvider).value;
      if (auth is! Authenticated) {
        throw const SessionExpiredException();
      }
      return ref.read(exerciseApiProvider).detail(id);
    }, retry: (retryCount, error) => null);
