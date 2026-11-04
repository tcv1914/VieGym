import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../auth/presentation/logout_button.dart';
import '../../log/presentation/log_history_page.dart';
import '../../workout_widgets.dart';
import '../application/schedule_providers.dart';
import '../data/schedule_models.dart';
import 'schedule_detail_page.dart';
import 'schedule_form_page.dart';

/// Tab "Lịch tập": 7 ngày thứ Hai–Chủ nhật, nhóm theo `scheduledDate` (ngày theo múi giờ user).
class ScheduleWeekPage extends ConsumerStatefulWidget {
  const ScheduleWeekPage({super.key});

  @override
  ConsumerState<ScheduleWeekPage> createState() => _ScheduleWeekPageState();
}

class _ScheduleWeekPageState extends ConsumerState<ScheduleWeekPage> {
  DateTime _monday = weekStart(today());

  void _goWeek(int delta) =>
      setState(() => _monday = addDays(_monday, 7 * delta));

  Future<void> _create() async {
    final now = today();
    // Đang xem tuần tương lai thì mặc định thứ Hai của tuần đó, không thì hôm nay.
    final initial = _monday.isAfter(now) ? _monday : now;
    final created = await Navigator.of(context).push<ScheduleDetail>(
      MaterialPageRoute(
        builder: (_) => ScheduleFormPage(initialDate: initial),
      ),
    );
    if (created == null || !mounted) return;
    ref.invalidate(weekSchedulesProvider);
    setState(() => _monday = weekStart(created.item.date));
  }

  Future<void> _open(ScheduleItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScheduleDetailPage(id: item.id)),
    );
    // Có thể đã dời sang tuần khác hoặc hủy: tải lại tuần đang xem.
    ref.invalidate(weekSchedulesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(weekSchedulesProvider(_monday));
    final now = today();
    final isThisWeek = _monday == weekStart(now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch tập'),
        actions: [
          IconButton(
            key: const Key('open-history'),
            tooltip: 'Lịch sử tập',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogHistoryPage()),
            ),
            icon: const Icon(Icons.history),
          ),
          const LogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('schedule-create'),
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Xếp lịch'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  key: const Key('week-prev'),
                  tooltip: 'Tuần trước',
                  onPressed: () => _goWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${viDayMonth(_monday)} – ${viDate(addDays(_monday, 6))}',
                    key: const Key('week-label'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('week-next'),
                  tooltip: 'Tuần sau',
                  onPressed: () => _goWeek(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (!isThisWeek)
            TextButton(
              key: const Key('week-today'),
              onPressed: () => setState(() => _monday = weekStart(now)),
              child: const Text('Về tuần này'),
            ),
          Expanded(
            child: week.when(
              skipLoadingOnRefresh: !week.hasError,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(weekSchedulesProvider(_monday)),
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(weekSchedulesProvider(_monday).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    if (list.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Tuần này chưa có lịch. Bấm "Xếp lịch" để thêm buổi từ giáo án của bạn.',
                          key: Key('week-empty'),
                        ),
                      ),
                    for (var i = 0; i < 7; i++)
                      _DaySection(
                        day: addDays(_monday, i),
                        today: now,
                        items: list.on(addDays(_monday, i)),
                        onTap: _open,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.today,
    required this.items,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = day == today;
    return Column(
      key: Key('day-${isoDate(day)}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text(
                '${viWeekday(day)} ${viDayMonth(day)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isToday ? theme.colorScheme.primary : null,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Text(
                  'Hôm nay',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Không có buổi tập',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final s in items)
          ScheduleTile(item: s, today: today, onTap: () => onTap(s)),
      ],
    );
  }
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.item,
    required this.today,
    this.onTap,
  });

  final ScheduleItem item;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = item.status == ScheduleStatus.cancelled;
    return ListTile(
      key: Key('schedule-${item.id}'),
      leading: SizedBox(
        width: 52,
        child: Center(child: Text(item.startTime ?? 'Cả ngày')),
      ),
      title: Text(
        item.workoutDay.name,
        style: cancelled
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        [
          item.workoutDay.programName,
          if (item.note != null) item.note!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: StatusChip(item: item, today: today),
      onTap: onTap,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.item, required this.today});

  final ScheduleItem item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (item.status) {
      ScheduleStatus.completed => ('Đã tập', scheme.primary),
      ScheduleStatus.cancelled => ('Đã hủy', scheme.outline),
      ScheduleStatus.scheduled when item.isOverdue(today) => (
        'Đã qua',
        scheme.error,
      ),
      ScheduleStatus.scheduled => ('Đã xếp', scheme.secondary),
    };
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: color),
    );
  }
}
