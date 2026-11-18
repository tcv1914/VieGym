import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../../exercise/data/exercise_models.dart';
import '../../../exercise/presentation/exercise_media.dart';
import '../../workout_widgets.dart';
import '../application/program_draft.dart';
import '../application/program_providers.dart';
import '../data/program_api.dart';
import '../data/program_models.dart';
import 'exercise_picker_page.dart';

/// Tạo ([initial] null) hoặc sửa giáo án. Lưu cả cấu trúc một lần; pop trả về
/// [ProgramDetail] đã lưu. Bản nháp nằm trong State: lỗi mạng không mất dữ liệu.
class ProgramFormPage extends ConsumerStatefulWidget {
  const ProgramFormPage({super.key, this.initial});

  final ProgramDetail? initial;

  @override
  ConsumerState<ProgramFormPage> createState() => _ProgramFormPageState();
}

class _ProgramFormPageState extends ConsumerState<ProgramFormPage> {
  late final ProgramDraft _draft = widget.initial == null
      ? (ProgramDraft()..addDay())
      : ProgramDraft.fromDetail(widget.initial!);
  Map<String, String> _errors = {};
  bool _dirty = false;
  bool _saving = false;

  void _changed([String? path]) {
    final clearError = path != null && _errors.containsKey(path);
    if (_dirty && !clearError) return;
    setState(() {
      _dirty = true;
      if (clearError) _errors = {..._errors}..remove(path);
    });
  }

  void _restructure(VoidCallback change) => setState(() {
    change();
    _dirty = true;
    _errors = {};
  });

  Future<void> _addExercise(DraftDay day) async {
    final picked = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(
        builder: (_) => ExercisePickerPage(
          alreadyInDay: day.exercises.map((e) => e.exerciseId).toSet(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (day.contains(picked.id)) {
      showSnack(context, 'Bài tập đã có trong buổi này');
      return;
    }
    _restructure(
      () => day.exercises.add(
        DraftExercise(
          exerciseId: picked.id,
          exerciseName: picked.name,
          thumbnailUrl: picked.thumbnailUrl,
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final errors = _draft.validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      showSnack(context, _summary(errors));
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(programApiProvider);
    try {
      final saved = _draft.isNew
          ? await api.create(_draft.toJson())
          : await api.update(_draft.programId!, _draft.toJson());
      ref.invalidate(myProgramsProvider);
      if (!mounted) return;
      showSnack(context, 'Đã lưu giáo án');
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.fieldErrors;
      });
      if (e.code == 'VERSION_CONFLICT') {
        await _conflict(e.message);
      } else {
        showSnack(
          context,
          e.fieldErrors.isEmpty ? e.message : _summary(e.fieldErrors),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, _draft.isNew ? createErrorText(e) : e.toString());
    }
  }

  String _summary(Map<String, String> errors) => errors.length == 1
      ? errors.values.first
      : '${errors.values.first} (và ${errors.length - 1} lỗi khác)';

  Future<void> _conflict(String message) async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giáo án đã thay đổi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            key: const Key('program-conflict-reload'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tải bản mới'),
          ),
        ],
      ),
    );
    if (reload == true && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ thay đổi?'),
          content: const Text('Những gì bạn vừa nhập chưa được lưu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại'),
            ),
            TextButton(
              key: const Key('program-discard'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bỏ thay đổi'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: GymScaffold(
        appBar: GymAppBar(
          eyebrow: 'THIẾT KẾ LỘ TRÌNH',
          title: d.isNew ? 'Tạo giáo án' : 'Sửa giáo án',
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: BusyButton(
                key: const Key('program-save'),
                compact: true,
                busy: _saving,
                onPressed: _save,
                label: 'Lưu',
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            GymCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('program-name'),
                    initialValue: d.name,
                    maxLength: ProgramLimits.nameMax,
                    decoration: gymInputDecoration(
                      context,
                      labelText: 'Tên giáo án',
                      prefixIcon: Icons.event_note_rounded,
                    ).copyWith(errorText: _errors['name']),
                    onChanged: (v) {
                      d.name = v;
                      _changed('name');
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('program-description'),
                    initialValue: d.description,
                    maxLength: ProgramLimits.descriptionMax,
                    maxLines: 3,
                    minLines: 1,
                    decoration: gymInputDecoration(
                      context,
                      labelText: 'Mô tả (không bắt buộc)',
                      prefixIcon: Icons.notes_rounded,
                    ).copyWith(errorText: _errors['description']),
                    onChanged: (v) {
                      d.description = v;
                      _changed('description');
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.isNew
                        ? 'Số hiệp, số lần và thời gian nghỉ là kế hoạch bạn tự đặt; mọi bài đều tính theo số lần.'
                        : 'Thay đổi chỉ áp cho giáo án và các buổi chưa tập. Buổi bị gỡ vẫn được giữ trong lịch đã xếp.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_errors['days'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errors['days']!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            for (var i = 0; i < d.days.length; i++) _dayCard(i),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('program-add-day'),
              style: OutlinedButton.styleFrom(
                foregroundColor: GymColors.heroMid,
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(
                  color: GymColors.vibrantGreen.withValues(alpha: 0.55),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: d.days.length >= ProgramLimits.maxDays
                  ? null
                  : () => _restructure(d.addDay),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                d.days.length >= ProgramLimits.maxDays
                    ? 'Tối đa ${ProgramLimits.maxDays} buổi'
                    : 'Thêm buổi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(int i) {
    final d = _draft;
    final day = d.days[i];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey('day-${day.key}'),
      padding: const EdgeInsets.only(top: 14),
      child: GymCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('day-name-$i'),
                    initialValue: day.name,
                    maxLength: ProgramLimits.nameMax,
                    decoration: gymInputDecoration(
                      context,
                      labelText: 'Tên buổi ${i + 1}',
                      prefixIcon: Icons.fitness_center_rounded,
                    ).copyWith(
                      counterText: '',
                      errorText: _errors['days[$i].name'],
                    ),
                    onChanged: (v) {
                      day.name = v;
                      _changed('days[$i].name');
                    },
                  ),
                ),
                const SizedBox(width: 4),
                _MoveButtons(
                  index: i,
                  length: d.days.length,
                  onMove: (delta) =>
                      _restructure(() => ProgramDraft.move(d.days, i, delta)),
                ),
                IconButton(
                  tooltip: 'Xóa buổi',
                  onPressed: d.days.length <= 1
                      ? null
                      : () => _restructure(() => d.days.removeAt(i)),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: d.days.length <= 1 ? null : scheme.error,
                  ),
                ),
              ],
            ),
            if (_errors['days[$i].exercises'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errors['days[$i].exercises']!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            for (var j = 0; j < day.exercises.length; j++) _exerciseRow(i, j),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: Key('day-add-exercise-$i'),
              style: FilledButton.styleFrom(
                backgroundColor: GymColors.vibrantGreen.withValues(alpha: 0.12),
                foregroundColor: GymColors.heroMid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: day.exercises.length >= ProgramLimits.maxExercisesPerDay
                  ? null
                  : () => _addExercise(day),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm bài từ thư viện'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseRow(int i, int j) {
    final day = _draft.days[i];
    final e = day.exercises[j];
    final path = 'days[$i].exercises[$j]';
    final exerciseError = _errors['$path.exerciseId'];
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: ValueKey('exercise-${e.key}'),
      margin: const EdgeInsets.only(top: 10, right: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExerciseThumbnail(url: e.thumbnailUrl, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (exerciseError != null)
                      Text(
                        exerciseError,
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                  ],
                ),
              ),
              _MoveButtons(
                index: j,
                length: day.exercises.length,
                onMove: (delta) => _restructure(
                  () => ProgramDraft.move(day.exercises, j, delta),
                ),
              ),
              IconButton(
                tooltip: 'Bỏ bài',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _restructure(() => day.exercises.removeAt(j)),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _number(
                '$path.targetSets',
                'Số hiệp',
                'hiệp',
                e.sets,
                (v) => e.sets = v,
              ),
              const SizedBox(width: 8),
              _number(
                '$path.targetReps',
                'Số lần',
                'lần',
                e.reps,
                (v) => e.reps = v,
              ),
              const SizedBox(width: 8),
              _number(
                '$path.restSeconds',
                'Nghỉ',
                'giây',
                e.rest,
                (v) => e.rest = v,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _number(
    String path,
    String label,
    String unit,
    String value,
    ValueChanged<String> onChanged,
  ) => Expanded(
    child: TextFormField(
      key: Key(path),
      initialValue: value,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: gymInputDecoration(
        context,
        labelText: label,
        suffixText: unit,
      ).copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        errorText: _errors[path],
        errorMaxLines: 2,
      ),
      onChanged: (v) {
        onChanged(v);
        _changed(path);
      },
    ),
  );
}

class _MoveButtons extends StatelessWidget {
  const _MoveButtons({
    required this.index,
    required this.length,
    required this.onMove,
  });

  final int index;
  final int length;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Lên',
        visualDensity: VisualDensity.compact,
        onPressed: index == 0 ? null : () => onMove(-1),
        icon: const Icon(Icons.arrow_upward_rounded, size: 19),
      ),
      IconButton(
        tooltip: 'Xuống',
        visualDensity: VisualDensity.compact,
        onPressed: index == length - 1 ? null : () => onMove(1),
        icon: const Icon(Icons.arrow_downward_rounded, size: 19),
      ),
    ],
  );
}
