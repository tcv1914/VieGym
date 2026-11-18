import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../../auth/presentation/logout_button.dart';
import '../../../dashboard/application/dashboard_providers.dart';
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
    final initial = _monday.isAfter(now) ? _monday : now;
    final created = await Navigator.of(context).push<ScheduleDetail>(
      MaterialPageRoute(
        builder: (_) => ScheduleFormPage(initialDate: initial),
      ),
    );
    if (created == null || !mounted) return;
    ref.invalidate(weekSchedulesProvider);
    ref.invalidate(dashboardProvider);
    setState(() => _monday = weekStart(created.item.date));
  }

  Future<void> _open(ScheduleItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScheduleDetailPage(id: item.id)),
    );
    ref.invalidate(weekSchedulesProvider);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(weekSchedulesProvider(_monday));
    final now = today();
    final isThisWeek = _monday == weekStart(now);

    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'KẾ HOẠCH TUẦN',
        title: 'Lịch tập',
        actions: [
          GymGlassAction(
            child: IconButton(
              key: const Key('open-history'),
              tooltip: 'Lịch sử tập',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogHistoryPage()),
              ),
              icon: const Icon(Icons.history_rounded),
            ),
          ),
          const GymGlassAction(child: LogoutButton()),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('week-prev'),
                    tooltip: 'Tuần trước',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _goWeek(-1),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${viDayMonth(_monday)} – ${viDate(addDays(_monday, 6))}',
                      key: const Key('week-label'),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('week-next'),
                    tooltip: 'Tuần sau',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _goWeek(1),
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ),
                  if (!isThisWeek)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton(
                        key: const Key('week-today'),
                        style: TextButton.styleFrom(
                          backgroundColor: GymColors.accentLime,
                          foregroundColor: GymColors.heroDark,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _monday = weekStart(now)),
                        child: const Text('Về tuần này'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('schedule-create'),
        heroTag: 'schedule-create-fab',
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Xếp lịch',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: week.when(
        skipLoadingOnRefresh: !week.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(weekSchedulesProvider(_monday)),
        ),
        data: (list) => RefreshIndicator(
          color: GymColors.vibrantGreen,
          onRefresh: () => ref.refresh(weekSchedulesProvider(_monday).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              if (list.items.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GymColors.vibrantGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: GymColors.vibrantGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        color: GymColors.vibrantGreen,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tuần này chưa có lịch. Bấm "Xếp lịch" để thêm buổi từ giáo án của bạn.',
                          key: Key('week-empty'),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
    final scheme = Theme.of(context).colorScheme;
    final isToday = day == today;

    return Padding(
      key: Key('day-${isoDate(day)}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: GymCard(
        padding: const EdgeInsets.all(14),
        borderColor: isToday
            ? GymColors.vibrantGreen.withValues(alpha: 0.55)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${viWeekday(day)} ${viDayMonth(day)}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isToday ? GymColors.heroMid : scheme.onSurface,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  const GymPill(label: 'Hôm nay'),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'Không có buổi tập',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            for (final (idx, s) in items.indexed) ...[
              if (idx > 0) const SizedBox(height: 8),
              ScheduleTile(item: s, today: today, onTap: () => onTap(s)),
            ],
          ],
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final cancelled = item.status == ScheduleStatus.cancelled;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        key: Key('schedule-${item.id}'),
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        leading: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: GymColors.vibrantGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            item.startTime ?? 'Cả ngày',
            style: const TextStyle(
              color: GymColors.heroMid,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          item.workoutDay.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            decoration: cancelled ? TextDecoration.lineThrough : null,
          ),
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
      ),
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
      ScheduleStatus.completed => ('Đã tập', GymColors.vibrantGreen),
      ScheduleStatus.cancelled => ('Đã hủy', scheme.outline),
      ScheduleStatus.scheduled when item.isOverdue(today) => (
        'Đã qua',
        scheme.error,
      ),
      ScheduleStatus.scheduled => ('Đã xếp', GymColors.bodyBlue),
    };
    return GymPill(label: label, color: color);
  }
}
