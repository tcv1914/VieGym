import 'package:flutter/material.dart';

import '../data/exercise_models.dart';

/// Chọn tối đa một giá trị mỗi nhóm. Trả truy vấn mới khi bấm Áp dụng, null khi đóng.
Future<ExerciseQuery?> showExerciseFilterSheet(
  BuildContext context, {
  required ExerciseFilters filters,
  required ExerciseQuery current,
}) => showModalBottomSheet<ExerciseQuery>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FilterSheet(filters: filters, current: current),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters, required this.current});

  final ExerciseFilters filters;
  final ExerciseQuery current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _muscleGroup = widget.current.muscleGroup;
  late String? _equipment = widget.current.equipment;
  late String? _difficulty = widget.current.difficulty;

  Widget _group(
    String title,
    List<FilterOption> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o.name),
                  selected: selected == o.code,
                  // Bấm lại chip đang chọn để bỏ lọc nhóm đó.
                  onSelected: (on) =>
                      setState(() => onChanged(on ? o.code : null)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _group(
              'Nhóm cơ',
              f.muscleGroups,
              _muscleGroup,
              (v) => _muscleGroup = v,
            ),
            _group('Thiết bị', f.equipment, _equipment, (v) => _equipment = v),
            _group(
              'Độ khó',
              f.difficulties,
              _difficulty,
              (v) => _difficulty = v,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('filter-clear'),
                    onPressed: () => setState(() {
                      _muscleGroup = null;
                      _equipment = null;
                      _difficulty = null;
                    }),
                    child: const Text('Xóa lọc'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('filter-apply'),
                    onPressed: () => Navigator.of(context).pop(
                      widget.current.withFilters(
                        muscleGroup: _muscleGroup,
                        equipment: _equipment,
                        difficulty: _difficulty,
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
