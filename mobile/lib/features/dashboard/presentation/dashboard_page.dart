import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/home_tab.dart';
import '../../../core/format/date_format.dart';
import '../../../core/format/number_format.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/logout_button.dart';
import '../../nutrition/food/presentation/food_widgets.dart';
import '../../nutrition/meal/application/meal_plan_controller.dart';
import '../../workout/log/presentation/log_detail_page.dart';
import '../../workout/schedule/data/schedule_models.dart';
import '../../workout/schedule/presentation/schedule_detail_page.dart';
import '../../workout/schedule/presentation/schedule_form_page.dart';
import '../../ai/presentation/conversation_list_page.dart';
import '../../workout/workout_widgets.dart';
import '../application/dashboard_providers.dart';
import '../data/dashboard_models.dart';

/// Ngày xa nhất cho phép xem: đủ để xem lịch đã lên trước.
const _maxDaysAhead = 365;

/// "645 kcal" — dashboard hiện kcal số nguyên (docs/04 §3.6).
String _kcal(double v) => '${formatVi(v, decimals: 0)} kcal';

/// Tab "Tổng quan" (UC09): dinh dưỡng, lịch tập, tiến độ tuần, cơ thể của ngày đang chọn.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    if (auth is! Authenticated) return const SizedBox.shrink();
    final date = ref.watch(dashboardDateProvider);
    final key = (userId: auth.user.id, date: date);
    final async = ref.watch(dashboardProvider(key));
    final data = async.value;

    Future<void> refresh() async {
      ref.invalidate(dashboardProvider(key));
      try {
        await ref.read(dashboardProvider(key).future);
      } catch (_) {
        // Lỗi đã hiện trên màn (banner dữ liệu cũ hoặc nút thử lại).
      }
    }

    Widget body;
    if (data == null) {
      body = async.hasError
          ? ErrorRetry(error: async.error!, onRetry: refresh)
          : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          key: const Key('dashboard-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
          children: [
            if (async.isLoading) const LinearProgressIndicator(),
            if (async.hasError) _StaleBanner(data: data, onRetry: refresh),
            _NutritionCard(data: data),
            _TrainingCard(data: data),
            _BodyCard(health: data.health),
            const _AiCard(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xin chào, ${auth.user.fullName}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('dashboard-ai'),
            tooltip: 'AI Coach',
            onPressed: () => _openAi(context),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          _DateBar(date: date),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Tải lại lỗi nhưng còn số cũ: vẫn hiện, ghi rõ thời điểm.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.data, required this.onRetry});

  final Dashboard data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = data.generatedAt;
    return Card(
      key: const Key('dashboard-stale'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        title: const Text('Không tải được dữ liệu mới'),
        subtitle: Text(
          'Đang hiện số liệu lúc ${hhmm(t.hour, t.minute)} ${viDayMonth(t)}.',
        ),
        trailing: TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardDateProvider.notifier);
    final now = today();
    final first = firstPlanDate;
    final last = addDays(now, _maxDaysAhead);
    final label = date == now
        ? 'Hôm nay, ${viDate(date)}'
        : '${viWeekday(date)}, ${viDate(date)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('dashboard-prev-day'),
            tooltip: 'Ngày trước',
            onPressed: date.isAfter(first)
                ? () => notifier.set(addDays(date, -1))
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('dashboard-pick-date'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date.isAfter(last) ? last : date,
                  firstDate: first,
                  lastDate: last,
                  helpText: 'Chọn ngày',
                );
                if (picked != null) notifier.set(picked);
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(label, key: const Key('dashboard-date')),
            ),
          ),
          IconButton(
            key: const Key('dashboard-next-day'),
            tooltip: 'Ngày sau',
            onPressed: date.isBefore(last)
                ? () => notifier.set(addDays(date, 1))
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          if (date != now)
            TextButton(
              key: const Key('dashboard-today'),
              onPressed: () => notifier.set(now),
              child: const Text('Hôm nay'),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.cardKey,
    this.onTap,
  });

  final String title;
  final List<Widget> children;
  final Key? cardKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Chuyển sang tab Thực đơn ở đúng ngày đang xem.
void _openMealPlan(WidgetRef ref, DateTime date) {
  ref.read(homeTabProvider.notifier).select(HomeTab.mealPlan);
  // Đợi tab dựng xong (lần mở đầu tiên) rồi mới đổi ngày.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => ref.read(mealPlanProvider.notifier).setDate(date),
  );
}

class _NutritionCard extends ConsumerWidget {
  const _NutritionCard({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = data.nutrition;
    final t = n.totals;
    final target = n.targets;
    final remaining = n.remaining;
    final isToday = data.date == today();
    return _SectionCard(
      cardKey: const Key('dashboard-nutrition'),
      title: isToday ? 'Dinh dưỡng hôm nay' : 'Dinh dưỡng ${viDate(data.date)}',
      onTap: () => _openMealPlan(ref, data.date),
      children: [
        Text(
          target == null
              ? _kcal(t.kcal)
              : '${formatVi(t.kcal, decimals: 0)} / ${_kcal(target.kcal)}',
          key: const Key('dashboard-kcal'),
          style: theme.textTheme.headlineSmall,
        ),
        if (target != null && remaining != null) ...[
          const SizedBox(height: 8),
          // Thanh chỉ dài tối đa 100%; số vượt vẫn hiện đúng ở dòng dưới.
          LinearProgressIndicator(
            value: target.kcal <= 0
                ? null
                : (t.kcal / target.kcal).clamp(0, 1).toDouble(),
            color: remaining.kcal < 0 ? theme.colorScheme.error : null,
          ),
          const SizedBox(height: 4),
          Text(
            remaining.kcal < 0
                ? 'Vượt ${_kcal(-remaining.kcal)}'
                : 'Còn lại ${_kcal(remaining.kcal)}',
            key: const Key('dashboard-remaining'),
            style: remaining.kcal < 0
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
        ],
        const SizedBox(height: 8),
        _macro('Đạm', t.protein, target?.protein),
        _macro('Bột đường', t.carbs, target?.carbs),
        _macro('Béo', t.fat, target?.fat),
        const SizedBox(height: 8),
        if (n.entryCount == 0)
          const Text(
            'Chưa ghi nhận bữa ăn nào trong ngày này.',
            key: Key('dashboard-no-meal'),
          ),
        if (target == null)
          Text(
            'Chưa có mục tiêu để so sánh. Hãy hoàn thiện hồ sơ sức khỏe.',
            key: const Key('dashboard-no-target'),
            style: theme.textTheme.bodySmall,
          )
        else
          Text(
            'So với mục tiêu hiện tại'
            '${n.targetsCalculatedAt == null ? '' : ' (tính ngày ${viDate(n.targetsCalculatedAt!)})'}.',
            style: theme.textTheme.bodySmall,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('dashboard-add-meal'),
            onPressed: () => _openMealPlan(ref, data.date),
            icon: const Icon(Icons.add),
            label: const Text('Thêm món'),
          ),
        ),
      ],
    );
  }

  Widget _macro(String label, double eaten, double? target) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          target == null
              ? gramText(eaten)
              : '${formatVi(eaten)} / ${formatVi(target)} g',
        ),
      ],
    ),
  );
}

String _scheduleSubtitle(DashboardSchedule s, {bool withDate = false}) {
  final parts = [
    if (withDate) '${viWeekday(s.date)} ${viDayMonth(s.date)}',
    ?s.startTime,
    s.programName,
  ];
  return parts.join(' · ');
}

class _TrainingCard extends ConsumerWidget {
  const _TrainingCard({required this.data});

  final Dashboard data;

  Future<void> _push(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    ref.invalidate(dashboardProvider);
  }

  void _open(BuildContext context, WidgetRef ref, DashboardSchedule s) {
    final logId = s.workoutLogId;
    _push(
      context,
      ref,
      s.status == ScheduleStatus.completed && logId != null
          ? LogDetailPage(id: logId)
          : ScheduleDetailPage(id: s.scheduleId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final training = data.training;
    final week = training.week;
    final progress = week.progress;
    final isToday = data.date == today();
    final next = training.next;
    return _SectionCard(
      cardKey: const Key('dashboard-training'),
      title: isToday ? 'Lịch tập hôm nay' : 'Lịch tập ${viDate(data.date)}',
      children: [
        if (training.today.isEmpty) ...[
          Text(
            isToday ? 'Hôm nay không có lịch.' : 'Ngày này không có lịch.',
            key: const Key('dashboard-no-schedule'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('dashboard-add-schedule'),
              onPressed: () => _push(
                context,
                ref,
                ScheduleFormPage(
                  initialDate: data.date.isBefore(today()) ? today() : data.date,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Lên lịch'),
            ),
          ),
        ],
        for (final s in training.today)
          ListTile(
            key: Key('dashboard-schedule-${s.scheduleId}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              s.name,
              style: s.status == ScheduleStatus.cancelled
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(_scheduleSubtitle(s)),
            trailing: _statusAction(context, ref, s),
            onTap: () => _open(context, ref, s),
          ),
        const Divider(),
        Text(
          progress == null
              ? 'Tuần ${viDayMonth(week.from)}–${viDayMonth(week.to)}: chưa có lịch'
              : 'Tuần ${viDayMonth(week.from)}–${viDayMonth(week.to)}: '
                    '${week.completed}/${week.scheduled} buổi hoàn thành',
          key: const Key('dashboard-week'),
        ),
        if (progress != null) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress),
        ],
        if (week.cancelled > 0)
          Text(
            '${week.cancelled} buổi đã hủy, không tính vào tiến độ.',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        if (next == null)
          Text(
            'Không có buổi nào sắp tới trong 30 ngày.',
            key: const Key('dashboard-no-next'),
            style: theme.textTheme.bodySmall,
          )
        else
          ListTile(
            key: const Key('dashboard-next'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upcoming_outlined),
            title: Text('Buổi tiếp theo: ${next.name}'),
            subtitle: Text(_scheduleSubtitle(next, withDate: true)),
            onTap: () => _open(context, ref, next),
          ),
      ],
    );
  }

  Widget _statusAction(
    BuildContext context,
    WidgetRef ref,
    DashboardSchedule s,
  ) => switch (s.status) {
    ScheduleStatus.completed => const Chip(label: Text('Đã xong')),
    ScheduleStatus.cancelled => const Text('Đã hủy'),
    ScheduleStatus.scheduled =>
      s.date.isAfter(today())
          ? const Text('Chưa tới ngày')
          : FilledButton.tonal(
              onPressed: () => _open(context, ref, s),
              child: const Text('Bắt đầu'),
            ),
  };
}

class _BodyCard extends ConsumerWidget {
  const _BodyCard({required this.health});

  final DashboardHealth health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openHealth() =>
        ref.read(homeTabProvider.notifier).select(HomeTab.health);
    if (!health.hasProfile) {
      return _SectionCard(
        cardKey: const Key('dashboard-body'),
        title: 'Cơ thể',
        children: [
          const Text('Chưa có hồ sơ sức khỏe.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('dashboard-complete-profile'),
              onPressed: openHealth,
              icon: const Icon(Icons.edit_note),
              label: const Text('Hoàn thiện hồ sơ'),
            ),
          ),
        ],
      );
    }
    final weight = health.weightKg;
    final bmi = health.bmi;
    return _SectionCard(
      cardKey: const Key('dashboard-body'),
      title: 'Cơ thể',
      onTap: openHealth,
      children: [
        if (weight != null)
          Text(
            'Cân nặng ${formatViCompact(weight, maxDecimals: 1)} kg (theo hồ sơ)',
            key: const Key('dashboard-weight'),
          ),
        Text(
          [
            if (bmi != null) 'BMI ${formatVi(bmi, decimals: 2)}',
            if (health.goal != null) 'Mục tiêu: ${health.goal!.label}',
          ].join(' · '),
          key: const Key('dashboard-bmi'),
        ),
      ],
    );
  }
}

void _openAi(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const ConversationListPage()),
);

/// Lối vào AI Coach (ngày 12): chỉ mở màn chat, không hiển thị gợi ý tự sinh trên Tổng quan.
class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) => _SectionCard(
    cardKey: const Key('dashboard-ai-card'),
    title: 'AI Coach',
    onTap: () => _openAi(context),
    children: const [
      Text('Hỏi về bữa ăn, lịch tập dựa trên dữ liệu bạn đã ghi.'),
    ],
  );
}
