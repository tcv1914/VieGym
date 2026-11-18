import 'package:flutter/material.dart';

import '../../../core/ui/gym_ui.dart';
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

  int get _selectedCount =>
      (_muscleGroup != null ? 1 : 0) +
      (_equipment != null ? 1 : 0) +
      (_difficulty != null ? 1 : 0);

  Widget _group(
    String title,
    IconData icon,
    List<FilterOption> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: GymColors.vibrantGreen),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GymSectionHeader(
              icon: Icons.tune_rounded,
              title: 'Bộ lọc bài tập',
              trailing: _selectedCount > 0
                  ? GymPill(label: 'Đang chọn $_selectedCount')
                  : null,
            ),
            const SizedBox(height: 18),
            _group(
              'Nhóm cơ',
              Icons.accessibility_new_rounded,
              f.muscleGroups,
              _muscleGroup,
              (v) => _muscleGroup = v,
            ),
            _group(
              'Thiết bị',
              Icons.fitness_center_rounded,
              f.equipment,
              _equipment,
              (v) => _equipment = v,
            ),
            _group(
              'Độ khó',
              Icons.speed_rounded,
              f.difficulties,
              _difficulty,
              (v) => _difficulty = v,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('filter-clear'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: GymColors.vibrantGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
