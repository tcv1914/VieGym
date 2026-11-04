import 'package:flutter/material.dart';

import '../../../../core/format/number_format.dart';
import '../data/food_models.dart';

/// Ảnh món từ site nguồn. Null/lỗi mạng/lỗi ảnh → biểu tượng, thông tin dinh dưỡng vẫn hiện.
class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.url, this.size = 56});

  final String? url;

  /// null = rộng hết chỗ (màn chi tiết).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      key: const Key('food-image-placeholder'),
      width: size,
      height: size ?? 160,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.restaurant),
    );
    final src = url;
    if (src == null || src.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
    List<FoodOption> options,
    String? selected,
    ValueChanged<String?> onSelected,
    String keyPrefix,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final o in options)
            ChoiceChip(
              key: Key('$keyPrefix-${o.code}'),
              label: Text(o.name),
              selected: selected == o.code,
              onSelected: (on) => onSelected(on ? o.code : null),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Text(
              'Bộ lọc món ăn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _section(
              'Vùng đo của nguồn',
              widget.filters.regions,
              _region,
              (v) => setState(() => _region = v),
              'food-region',
            ),
            _section(
              'Danh mục',
              widget.filters.categories,
              _category,
              (v) => setState(() => _category = v),
              'food-category',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _category = null;
                    _region = null;
                  }),
                  child: const Text('Bỏ chọn'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('food-filter-apply'),
                  onPressed: () => Navigator.pop(
                    context,
                    widget.current.withFilters(
                      category: _category,
                      region: _region,
                    ),
                  ),
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
