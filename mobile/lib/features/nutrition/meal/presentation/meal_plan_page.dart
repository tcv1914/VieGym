import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/format/number_format.dart';
import '../../../../core/network/api_client.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thực đơn'),
        actions: const [LogoutButton()],
      ),
      body: Column(
        children: [
          _DateBar(date: state.date),
          Expanded(child: _body(context, ref, state, controller)),
        ],
      ),
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
      onRefresh: controller.refresh,
      child: ListView(
        key: const Key('meal-plan-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                title: Text(state.error.toString()),
                trailing: TextButton(
                  onPressed: controller.refresh,
                  child: const Text('Thử lại'),
                ),
              ),
            ),
          _TotalsCard(plan: plan),
          if (!writable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chỉ lập thực đơn tối đa 7 ngày tới.'),
            ),
          for (final type in MealType.values)
            _MealSection(
              plan: plan,
              type: type,
              writable: writable,
              onAdd: () => _addFood(context, ref, plan.date, type),
              onEdit: (entry) => _editEntry(context, ref, entry),
            ),
        ],
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

  /// Gọi thao tác ghi; lỗi → thông điệp cho form. Mất mạng hoặc mục không còn → tải lại thực đơn
  /// để người dùng thấy trạng thái thật, không đoán.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('meal-prev-day'),
            tooltip: 'Ngày trước',
            onPressed: date.isAfter(firstPlanDate)
                ? () => controller.setDate(addDays(date, -1))
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('meal-pick-date'),
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
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(label, key: const Key('meal-date')),
            ),
          ),
          IconButton(
            key: const Key('meal-next-day'),
            tooltip: 'Ngày sau',
            onPressed: date.isBefore(last)
                ? () => controller.setDate(addDays(date, 1))
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          if (date != now)
            TextButton(
              key: const Key('meal-today'),
              onPressed: () => controller.setDate(now),
              child: const Text('Hôm nay'),
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
    final t = plan.totals;
    final target = plan.targets;
    final remaining = plan.remaining;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              target == null
                  ? 'Đã ăn ${kcalText(t.kcal)}'
                  : 'Đã ăn ${kcalText(t.kcal)} / ${kcalText(target.kcal)}',
              key: const Key('meal-total-kcal'),
              style: theme.textTheme.titleLarge,
            ),
            if (target != null && remaining != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: target.kcal <= 0
                    ? null
                    : (t.kcal / target.kcal).clamp(0, 1).toDouble(),
                color: remaining.kcal < 0 ? theme.colorScheme.error : null,
              ),
              const SizedBox(height: 4),
              Text(
                remaining.kcal < 0
                    ? 'Vượt ${kcalText(-remaining.kcal)} so với mục tiêu'
                    : 'Còn lại ${kcalText(remaining.kcal)}',
                key: const Key('meal-remaining'),
                style: remaining.kcal < 0
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            _macroRow('Đạm', t.protein, target?.protein),
            _macroRow('Bột đường', t.carbs, target?.carbs),
            _macroRow('Béo', t.fat, target?.fat),
            const SizedBox(height: 8),
            Text(
              target == null
                  ? 'Chưa có mục tiêu để so sánh. Hãy hoàn thiện hồ sơ ở tab Sức khỏe.'
                  : 'So với mục tiêu hiện tại'
                        '${plan.targetsCalculatedAt == null ? '' : ' (tính ngày ${viDate(plan.targetsCalculatedAt!)})'}'
                        ', kể cả khi xem ngày cũ.',
              key: const Key('meal-target-note'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String label, double eaten, double? target) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          target == null
              ? gramText(eaten)
              : '${gramText(eaten)} / ${gramText(target)}',
        ),
      ],
    ),
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

  @override
  Widget build(BuildContext context) {
    final entries = plan.meals[type] ?? const [];
    final total = plan.mealTotals[type] ?? Nutrients.zero;
    return Card(
      key: Key('meal-section-${type.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              type.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(kcalText(total.kcal)),
            trailing: TextButton.icon(
              key: Key('meal-add-${type.code}'),
              onPressed: writable ? onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('Thêm món'),
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Chưa có món'),
            ),
          for (final e in entries)
            ListTile(
              key: Key('meal-entry-${e.id}'),
              dense: true,
              title: Text(e.foodName),
              subtitle: Text(
                '${formatViCompact(e.servings)} × ${entryServingText(e)}\n'
                'Đạm ${gramText(e.total.protein)} · Bột đường ${gramText(e.total.carbs)} · '
                'Béo ${gramText(e.total.fat)}',
              ),
              isThreeLine: true,
              trailing: Text(kcalText(e.total.kcal)),
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
