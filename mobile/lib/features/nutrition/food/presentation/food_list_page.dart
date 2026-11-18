import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/gym_ui.dart';
import '../../../auth/presentation/logout_button.dart';
import '../../../workout/workout_widgets.dart';
import '../application/food_list_controller.dart';
import '../data/food_models.dart';
import 'food_detail_page.dart';
import 'food_widgets.dart';

/// Tab "Món ăn": tìm không dấu, lọc danh mục/vùng, tải thêm khi cuộn.
/// Có [onPick] (thực đơn ngày 10): chạm món → trả món đã chọn thay vì mở chi tiết.
class FoodListPage extends ConsumerStatefulWidget {
  const FoodListPage({super.key, this.onPick, this.title = 'Món ăn'});

  final ValueChanged<FoodSummary>? onPick;
  final String title;

  static const searchDebounce = Duration(milliseconds: 400);

  @override
  ConsumerState<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends ConsumerState<FoodListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  FoodListController get _controller => ref.read(foodListProvider.notifier);

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
      FoodListPage.searchDebounce,
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
    final filters = ref.read(foodFiltersProvider).value;
    if (filters == null) {
      ref.invalidate(foodFiltersProvider);
      showSnack(context, 'Chưa tải được danh mục lọc, vui lòng thử lại.');
      return;
    }
    _debounce?.cancel();
    final current = ref.read(foodListProvider).query.withKeyword(_search.text);
    final next = await showFoodFilterSheet(
      context,
      filters: filters,
      current: current,
    );
    if (next != null) _controller.setQuery(next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodListProvider);
    final filters = ref.watch(foodFiltersProvider).value;
    final q = state.query;
    final scheme = Theme.of(context).colorScheme;

    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'ẨM THỰC & DINH DƯỠNG VIỆT',
        title: widget.title,
        actions: [
          GymGlassAction(
            child: IconButton(
              key: const Key('food-filter'),
              tooltip: 'Bộ lọc',
              visualDensity: VisualDensity.compact,
              onPressed: _openFilters,
              icon: Badge(
                backgroundColor: GymColors.accentLime,
                textColor: GymColors.heroDark,
                isLabelVisible: q.filterCount > 0,
                label: Text(
                  '${q.filterCount}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          if (widget.onPick == null)
            const GymGlassAction(child: LogoutButton()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              key: const Key('food-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _searchNow,
              maxLength: 100,
              decoration: gymInputDecoration(
                context,
                hintText: 'Tìm món ăn Việt (vd: phở bò, cơm tấm...)',
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
          if (q.filterCount > 0)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (q.region != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(
                          filters?.regionLabel(q.region!) ?? q.region!,
                          style: const TextStyle(
                            color: GymColors.heroMid,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: GymColors.vibrantGreen.withValues(
                          alpha: 0.14,
                        ),
                        deleteIcon: const Icon(Icons.clear, size: 18),
                        deleteIconColor: GymColors.heroMid,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onDeleted: () => _controller.setQuery(
                          q.withFilters(category: q.category),
                        ),
                      ),
                    ),
                  if (q.category != null)
                    InputChip(
                      label: Text(
                        filters?.categoryLabel(q.category!) ?? q.category!,
                        style: const TextStyle(
                          color: GymColors.heroMid,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: GymColors.vibrantGreen.withValues(
                        alpha: 0.14,
                      ),
                      deleteIcon: const Icon(Icons.clear, size: 18),
                      deleteIconColor: GymColors.heroMid,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onDeleted: () =>
                          _controller.setQuery(q.withFilters(region: q.region)),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Số liệu cho 1 phần ăn theo Viện Dinh dưỡng Quốc gia (không phải 100 g).',
                    key: const Key('food-basis-note'),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _body(FoodListState state) {
    final scheme = Theme.of(context).colorScheme;
    if (state.loadingFirst) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.firstError != null) {
      return ErrorRetry(error: state.firstError!, onRetry: _controller.refresh);
    }
    if (state.items.isEmpty) {
      return StatusMessage(
        key: const Key('food-empty'),
        icon: Icons.search_off_rounded,
        text: 'Không tìm thấy món phù hợp.',
        action: state.query.isEmpty
            ? null
            : FilledButton.tonalIcon(
                key: const Key('food-clear-all'),
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
          final f = state.items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GymCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: Key('food-${f.id}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: FoodImage(url: f.imageUrl, size: 58),
                title: Text(
                  f.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${kcalText(f.kcal)} / ${servingText(f)}\n'
                    '${[f.region?.name, f.code].whereType<String>().join(' · ')}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
                isThreeLine: true,
                trailing: widget.onPick == null
                    ? Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      )
                    : IconButton(
                        key: Key('food-info-${f.id}'),
                        tooltip: 'Xem chi tiết',
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          color: GymColors.vibrantGreen,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FoodDetailPage(id: f.id, title: f.name),
                          ),
                        ),
                      ),
                onTap: widget.onPick != null
                    ? () => widget.onPick!(f)
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FoodDetailPage(id: f.id, title: f.name),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _footer(FoodListState state) {
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
              key: const Key('food-load-more-retry'),
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
          color: GymColors.flameOrange,
          icon: Icons.restaurant_menu_rounded,
          label: state.hasNext
              ? 'Đang hiển thị ${state.items.length}/${state.totalItems} món'
              : 'Đã hiển thị hết ${state.totalItems} món',
        ),
      ),
    );
  }
}
