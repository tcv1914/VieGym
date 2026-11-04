import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/workout_widgets.dart';
import '../application/food_list_controller.dart';
import '../data/food_models.dart';
import 'food_widgets.dart';

/// Chi tiết món: khẩu phần, kcal/P/C/F của đúng khẩu phần đó, nguồn và nhãn dữ liệu.
/// Chưa có nút thêm vào bữa (ngày 10).
class FoodDetailPage extends ConsumerWidget {
  const FoodDetailPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final food = ref.watch(foodDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: food.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(foodDetailProvider(id)),
        ),
        data: (d) => _FoodDetailView(food: d),
      ),
    );
  }
}

class _FoodDetailView extends StatelessWidget {
  const _FoodDetailView({required this.food});

  final FoodDetail food;

  @override
  Widget build(BuildContext context) {
    final f = food.summary;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(child: FoodImage(url: f.imageUrl, size: null)),
        const SizedBox(height: 12),
        Text(f.name, style: theme.textTheme.titleLarge),
        if (food.nameEn != null)
          Text(food.nameEn!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          [
            f.category.name,
            f.region == null ? null : 'Vùng đo: ${f.region!.name}',
            'Mã ${f.code}',
          ].whereType<String>().join(' · '),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khẩu phần: ${servingText(f)}',
                  key: const Key('food-serving'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  kcalText(f.kcal),
                  key: const Key('food-kcal'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _row('Chất đạm (protein)', gramText(f.protein)),
                _row('Chất bột đường (carb)', gramText(f.carbs)),
                _row('Chất béo (fat)', gramText(f.fat)),
                if (f.servingSize == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Nguồn chỉ công bố số liệu cho 1 phần như ảnh, không ghi khối lượng; '
                      'cùng tên món ở vùng/quán khác có thể là phần ăn khác.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Chất lượng dữ liệu: ${dataQualityLabel(f.dataQuality)}'),
        const SizedBox(height: 4),
        Text('Nguồn: ${food.source}', key: const Key('food-source')),
        if (food.sourceUrl != null)
          SelectableText(food.sourceUrl!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Ảnh thuộc bản quyền của nguồn, tải trực tiếp từ trang của Viện.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}
