import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../program/data/program_models.dart';
import '../../program/presentation/program_detail_page.dart';
import '../../workout_widgets.dart';
import '../application/schedule_providers.dart';
import '../data/schedule_api.dart';
import '../data/schedule_models.dart';
import 'schedule_form_page.dart';
import 'schedule_week_page.dart';

/// Chi tiết lịch: bài của buổi, dời ngày giờ, hủy. Không có nút "đã tập" — hoàn thành
/// chỉ qua ghi nhận buổi tập (ngày 8).
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
    }
  }

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
      await ref.read(scheduleApiProvider).update(
        s.id,
        date: s.date,
        startTime: s.startTime,
        note: s.note,
        status: ScheduleStatus.cancelled,
      );
      ref.invalidate(weekSchedulesProvider);
      ref.invalidate(scheduleDetailProvider(widget.id));
      if (mounted) showSnack(context, 'Đã hủy lịch');
    } catch (e) {
      // 409: lịch đã hủy/hoàn thành ở nơi khác → tải lại cho thấy trạng thái thật.
      ref.invalidate(scheduleDetailProvider(widget.id));
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(scheduleDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Buổi tập đã xếp')),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.workoutDay.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(s.workoutDay.programName),
                trailing: StatusChip(item: s, today: now),
              ),
              Text(
                '${viWeekday(s.date)}, ${viDate(s.date)} · ${s.startTime ?? 'chưa đặt giờ'}',
              ),
              if (s.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Ghi chú: ${s.note}'),
                ),
              if (s.workoutDay.archived)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Buổi này đã được gỡ khỏi giáo án; lịch vẫn giữ và tập được theo các bài dưới đây.',
                  ),
                ),
              if (s.isOverdue(now))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Ngày tập đã qua. Bạn có thể dời sang ngày khác hoặc hủy lịch.',
                  ),
                ),
              const SizedBox(height: 8),
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
                  key: const Key('schedule-reschedule'),
                  onPressed: _busy ? null : () => _reschedule(d),
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Dời ngày giờ'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('schedule-cancel'),
                  onPressed: _busy ? null : () => _cancel(d),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_busy),
                  label: const Text('Hủy lịch'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
