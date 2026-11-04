import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/network/api_client.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/data/schedule_api.dart';
import '../../schedule/data/schedule_models.dart';
import '../../workout_widgets.dart';
import '../application/log_draft.dart';
import '../application/log_providers.dart';
import '../data/log_api.dart';
import '../data/log_models.dart';
import 'log_detail_page.dart';

/// Ghi kết quả thực tế của một lịch (UC06). Kế hoạch chỉ hiện làm gợi ý; ô trống không phải 0.
///
/// Chỉ coi là đã lưu khi server trả 201, hoặc khi kiểm tra lại lịch thấy đã có log
/// (mất mạng sau khi gửi). Không tự gửi lại.
class LogFormPage extends ConsumerStatefulWidget {
  const LogFormPage({super.key, required this.schedule, this.clock});

  final ScheduleDetail schedule;

  /// Cho test; mặc định giờ máy.
  final DateTime Function()? clock;

  @override
  ConsumerState<LogFormPage> createState() => _LogFormPageState();
}

class _LogFormPageState extends ConsumerState<LogFormPage> {
  late final LogDraft _draft;
  final _controllers = <int, TextEditingController>{};
  late final TextEditingController _note;
  Map<String, String> _errors = {};
  bool _busy = false;
  bool _dirty = false;

  /// Lỗi chung (409, mất mạng) hiện trên đầu form.
  String? _banner;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _draft = LogDraft.fromSchedule(widget.schedule, now: _now());
    _note = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  /// Controller theo key ổn định của hiệp (không theo vị trí).
  TextEditingController _controller(int key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  void _disposeSet(DraftSet s) {
    _controllers.remove(s.key * 2)?.dispose();
    _controllers.remove(s.key * 2 + 1)?.dispose();
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _addSet(DraftLogExercise e) {
    if (e.sets.length >= LogLimits.maxSets) return;
    final last = e.sets.isEmpty ? null : e.sets.last;
    // Hiệp mới lấy lại mức tạ của hiệp trước cho đỡ gõ; số lần để trống.
    setState(() {
      e.sets.add(DraftSet(weight: last?.weight ?? ''));
      _dirty = true;
    });
  }

  void _removeSet(DraftLogExercise e, DraftSet s) {
    setState(() {
      e.sets.remove(s);
      _disposeSet(s);
      // Lỗi gắn theo vị trí hiệp; xóa dòng thì vị trí đổi, kiểm tra lại khi bấm lưu.
      _errors = {};
      _dirty = true;
    });
  }

  void _fillPlanned(DraftLogExercise e) {
    setState(() {
      e.fillPlannedReps();
      for (final s in e.sets) {
        _controllers[s.key * 2]?.text = s.reps;
      }
      _dirty = true;
    });
  }

  String? _err(String path) => _errors[path];

  Future<void> _submit() async {
    _draft.note = _note.text;
    final errors = _draft.validate();
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) {
      showSnack(context, errors['exercises'] ?? 'Kiểm tra lại các ô báo đỏ');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn thành buổi tập?'),
        content: Text(
          'Lưu ${_draft.included.length} bài, ${_draft.setCount} hiệp. '
          'Sau khi lưu không sửa được kết quả.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Xem lại'),
          ),
          FilledButton(
            key: const Key('log-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final log = await ref
          .read(logApiProvider)
          .create(_draft.toPayload(_now()));
      _saved(log.id);
    } on ApiException catch (e) {
      await _handleApiError(e);
    } on NetworkException {
      await _verifyAfterNetworkError();
    } catch (e) {
      if (mounted) setState(() => _banner = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshLists() {
    ref.invalidate(weekSchedulesProvider);
    ref.invalidate(scheduleDetailProvider(_draft.scheduleId));
    ref.read(logHistoryVersionProvider.notifier).bump();
  }

  void _saved(String logId) {
    _refreshLists();
    if (!mounted) return;
    _dirty = false;
    showSnack(context, 'Đã lưu buổi tập');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LogDetailPage(id: logId)),
    );
  }

  Future<void> _handleApiError(ApiException e) async {
    if (e.code == 'WORKOUT_ALREADY_LOGGED') {
      _refreshLists();
      final logId = e.data['workoutLogId'] as String?;
      setState(() {
        _busy = false;
        _banner = 'Buổi này đã được ghi nhận trước đó. Kết quả đã lưu không bị thay đổi.';
      });
      if (logId != null) await _offerExisting(logId);
      return;
    }
    if (e.code == 'VALIDATION_ERROR' || e.code == 'EXERCISE_INACTIVE') {
      setState(() {
        _errors = e.fieldErrors;
        _banner = e.fieldErrors.isEmpty
            ? e.message
            : 'Kiểm tra lại: ${e.message}';
      });
      return;
    }
    // 409 INVALID_STATE (đã hủy ở nơi khác, chưa tới ngày), 404, 5xx: giữ nháp, báo lỗi.
    if (e.statusCode == 409 || e.statusCode == 404) _refreshLists();
    setState(() => _banner = e.message);
  }

  Future<void> _offerExisting(String logId) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đã có kết quả'),
        content: const Text(
          'Buổi này đã được lưu (có thể từ lần gửi trước). Mở kết quả đã lưu? '
          'Dữ liệu đang nhập vẫn giữ ở màn này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            key: const Key('log-open-existing'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mở kết quả'),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LogDetailPage(id: logId)));
    }
  }

  /// Mất mạng sau khi gửi: server có thể đã lưu. Hỏi lại lịch thay vì đoán.
  Future<void> _verifyAfterNetworkError() async {
    try {
      final detail = await ref
          .read(scheduleApiProvider)
          .detail(_draft.scheduleId);
      final logId = detail.item.workoutLogId;
      if (logId != null) {
        _saved(logId);
        return;
      }
      if (mounted) {
        setState(
          () => _banner = 'Máy chủ chưa nhận được kết quả. Dữ liệu vẫn còn, bấm "Hoàn thành" để gửi lại.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _banner =
              'Chưa xác nhận được buổi tập đã lưu hay chưa (mất kết nối). '
              'Dữ liệu vẫn còn; khi có mạng hãy bấm "Hoàn thành" — nếu đã lưu, app sẽ mở kết quả cũ.',
        );
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ dữ liệu đang nhập?'),
        content: const Text('Kết quả chưa được lưu sẽ mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục nhập'),
          ),
          TextButton(
            key: const Key('log-discard'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule.item;
    final includedKeys = [for (final e in _draft.included) e.key];
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) {
          _dirty = false;
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Ghi buổi: ${s.workoutDay.name}')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              '${viWeekday(s.date)}, ${viDate(s.date)} · ${s.workoutDay.programName}',
            ),
            const SizedBox(height: 4),
            Text(
              _draft.startedAt != null
                  ? 'Bắt đầu lúc ${hhmm(_draft.startedAt!.hour, _draft.startedAt!.minute)}; '
                        'kết thúc tính lúc bấm lưu.'
                  : 'Ghi muộn cho ngày đã qua: lưu theo ngày của lịch, không ghi giờ.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Nhập số lần và mức tạ thực tế (kg, tạ ngoài; 0 nếu không dùng tạ). '
              'Bỏ chọn bài chưa tập.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_banner != null)
              Card(
                key: const Key('log-banner'),
                color: Theme.of(context).colorScheme.errorContainer,
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_banner!),
                ),
              ),
            if (_err('exercises') != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _err('exercises')!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            for (final e in _draft.exercises)
              _exerciseCard(e, includedKeys.indexOf(e.key)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('log-note'),
              controller: _note,
              maxLines: 3,
              maxLength: LogLimits.noteMax,
              enabled: !_busy,
              onChanged: (_) => _changed(),
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: const OutlineInputBorder(),
                errorText: _err('note'),
              ),
            ),
            const SizedBox(height: 8),
            BusyButton(
              key: const Key('log-submit'),
              busy: _busy,
              onPressed: _submit,
              label: 'Hoàn thành buổi tập',
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(DraftLogExercise e, int index) {
    final theme = Theme.of(context);
    final base = 'exercises[$index]';
    final plan = e.targetSets != null && e.targetReps != null
        ? 'Kế hoạch: ${e.targetSets} hiệp × ${e.targetReps} lần'
        : null;
    return Card(
      key: Key('log-ex-${e.key}'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              key: Key('log-ex-include-${e.key}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: e.included,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      e.included = v ?? false;
                      _errors = {};
                      _dirty = true;
                    }),
              title: Text(e.name),
              subtitle: Text(
                e.included
                    ? (plan ?? 'Ngoài kế hoạch')
                    : 'Chưa tập — không lưu',
              ),
            ),
            if (index >= 0 && _err('$base.exerciseId') != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  _err('$base.exerciseId')!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (e.included) ...[
              for (var j = 0; j < e.sets.length; j++)
                _setRow(e, e.sets[j], j, '$base.sets[$j]'),
              if (_err('$base.sets') != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _err('$base.sets')!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: Key('log-add-set-${e.key}'),
                    onPressed: _busy || e.sets.length >= LogLimits.maxSets
                        ? null
                        : () => _addSet(e),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm hiệp'),
                  ),
                  if (e.targetReps != null)
                    TextButton(
                      key: Key('log-fill-${e.key}'),
                      onPressed: _busy ? null : () => _fillPlanned(e),
                      child: Text('Điền ${e.targetReps} lần vào ô trống'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _setRow(DraftLogExercise e, DraftSet s, int j, String path) {
    return Padding(
      key: ValueKey('log-set-${s.key}'),
      padding: const EdgeInsets.only(left: 12, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text('Hiệp ${j + 1}'),
            ),
          ),
          Expanded(
            child: TextField(
              key: Key('log-reps-${s.key}'),
              controller: _controller(s.key * 2, s.reps),
              enabled: !_busy,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                s.reps = v;
                _changed();
              },
              decoration: InputDecoration(
                labelText: 'Số lần',
                hintText: e.targetReps?.toString(),
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: _err('$path.reps'),
                errorMaxLines: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('log-kg-${s.key}'),
              controller: _controller(s.key * 2 + 1, s.weight),
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                s.weight = v;
                _changed();
              },
              decoration: InputDecoration(
                labelText: 'Tạ (kg)',
                hintText: '0 = không tạ',
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: _err('$path.weightKg'),
                errorMaxLines: 2,
              ),
            ),
          ),
          IconButton(
            key: Key('log-remove-set-${s.key}'),
            tooltip: 'Xóa hiệp',
            onPressed: _busy || e.sets.length <= 1
                ? null
                : () => _removeSet(e, s),
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}
