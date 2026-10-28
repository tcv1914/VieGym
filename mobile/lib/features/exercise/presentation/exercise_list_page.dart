import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/logout_button.dart';
import '../application/exercise_list_controller.dart';
import '../data/exercise_models.dart';
import 'exercise_detail_page.dart';
import 'exercise_filter_sheet.dart';
import 'exercise_media.dart';

class ExerciseListPage extends ConsumerStatefulWidget {
  const ExerciseListPage({super.key});

  /// Chờ người dùng ngừng gõ rồi mới gọi API.
  static const searchDebounce = Duration(milliseconds: 400);

  @override
  ConsumerState<ExerciseListPage> createState() => _ExerciseListPageState();
}

class _ExerciseListPageState extends ConsumerState<ExerciseListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  ExerciseListController get _controller =>
      ref.read(exerciseListProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _controller.loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      ExerciseListPage.searchDebounce,
      () => _controller.setKeyword(value),
    );
  }

  void _searchNow(String value) {
    _debounce?.cancel();
    _controller.setKeyword(value);
  }

  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    _controller.clearQuery();
  }

  Future<void> _openFilters() async {
    final filters = ref.read(exerciseFiltersProvider).value;
    if (filters == null) {
      ref.invalidate(exerciseFiltersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa tải được danh mục lọc, vui lòng thử lại.'),
        ),
      );
      return;
    }
    // Áp keyword đang gõ dở để bộ lọc không làm mất nó.
    _debounce?.cancel();
    final current = ref
        .read(exerciseListProvider)
        .query
        .withKeyword(_search.text);
    final next = await showExerciseFilterSheet(
      context,
      filters: filters,
      current: current,
    );
    if (next != null) _controller.setQuery(next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseListProvider);
    final filters = ref.watch(exerciseFiltersProvider).value;
    final filterCount = state.query.filterCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện bài tập'),
        actions: [
          IconButton(
            key: const Key('exercise-filter'),
            tooltip: 'Bộ lọc',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(Icons.filter_list),
            ),
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('exercise-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _searchNow,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, ví dụ: day nguc',
                prefixIcon: const Icon(Icons.search),
                counterText: '',
                border: const OutlineInputBorder(),
                suffixIcon: ListenableBuilder(
                  listenable: _search,
                  builder: (context, _) => _search.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Xóa',
                          onPressed: () {
                            _search.clear();
                            _searchNow('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
          ),
          if (filterCount > 0 && filters != null)
            _ActiveFilters(query: state.query, filters: filters),
          Expanded(child: _body(state, filters)),
        ],
      ),
    );
  }

  Widget _body(ExerciseListState state, ExerciseFilters? filters) {
    if (state.loadingFirst) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.firstError != null) {
      return _Message(
        icon: Icons.error_outline,
        text: state.firstError.toString(),
        action: TextButton(
          onPressed: _controller.refresh,
          child: const Text('Thử lại'),
        ),
      );
    }
    if (state.items.isEmpty) {
      return _Message(
        icon: Icons.search_off,
        text: 'Không tìm thấy bài tập phù hợp.',
        action: state.query.isEmpty
            ? null
            : TextButton(
                key: const Key('exercise-clear-all'),
                onPressed: _clearAll,
                child: const Text('Xóa tìm kiếm và bộ lọc'),
              ),
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index == state.items.length) return _footer(state);
          final e = state.items[index];
          return ListTile(
            key: Key('exercise-${e.id}'),
            leading: ExerciseThumbnail(url: e.thumbnailUrl),
            title: Text(e.name),
            subtitle: Text(
              [
                filters?.muscleGroupLabel(e.muscleGroup) ?? e.muscleGroup,
                filters?.equipmentLabel(e.equipment) ?? e.equipment,
                filters?.difficultyLabel(e.difficulty) ?? e.difficulty,
              ].join(' · '),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciseDetailPage(id: e.id, title: e.name),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _footer(ExerciseListState state) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.moreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(state.moreError.toString(), textAlign: TextAlign.center),
            TextButton(
              key: const Key('exercise-load-more-retry'),
              onPressed: _controller.loadMore,
              child: const Text('Tải lại trang sau'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          state.hasNext
              ? 'Đang hiển thị ${state.items.length}/${state.totalItems} bài'
              : 'Đã hiển thị hết ${state.totalItems} bài',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Bộ lọc đang áp dụng; bấm x để bỏ từng điều kiện.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.query, required this.filters});

  final ExerciseQuery query;
  final ExerciseFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(exerciseListProvider.notifier);
    final m = query.muscleGroup;
    final e = query.equipment;
    final d = query.difficulty;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (m != null)
            _chip(
              filters.muscleGroupLabel(m),
              () => controller.setQuery(
                query.withFilters(equipment: e, difficulty: d),
              ),
            ),
          if (e != null)
            _chip(
              filters.equipmentLabel(e),
              () => controller.setQuery(
                query.withFilters(muscleGroup: m, difficulty: d),
              ),
            ),
          if (d != null)
            _chip(
              filters.difficultyLabel(d),
              () => controller.setQuery(
                query.withFilters(muscleGroup: m, equipment: e),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InputChip(label: Text(label), onDeleted: onDeleted),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }
}
