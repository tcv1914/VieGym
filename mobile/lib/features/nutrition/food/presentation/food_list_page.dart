import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/logout_button.dart';
import '../../../workout/workout_widgets.dart';
import '../application/food_list_controller.dart';
import 'food_detail_page.dart';
import 'food_widgets.dart';

/// Tab "Món ăn": tìm không dấu, lọc danh mục/vùng, tải thêm khi cuộn.
/// Ngày 10 sẽ mở màn này để chọn món (trả foodId); hôm nay chỉ tra cứu.
class FoodListPage extends ConsumerStatefulWidget {
  const FoodListPage({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Món ăn'),
        actions: [
          IconButton(
            key: const Key('food-filter'),
            tooltip: 'Bộ lọc',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: q.filterCount > 0,
              label: Text('${q.filterCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('food-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _searchNow,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Tìm món, ví dụ: pho bo',
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
          if (q.filterCount > 0)
            SizedBox(
              height: 48,
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
                      ),
                      onDeleted: () =>
                          _controller.setQuery(q.withFilters(region: q.region)),
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Số liệu cho 1 phần ăn theo Viện Dinh dưỡng Quốc gia (không phải 100 g).',
              key: Key('food-basis-note'),
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _body(FoodListState state) {
    if (state.loadingFirst) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.firstError != null) {
      return ErrorRetry(error: state.firstError!, onRetry: _controller.refresh);
    }
    if (state.items.isEmpty) {
      return StatusMessage(
        key: const Key('food-empty'),
        icon: Icons.search_off,
        text: 'Không tìm thấy món phù hợp.',
        action: state.query.isEmpty
            ? null
            : TextButton(
                key: const Key('food-clear-all'),
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
          final f = state.items[index];
          return ListTile(
            key: Key('food-${f.id}'),
            leading: FoodImage(url: f.imageUrl),
            title: Text(f.name),
            subtitle: Text(
              '${kcalText(f.kcal)} / ${servingText(f)}\n'
              '${[f.region?.name, f.code].whereType<String>().join(' · ')}',
            ),
            isThreeLine: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FoodDetailPage(id: f.id, title: f.name),
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
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          state.hasNext
              ? 'Đang hiển thị ${state.items.length}/${state.totalItems} món'
              : 'Đã hiển thị hết ${state.totalItems} món',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
