import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../program/application/program_providers.dart';
import '../../program/data/program_models.dart';
import '../../workout_widgets.dart';
import '../data/schedule_api.dart';
import '../data/schedule_models.dart';

/// Xếp lịch mới ([existing] null): chọn giáo án → buổi → ngày → giờ.
/// Dời lịch ([existing]): chỉ đổi ngày/giờ/ghi chú; muốn tập buổi khác thì hủy và xếp mới.
/// Pop trả về [ScheduleDetail] đã lưu.
class ScheduleFormPage extends ConsumerStatefulWidget {
  const ScheduleFormPage({super.key, this.initialDate, this.existing});

  final DateTime? initialDate;
  final ScheduleDetail? existing;

  @override
  ConsumerState<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends ConsumerState<ScheduleFormPage> {
  late DateTime _date;
  TimeOfDay? _time;
  late final TextEditingController _note;
  String? _programId;
  String? _dayId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing?.item;
    final now = today();
    final initial = s?.date ?? widget.initialDate ?? now;
    _date = initial.isBefore(now) && !_isEdit ? now : initial;
    _time = _parseTime(s?.startTime);
    _note = TextEditingController(text: s?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? hhmmText) {
    if (hhmmText == null) return null;
    final parts = hhmmText.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String? get _timeText =>
      _time == null ? null : hhmm(_time!.hour, _time!.minute);

  Future<void> _pickDate() async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: addDays(now, 365),
      helpText: 'Chọn ngày tập',
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Chọn giờ bắt đầu',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_isEdit && _dayId == null) {
      showSnack(context, 'Vui lòng chọn buổi tập');
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(scheduleApiProvider);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    try {
      final saved = _isEdit
          ? await api.update(
              widget.existing!.item.id,
              date: _date,
              startTime: _timeText,
              note: note,
              status: ScheduleStatus.scheduled,
            )
          : await api.create(
              workoutDayId: _dayId!,
              date: _date,
              startTime: _timeText,
              note: note,
            );
      if (!mounted) return;
      showSnack(
        context,
        _isEdit
            ? 'Đã dời lịch'
            : 'Đã xếp lịch ${viWeekday(_date)} ${viDate(_date)}',
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, _isEdit ? e.toString() : createErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'LẬP KẾ HOẠCH TẬP',
        title: _isEdit ? 'Dời lịch' : 'Xếp lịch tập',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          GymCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GymSectionHeader(
                  icon: Icons.fitness_center_rounded,
                  title: 'Nội dung buổi tập',
                ),
                const SizedBox(height: 12),
                if (_isEdit)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: GymColors.vibrantGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: GymColors.vibrantGreen,
                      ),
                    ),
                    title: Text(
                      widget.existing!.item.workoutDay.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      widget.existing!.item.workoutDay.programName,
                    ),
                  )
                else
                  ..._programAndDay(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GymCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GymSectionHeader(
                  icon: Icons.calendar_month_rounded,
                  title: 'Thời gian & Ghi chú',
                  accent: GymColors.bodyBlue,
                ),
                const SizedBox(height: 12),
                Material(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    key: const Key('schedule-date'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      color: GymColors.vibrantGreen,
                    ),
                    title: Text(
                      '${viWeekday(_date)}, ${viDate(_date)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Ngày tập'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: _saving ? null : _pickDate,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    key: const Key('schedule-time'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    leading: const Icon(
                      Icons.schedule_rounded,
                      color: GymColors.bodyBlue,
                    ),
                    title: Text(
                      _timeText ?? 'Chưa đặt giờ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Giờ bắt đầu (không bắt buộc)'),
                    trailing: _time == null
                        ? const Icon(Icons.edit_outlined, size: 20)
                        : IconButton(
                            tooltip: 'Bỏ giờ',
                            onPressed: () => setState(() => _time = null),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                    onTap: _saving ? null : _pickTime,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('schedule-note'),
                  controller: _note,
                  maxLength: 500,
                  decoration: gymInputDecoration(
                    context,
                    labelText: 'Ghi chú (không bắt buộc)',
                    prefixIcon: Icons.notes_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BusyButton(
            key: const Key('schedule-save'),
            busy: _saving,
            onPressed: _save,
            label: _isEdit ? 'Lưu ngày giờ mới' : 'Xếp lịch',
          ),
        ],
      ),
    );
  }

  List<Widget> _programAndDay() {
    final programs = ref.watch(myProgramsProvider);
    return programs.when(
      loading: () => [const Center(child: CircularProgressIndicator())],
      error: (e, _) => [
        ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(myProgramsProvider),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return const [
            StatusMessage(
              icon: Icons.event_note_outlined,
              text:
                  'Bạn chưa có giáo án. Hãy tạo hoặc chọn giáo án mẫu ở tab "Giáo án" trước.',
            ),
          ];
        }
        _programId ??=
            (items.where((p) => p.isActive).firstOrNull ?? items.first).id;
        return [
          DropdownButtonFormField<String>(
            key: const Key('schedule-program'),
            initialValue: _programId,
            isExpanded: true,
            decoration: gymInputDecoration(
              context,
              labelText: 'Giáo án',
              prefixIcon: Icons.event_note_rounded,
            ),
            items: [
              for (final p in items)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.isActive ? '${p.name} (đang dùng)' : p.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (id) => setState(() {
                    _programId = id;
                    _dayId = null;
                  }),
          ),
          const SizedBox(height: 14),
          _days(_programId!),
        ];
      },
    );
  }

  Widget _days(String programId) {
    final detail = ref.watch(programDetailProvider(programId));
    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorRetry(
        error: e,
        onRetry: () => ref.invalidate(programDetailProvider(programId)),
      ),
      data: (p) => RadioGroup<String>(
        groupValue: _dayId,
        onChanged: (id) {
          if (!_saving) setState(() => _dayId = id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buổi tập',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final d in p.days) _dayOption(d),
          ],
        ),
      ),
    );
  }

  Widget _dayOption(ProgramDay d) {
    final blocked = d.hasInactiveExercise;
    final selected = _dayId == d.id;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? GymColors.vibrantGreen.withValues(alpha: 0.08)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? GymColors.vibrantGreen
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: RadioListTile<String>(
        key: Key('schedule-day-${d.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        value: d.id,
        enabled: !blocked,
        title: Text(
          d.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          blocked
              ? 'Có bài đã ngừng sử dụng, hãy sửa giáo án trước'
              : d.exercises.map((e) => e.exerciseName).join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
