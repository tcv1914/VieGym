import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/gym_ui.dart';
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

    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'KHO ĐỘNG TÁC TẬP LUYỆN',
        title: 'Thư viện bài tập',
        actions: [
          GymGlassAction(
            child: IconButton(
              key: const Key('exercise-filter'),
              tooltip: 'Bộ lọc',
              visualDensity: VisualDensity.compact,
              onPressed: _openFilters,
              icon: Badge(
                backgroundColor: GymColors.accentLime,
                textColor: GymColors.heroDark,
                isLabelVisible: filterCount > 0,
                label: Text(
                  '$filterCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          const GymGlassAction(child: LogoutButton()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('exercise-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _searchNow,
              maxLength: 100,
              decoration: gymInputDecoration(
                context,
                hintText: 'Tìm theo tên Việt hoặc Anh (vd: đẩy ngực, bench...)',
                prefixIcon: Icons.search_rounded,
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
                          icon: const Icon(Icons.clear_rounded, size: 20),
                        ),
                ),
              ).copyWith(counterText: ''),
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
    final scheme = Theme.of(context).colorScheme;
    if (state.loadingFirst) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.firstError != null) {
      return GymStateView(
        icon: Icons.error_outline_rounded,
        accent: scheme.error,
        message: state.firstError.toString(),
        action: FilledButton.icon(
          onPressed: _controller.refresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Thử lại'),
        ),
      );
    }
    if (state.items.isEmpty) {
      return GymStateView(
        icon: Icons.search_off_rounded,
        message: 'Không tìm thấy bài tập phù hợp.',
        action: state.query.isEmpty
            ? null
            : FilledButton.tonalIcon(
                key: const Key('exercise-clear-all'),
                onPressed: _clearAll,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Xóa tìm kiếm và bộ lọc'),
              ),
      );
    }

    return RefreshIndicator(
      color: GymColors.vibrantGreen,
      onRefresh: _controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index == state.items.length) return _footer(state);
          final e = state.items[index];
          final diffColor = GymColors.difficultyColor(e.difficulty);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GymCard(
              cardKey: Key('exercise-${e.id}'),
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExerciseDetailPage(id: e.id, title: e.name),
                ),
              ),
              child: Row(
                children: [
                  ExerciseThumbnail(url: e.thumbnailUrl, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: diffColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  filters?.muscleGroupLabel(e.muscleGroup) ??
                                      e.muscleGroup,
                                  filters?.equipmentLabel(e.equipment) ??
                                      e.equipment,
                                  filters?.difficultyLabel(e.difficulty) ??
                                      e.difficulty,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: GymPill(
          icon: Icons.check_circle_outline_rounded,
          label: state.hasNext
              ? 'Đang hiển thị ${state.items.length}/${state.totalItems} bài'
              : 'Đã hiển thị hết ${state.totalItems} bài',
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
      height: 44,
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
    child: InputChip(
      label: Text(
        label,
        style: const TextStyle(
          color: GymColors.heroMid,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
      backgroundColor: GymColors.vibrantGreen.withValues(alpha: 0.14),
      deleteIconColor: GymColors.heroMid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onDeleted: onDeleted,
    ),
  );
}
