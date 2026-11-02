import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
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
    // Lịch cũ đã quá ngày: gợi ý hôm nay (server không nhận ngày đã qua khi đổi ngày).
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

  String? get _timeText => _time == null ? null : hhmm(_time!.hour, _time!.minute);

  Future<void> _pickDate() async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: addDays(now, 365),
      helpText: 'Chọn ngày tập',
    );
    // Hủy picker: giữ ngày cũ.
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
        _isEdit ? 'Đã dời lịch' : 'Đã xếp lịch ${viWeekday(_date)} ${viDate(_date)}',
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Dời lịch' : 'Xếp lịch tập')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_isEdit)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fitness_center),
              title: Text(widget.existing!.item.workoutDay.name),
              subtitle: Text(widget.existing!.item.workoutDay.programName),
            )
          else
            ..._programAndDay(),
          const Divider(),
          ListTile(
            key: const Key('schedule-date'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text('${viWeekday(_date)}, ${viDate(_date)}'),
            subtitle: const Text('Ngày tập'),
            trailing: const Icon(Icons.edit),
            onTap: _saving ? null : _pickDate,
          ),
          ListTile(
            key: const Key('schedule-time'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_timeText ?? 'Chưa đặt giờ'),
            subtitle: const Text('Giờ bắt đầu (không bắt buộc)'),
            trailing: _time == null
                ? const Icon(Icons.edit)
                : IconButton(
                    tooltip: 'Bỏ giờ',
                    onPressed: () => setState(() => _time = null),
                    icon: const Icon(Icons.clear),
                  ),
            onTap: _saving ? null : _pickTime,
          ),
          TextField(
            key: const Key('schedule-note'),
            controller: _note,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (không bắt buộc)',
            ),
          ),
          const SizedBox(height: 16),
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
        ErrorRetry(error: e, onRetry: () => ref.invalidate(myProgramsProvider)),
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
        // Mặc định giáo án đang dùng.
        _programId ??= (items.where((p) => p.isActive).firstOrNull ?? items.first).id;
        return [
          DropdownButtonFormField<String>(
            key: const Key('schedule-program'),
            initialValue: _programId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Giáo án'),
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
          const SizedBox(height: 8),
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
            Text('Buổi tập', style: Theme.of(context).textTheme.titleSmall),
            for (final d in p.days) _dayOption(d),
          ],
        ),
      ),
    );
  }

  Widget _dayOption(ProgramDay d) {
    final blocked = d.hasInactiveExercise;
    return RadioListTile<String>(
      key: Key('schedule-day-${d.id}'),
      contentPadding: EdgeInsets.zero,
      value: d.id,
      enabled: !blocked,
      title: Text(d.name),
      subtitle: Text(
        blocked
            ? 'Có bài đã ngừng sử dụng, hãy sửa giáo án trước'
            : d.exercises.map((e) => e.exerciseName).join(', '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
