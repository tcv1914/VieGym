import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../log/presentation/log_detail_page.dart';
import '../../log/presentation/log_form_page.dart';
import '../../program/data/program_models.dart';
import '../../program/presentation/program_detail_page.dart';
import '../../workout_widgets.dart';
import '../application/schedule_providers.dart';
import '../data/schedule_api.dart';
import '../data/schedule_models.dart';
import 'schedule_form_page.dart';
import 'schedule_week_page.dart';

/// Chi tiết lịch: bài của buổi, bắt đầu ghi buổi tập, dời ngày giờ, hủy. Không có nút
/// "đánh dấu đã tập" — COMPLETED chỉ có cùng kết quả đã lưu (BR-W04).
class ScheduleDetailPage extends ConsumerStatefulWidget {
  const ScheduleDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends ConsumerState<ScheduleDetailPage> {
  bool _busy = false;

  Future<void> _reschedule(ScheduleDetail detail) async {
    final saved = await Navigator.of(context).push<ScheduleDetail>(
      MaterialPageRoute(builder: (_) => ScheduleFormPage(existing: detail)),
    );
    if (saved != null) {
      ref.invalidate(scheduleDetailProvider(widget.id));
      ref.invalidate(weekSchedulesProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  Future<void> _startLog(ScheduleDetail detail) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LogFormPage(schedule: detail)),
    );
    ref.invalidate(scheduleDetailProvider(widget.id));
  }

  void _openLog(String logId) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => LogDetailPage(id: logId)));

  Future<void> _cancel(ScheduleDetail detail) async {
    final s = detail.item;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch này?'),
        content: Text(
          '${s.workoutDay.name} — ${viWeekday(s.date)} ${viDate(s.date)}.\n'
          'Lịch đã hủy vẫn hiện trong tuần để theo dõi và không khôi phục được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            key: const Key('schedule-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(scheduleApiProvider)
          .update(
            s.id,
            date: s.date,
            startTime: s.startTime,
            note: s.note,
            status: ScheduleStatus.cancelled,
          );
      ref.invalidate(weekSchedulesProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(scheduleDetailProvider(widget.id));
      if (mounted) showSnack(context, 'Đã hủy lịch');
    } catch (e) {
      ref.invalidate(scheduleDetailProvider(widget.id));
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(scheduleDetailProvider(widget.id));
    final scheme = Theme.of(context).colorScheme;

    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'CHI TIẾT BUỔI TẬP',
        title: 'Buổi tập đã xếp',
      ),
      body: detail.when(
        skipLoadingOnRefresh: !detail.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(scheduleDetailProvider(widget.id)),
        ),
        data: (d) {
          final s = d.item;
          final now = today();
          final editable = s.status == ScheduleStatus.scheduled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              GymCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.workoutDay.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.workoutDay.programName,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(item: s, today: now),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: GymColors.vibrantGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${viWeekday(s.date)}, ${viDate(s.date)} · ${s.startTime ?? 'chưa đặt giờ'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (s.note != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ghi chú: ${s.note}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (s.workoutDay.archived) ...[
                const SizedBox(height: 12),
                const AuthNoticeBanner(
                  isError: false,
                  message:
                      'Buổi này đã được gỡ khỏi giáo án; lịch vẫn giữ và tập được theo các bài dưới đây.',
                ),
              ],
              if (s.isOverdue(now)) ...[
                const SizedBox(height: 12),
                const AuthNoticeBanner(
                  message:
                      'Ngày tập đã qua. Bạn vẫn ghi lại được kết quả nếu đã tập, hoặc dời sang ngày khác / hủy lịch.',
                ),
              ],
              if (s.status == ScheduleStatus.completed &&
                  s.workoutLogId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    key: const Key('schedule-view-log'),
                    style: FilledButton.styleFrom(
                      backgroundColor: GymColors.vibrantGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _openLog(s.workoutLogId!),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Xem kết quả đã ghi'),
                  ),
                ),
              const SizedBox(height: 14),
              DayCard(
                title: 'Bài tập (${d.exercises.length})',
                day: ProgramDay(
                  id: s.workoutDay.id,
                  dayOrder: 0,
                  name: s.workoutDay.name,
                  exercises: d.exercises,
                ),
              ),
              if (editable) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('schedule-start-log'),
                  style: FilledButton.styleFrom(
                    backgroundColor: GymColors.vibrantGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: _busy || s.date.isAfter(now)
                      ? null
                      : () => _startLog(d),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    s.date.isAfter(now) ? 'Chưa tới ngày tập' : 'Bắt đầu tập',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('schedule-reschedule'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _busy ? null : () => _reschedule(d),
                        icon: const Icon(Icons.edit_calendar_rounded, size: 19),
                        label: const Text('Dời ngày giờ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('schedule-cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.5),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _busy ? null : () => _cancel(d),
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.event_busy_rounded, size: 19),
                        label: const Text('Hủy lịch'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
