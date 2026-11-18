import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/format/number_format.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../../auth/presentation/logout_button.dart';
import '../../../workout/workout_widgets.dart';
import '../../food/application/food_list_controller.dart';
import '../../food/data/food_models.dart';
import '../../food/presentation/food_list_page.dart';
import '../../food/presentation/food_widgets.dart';
import '../application/meal_plan_controller.dart';
import '../data/meal_models.dart';
import 'meal_entry_sheet.dart';

/// Tab "Thực đơn" (UC07): chọn ngày, bốn bữa, tổng kcal/macro so với mục tiêu hiện tại.
class MealPlanPage extends ConsumerWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealPlanProvider);
    final controller = ref.read(mealPlanProvider.notifier);
    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'NHẬT KÝ DINH DƯỠNG',
        title: 'Thực đơn',
        actions: const [GymGlassAction(child: LogoutButton())],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _DateBar(date: state.date),
          ),
        ),
      ),
      body: _body(context, ref, state, controller),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    MealPlanState state,
    MealPlanController controller,
  ) {
    final plan = state.plan;
    if (plan == null) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ErrorRetry(
        error: state.error ?? 'Không tải được thực đơn',
        onRetry: controller.refresh,
      );
    }
    final writable = controller.canWrite(plan.date);
    return RefreshIndicator(
      color: GymColors.vibrantGreen,
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        key: const Key('meal-plan-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    title: Text(state.error.toString()),
                    trailing: TextButton(
                      onPressed: controller.refresh,
                      child: const Text('Thử lại'),
                    ),
                  ),
                ),
              ),
            _TotalsCard(plan: plan),
            const SizedBox(height: 8),
            if (!writable)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: GymPill(
                  icon: Icons.lock_clock_outlined,
                  color: GymColors.carbsAmber,
                  label: 'Chỉ lập thực đơn tối đa 7 ngày tới.',
                ),
              ),
            for (final type in MealType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MealSection(
                  plan: plan,
                  type: type,
                  writable: writable,
                  onAdd: () => _addFood(context, ref, plan.date, type),
                  onEdit: (entry) => _editEntry(context, ref, entry),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFood(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    MealType type,
  ) async {
    final food = await Navigator.of(context).push<FoodSummary>(
      MaterialPageRoute(builder: (_) => const MealFoodPickerPage()),
    );
    if (food == null || !context.mounted) return;
    final controller = ref.read(mealPlanProvider.notifier);
    await showMealEntrySheet(
      context,
      title: 'Thêm vào ${viDate(date)}',
      foodName: food.name,
      servingLabel: servingText(food),
      perServing: Nutrients(
        kcal: food.kcal,
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
      ),
      mealType: type,
      submitLabel: 'Thêm',
      onSubmit: (mealType, servings) => _guard(
        controller,
        () => controller.add(
          date: date,
          mealType: mealType,
          foodId: food.id,
          servings: servings,
        ),
      ),
    );
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    MealEntry entry,
  ) {
    final controller = ref.read(mealPlanProvider.notifier);
    return showMealEntrySheet(
      context,
      title: 'Sửa món',
      foodName: entry.foodName,
      servingLabel: entryServingText(entry),
      perServing: entry.perServing,
      mealType: entry.mealType,
      servings: entry.servings,
      submitLabel: 'Lưu',
      onSubmit: (mealType, servings) => _guard(
        controller,
        () => controller.updateEntry(
          entry.id,
          mealType: mealType == entry.mealType ? null : mealType,
          servings: servings == entry.servings ? null : servings,
        ),
        unchanged: mealType == entry.mealType && servings == entry.servings,
      ),
      onDelete: () =>
          _guard(controller, () => controller.deleteEntry(entry.id)),
    );
  }

  static Future<String?> _guard(
    MealPlanController controller,
    Future<void> Function() action, {
    bool unchanged = false,
  }) async {
    if (unchanged) return null;
    try {
      await action();
      return null;
    } catch (e) {
      if (e is NetworkException ||
          (e is ApiException && e.code == 'NOT_FOUND')) {
        controller.refresh();
      }
      return mealErrorText(e);
    }
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mealPlanProvider.notifier);
    final now = today();
    final last = addDays(now, maxDaysAhead);
    final label = date == now
        ? 'Hôm nay, ${viDate(date)}'
        : '${viWeekday(date)}, ${viDate(date)}';

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('meal-prev-day'),
            tooltip: 'Ngày trước',
            visualDensity: VisualDensity.compact,
            onPressed: date.isAfter(firstPlanDate)
                ? () => controller.setDate(addDays(date, -1))
                : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: date.isAfter(firstPlanDate)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('meal-pick-date'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date.isAfter(last) ? last : date,
                  firstDate: firstPlanDate,
                  lastDate: last,
                  helpText: 'Chọn ngày',
                );
                if (picked != null) controller.setDate(picked);
              },
              icon: const Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: GymColors.accentLime,
              ),
              label: Text(
                label,
                key: const Key('meal-date'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('meal-next-day'),
            tooltip: 'Ngày sau',
            visualDensity: VisualDensity.compact,
            onPressed: date.isBefore(last)
                ? () => controller.setDate(addDays(date, 1))
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: date.isBefore(last)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
          if (date != now)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                key: const Key('meal-today'),
                style: TextButton.styleFrom(
                  backgroundColor: GymColors.accentLime,
                  foregroundColor: GymColors.heroDark,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => controller.setDate(now),
                child: const Text('Hôm nay'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = plan.totals;
    final target = plan.targets;
    final remaining = plan.remaining;
    final isOver = remaining != null && remaining.kcal < 0;

    return GymCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GymSectionHeader(
            icon: Icons.local_fire_department_rounded,
            title: 'Tổng kết năng lượng ngày',
            accent: GymColors.flameOrange,
          ),
          const SizedBox(height: 8),
          Text(
            target == null
                ? 'Đã ăn ${kcalText(t.kcal)}'
                : 'Đã ăn ${kcalText(t.kcal)} / ${kcalText(target.kcal)}',
            key: const Key('meal-total-kcal'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (target != null && remaining != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: target.kcal <= 0
                    ? null
                    : (t.kcal / target.kcal).clamp(0, 1).toDouble(),
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                color: isOver ? scheme.error : GymColors.vibrantGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isOver
                  ? 'Vượt ${kcalText(-remaining.kcal)} so với mục tiêu'
                  : 'Còn lại ${kcalText(remaining.kcal)}',
              key: const Key('meal-remaining'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isOver ? scheme.error : GymColors.heroMid,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _macroRow('Đạm', t.protein, target?.protein, GymColors.proteinBlue),
          const SizedBox(height: 3),
          _macroRow(
            'Bột đường',
            t.carbs,
            target?.carbs,
            GymColors.carbsAmber,
          ),
          const SizedBox(height: 3),
          _macroRow('Béo', t.fat, target?.fat, GymColors.fatRose),
          const SizedBox(height: 6),
          Text(
            target == null
                ? 'Chưa có mục tiêu để so sánh. Hãy hoàn thiện hồ sơ ở tab Sức khỏe.'
                : 'So với mục tiêu hiện tại'
                      '${plan.targetsCalculatedAt == null ? '' : ' (tính ngày ${viDate(plan.targetsCalculatedAt!)})'}'
                      ', kể cả khi xem ngày cũ.',
            key: const Key('meal-target-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, double eaten, double? target, Color dot) =>
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            target == null
                ? gramText(eaten)
                : '${gramText(eaten)} / ${gramText(target)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      );
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.plan,
    required this.type,
    required this.writable,
    required this.onAdd,
    required this.onEdit,
  });

  final MealPlan plan;
  final MealType type;
  final bool writable;
  final VoidCallback onAdd;
  final ValueChanged<MealEntry> onEdit;

  IconData _mealIcon(MealType t) => switch (t) {
    MealType.breakfast => Icons.wb_sunny_outlined,
    MealType.lunch => Icons.lunch_dining_rounded,
    MealType.dinner => Icons.nights_stay_outlined,
    MealType.snack => Icons.cookie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = plan.meals[type] ?? const [];
    final total = plan.mealTotals[type] ?? Nutrients.zero;

    return GymCard(
      cardKey: Key('meal-section-${type.code}'),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GymColors.vibrantGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _mealIcon(type),
                  color: GymColors.vibrantGreen,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      kcalText(total.kcal),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                key: Key('meal-add-${type.code}'),
                style: FilledButton.styleFrom(
                  backgroundColor: GymColors.vibrantGreen.withValues(
                    alpha: 0.14,
                  ),
                  foregroundColor: GymColors.heroMid,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                onPressed: writable ? onAdd : null,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Thêm món'),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Text(
                'Chưa có món',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
          ],
          for (final e in entries)
            ListTile(
              key: Key('meal-entry-${e.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                e.foodName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              subtitle: Text(
                '${formatViCompact(e.servings)} × ${entryServingText(e)}\n'
                'Đạm ${gramText(e.total.protein)} · Bột đường ${gramText(e.total.carbs)} · '
                'Béo ${gramText(e.total.fat)}',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
              ),
              isThreeLine: true,
              trailing: GymPill(
                label: kcalText(e.total.kcal),
                color: GymColors.flameOrange,
              ),
              onTap: () => onEdit(e),
            ),
        ],
      ),
    );
  }
}

String entryServingText(MealEntry e) {
  final size = e.servingSize;
  if (size == null || e.servingUnit == null) return e.servingDescription;
  return '${e.servingDescription} (${formatViCompact(size)} ${e.servingUnit})';
}

/// Tìm món ngày 9 ở chế độ chọn, với trạng thái tìm kiếm riêng (không đổi từ khóa của tab Món ăn).
class MealFoodPickerPage extends StatelessWidget {
  const MealFoodPickerPage({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [foodListProvider.overrideWith(FoodListController.new)],
    child: FoodListPage(
      title: 'Chọn món',
      onPick: (food) => Navigator.of(context).pop(food),
    ),
  );
}
