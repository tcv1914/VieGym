import 'package:flutter/material.dart';

import '../../../../core/format/number_format.dart';
import '../../../../core/ui/gym_ui.dart';
import '../data/food_models.dart';

/// Ảnh món từ site nguồn. Null/lỗi mạng/lỗi ảnh → biểu tượng, thông tin dinh dưỡng vẫn hiện.
class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.url, this.size = 60});

  final String? url;

  /// null = rộng hết chỗ (màn chi tiết).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(size == null ? 18 : 14);
    final placeholder = Container(
      key: const Key('food-image-placeholder'),
      width: size ?? double.infinity,
      height: size ?? 170,
      decoration: BoxDecoration(
        color: GymColors.flameOrange.withValues(alpha: 0.10),
        borderRadius: radius,
        border: Border.all(
          color: GymColors.flameOrange.withValues(alpha: 0.22),
        ),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        color: GymColors.flameOrange,
        size: size == null ? 44 : 26,
      ),
    );
    final src = url;
    if (src == null || src.isEmpty) return placeholder;
    return Container(
      width: size,
      height: size,
      constraints: size == null
          ? const BoxConstraints(maxHeight: 220, minHeight: 140)
          : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: size == null ? BoxFit.contain : BoxFit.cover,
        cacheWidth: size == null ? null : 180,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

String kcalText(double kcal) => '${formatViCompact(kcal, maxDecimals: 1)} kcal';

String gramText(double g) => '${formatViCompact(g)} g';

/// "1 phần ăn theo nguồn" hoặc "1 bát (500 g)" nếu có khối lượng.
String servingText(FoodSummary f) {
  final size = f.servingSize;
  if (size == null || f.servingUnit == null) return f.servingDescription;
  return '${f.servingDescription} (${formatViCompact(size)} ${f.servingUnit})';
}

/// "Đạm 25 g · Bột đường 55 g · Béo 12 g"
String macroLine(FoodSummary f) =>
    'Đạm ${gramText(f.protein)} · Bột đường ${gramText(f.carbs)} · Béo ${gramText(f.fat)}';

/// Chọn danh mục và vùng; trả [FoodQuery] mới hoặc null nếu đóng.
Future<FoodQuery?> showFoodFilterSheet(
  BuildContext context, {
  required FoodFilters filters,
  required FoodQuery current,
}) => showModalBottomSheet<FoodQuery>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _FoodFilterSheet(filters: filters, current: current),
);

class _FoodFilterSheet extends StatefulWidget {
  const _FoodFilterSheet({required this.filters, required this.current});

  final FoodFilters filters;
  final FoodQuery current;

  @override
  State<_FoodFilterSheet> createState() => _FoodFilterSheetState();
}

class _FoodFilterSheetState extends State<_FoodFilterSheet> {
  late String? _category = widget.current.category;
  late String? _region = widget.current.region;

  Widget _section(
    String title,
    IconData icon,
    List<FoodOption> options,
    String? selected,
    ValueChanged<String?> onSelected,
    String keyPrefix,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: GymColors.vibrantGreen),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                key: Key('$keyPrefix-${o.code}'),
                label: Text(o.name),
                selected: selected == o.code,
                selectedColor: GymColors.vibrantGreen.withValues(alpha: 0.16),
                checkmarkColor: GymColors.heroMid,
                labelStyle: TextStyle(
                  fontWeight: selected == o.code
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected == o.code
                      ? GymColors.heroMid
                      : scheme.onSurface,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (on) => onSelected(on ? o.code : null),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            const GymSectionHeader(
              icon: Icons.tune_rounded,
              title: 'Bộ lọc món ăn',
              accent: GymColors.flameOrange,
            ),
            _section(
              'Vùng đo của nguồn',
              Icons.place_outlined,
              widget.filters.regions,
              _region,
              (v) => setState(() => _region = v),
              'food-region',
            ),
            _section(
              'Danh mục',
              Icons.category_outlined,
              widget.filters.categories,
              _category,
              (v) => setState(() => _category = v),
              'food-category',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => setState(() {
                      _category = null;
                      _region = null;
                    }),
                    child: const Text('Bỏ chọn'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('food-filter-apply'),
                    style: FilledButton.styleFrom(
                      backgroundColor: GymColors.vibrantGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      widget.current.withFilters(
                        category: _category,
                        region: _region,
                      ),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
