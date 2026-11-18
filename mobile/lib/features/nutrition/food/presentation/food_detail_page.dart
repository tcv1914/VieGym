import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/gym_ui.dart';
import '../../../workout/workout_widgets.dart';
import '../application/food_list_controller.dart';
import '../data/food_models.dart';
import 'food_widgets.dart';

/// Chi tiết món: khẩu phần, kcal/P/C/F của đúng khẩu phần đó, nguồn và nhãn dữ liệu.
class FoodDetailPage extends ConsumerWidget {
  const FoodDetailPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final food = ref.watch(foodDetailProvider(id));
    return GymScaffold(
      appBar: GymAppBar(eyebrow: 'THÔNG TIN DINH DƯỠNG', title: title),
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
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        GymCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: FoodImage(url: f.imageUrl, size: null)),
              const SizedBox(height: 16),
              Text(
                f.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (food.nameEn != null) ...[
                const SizedBox(height: 2),
                Text(
                  food.nameEn!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                [
                  f.category.name,
                  f.region == null ? null : 'Vùng đo: ${f.region!.name}',
                  'mã ${f.code}',
                ].whereType<String>().join(' · '),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GymCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GymSectionHeader(
                icon: Icons.local_fire_department_rounded,
                title: 'Năng lượng & Đa lượng',
                accent: GymColors.flameOrange,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GymColors.flameOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: GymColors.flameOrange.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khẩu phần: ${servingText(f)}',
                      key: const Key('food-serving'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kcalText(f.kcal),
                      key: const Key('food-kcal'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: GymColors.flameOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _macroRow(
                'Chất đạm (protein)',
                gramText(f.protein),
                GymColors.proteinBlue,
              ),
              const Divider(height: 16),
              _macroRow(
                'Chất bột đường (carb)',
                gramText(f.carbs),
                GymColors.carbsAmber,
              ),
              const Divider(height: 16),
              _macroRow(
                'Chất béo (fat)',
                gramText(f.fat),
                GymColors.fatRose,
              ),
              if (f.servingSize == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Nguồn chỉ công bố số liệu cho 1 phần như ảnh, không ghi khối lượng; '
                      'cùng tên món ở vùng/quán khác có thể là phần ăn khác.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chất lượng dữ liệu: ${dataQualityLabel(f.dataQuality)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nguồn: ${food.source}',
                key: const Key('food-source'),
                style: const TextStyle(fontSize: 13),
              ),
              if (food.sourceUrl != null) ...[
                const SizedBox(height: 4),
                SelectableText(
                  food.sourceUrl!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: GymColors.bodyBlue,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Ảnh thuộc bản quyền của nguồn, tải trực tiếp từ trang của Viện.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, String value, Color dotColor) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ],
  );
}
