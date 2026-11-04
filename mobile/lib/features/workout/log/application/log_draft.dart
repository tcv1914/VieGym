import '../../../../core/format/number_format.dart';
import '../../program/data/program_models.dart';
import '../../schedule/data/schedule_models.dart';
import '../data/log_models.dart';

/// Một hiệp đang nhập. Ô trống là "chưa nhập", không được hiểu là 0.
class DraftSet {
  DraftSet({this.reps = '', this.weight = ''}) : key = LogDraft.newKey();

  final int key;
  String reps;
  String weight;
}

/// Một bài của buổi. Bỏ chọn = chưa tập, không gửi lên (không tạo hiệp 0 giả).
class DraftLogExercise {
  DraftLogExercise({
    required this.exerciseId,
    required this.name,
    this.targetSets,
    this.targetReps,
    this.included = true,
    List<DraftSet>? sets,
  }) : key = LogDraft.newKey(),
       sets = sets ?? [DraftSet()];

  final int key;
  final String exerciseId;
  final String name;

  /// Kế hoạch, chỉ để gợi ý.
  final int? targetSets;
  final int? targetReps;
  bool included;
  final List<DraftSet> sets;

  /// Ô số lần còn trống được điền số lần dự kiến; mức tạ vẫn để người dùng nhập.
  void fillPlannedReps() {
    if (targetReps == null) return;
    for (final s in sets) {
      if (s.reps.trim().isEmpty) s.reps = '$targetReps';
    }
  }
}

/// Bản nháp ghi buổi tập, giữ trong màn hình: lỗi mạng hay 409 không làm mất dữ liệu.
///
/// Thời điểm: lịch hôm nay → bắt đầu = lúc mở form, kết thúc = lần bấm lưu đầu tiên (giữ nguyên
/// khi gửi lại). Lịch ngày đã qua → không gửi giờ, ngày tập vẫn là ngày của lịch.
class LogDraft {
  LogDraft({required this.scheduleId, required this.exercises, this.startedAt});

  factory LogDraft.fromSchedule(
    ScheduleDetail detail, {
    required DateTime now,
  }) {
    final s = detail.item;
    final isToday = s.date == DateTime.utc(now.year, now.month, now.day);
    return LogDraft(
      scheduleId: s.id,
      startedAt: isToday ? now : null,
      exercises: [
        for (final ProgramExercise e in detail.exercises)
          DraftLogExercise(
            exerciseId: e.exerciseId,
            name: e.exerciseName,
            targetSets: e.targetSets,
            targetReps: e.targetReps,
            sets: [for (var i = 0; i < e.targetSets; i++) DraftSet()],
          ),
      ],
    );
  }

  final String scheduleId;
  final List<DraftLogExercise> exercises;
  final DateTime? startedAt;
  DateTime? endedAt;
  String note = '';

  static int _nextKey = 0;
  static int newKey() => _nextKey++;

  List<DraftLogExercise> get included =>
      exercises.where((e) => e.included).toList();

  int get setCount => included.fold(0, (sum, e) => sum + e.sets.length);

  /// Lỗi theo đường dẫn giống backend (`exercises[0].sets[1].reps`), chỉ số theo danh sách
  /// bài được gửi (đã bỏ bài không chọn).
  Map<String, String> validate() {
    final errors = <String, String>{};
    final list = included;
    if (list.isEmpty) {
      errors['exercises'] = 'Chọn ít nhất một bài đã tập';
    } else if (list.length > LogLimits.maxExercises) {
      errors['exercises'] = 'Tối đa ${LogLimits.maxExercises} bài mỗi buổi';
    }
    for (var i = 0; i < list.length; i++) {
      final sets = list[i].sets;
      if (sets.isEmpty || sets.length > LogLimits.maxSets) {
        errors['exercises[$i].sets'] =
            'Mỗi bài từ 1 đến ${LogLimits.maxSets} hiệp';
      }
      for (var j = 0; j < sets.length; j++) {
        final path = 'exercises[$i].sets[$j]';
        final reps = int.tryParse(sets[j].reps.trim());
        if (sets[j].reps.trim().isEmpty) {
          errors['$path.reps'] = 'Nhập số lần';
        } else if (reps == null ||
            reps < LogLimits.repsMin ||
            reps > LogLimits.repsMax) {
          errors['$path.reps'] =
              'Số lần nguyên từ ${LogLimits.repsMin} đến ${LogLimits.repsMax}';
        }
        if (sets[j].weight.trim().isEmpty) {
          errors['$path.weightKg'] = 'Nhập kg (0 nếu không tạ)';
        } else if (parseViDecimal(sets[j].weight, maxDecimals: 2) == null) {
          errors['$path.weightKg'] = '0–999,99, tối đa 2 số lẻ';
        }
      }
    }
    if (note.trim().length > LogLimits.noteMax) {
      errors['note'] = 'Ghi chú tối đa ${LogLimits.noteMax} ký tự';
    }
    return errors;
  }

  /// Body POST. Gọi sau [validate] không lỗi. [submittedAt] chỉ được ghi ở lần đầu.
  Map<String, dynamic> toPayload(DateTime submittedAt) {
    if (startedAt != null) endedAt ??= submittedAt;
    return {
      'scheduleId': scheduleId,
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'endedAt': endedAt?.toUtc().toIso8601String(),
      'note': note.trim().isEmpty ? null : note.trim(),
      'exercises': [
        for (final e in included)
          {
            'exerciseId': e.exerciseId,
            'sets': [
              for (final s in e.sets)
                {
                  'reps': int.parse(s.reps.trim()),
                  'weightKg': parseViDecimal(s.weight, maxDecimals: 2),
                },
            ],
          },
      ],
    };
  }

  /// Đường dẫn lỗi `exercises[i]...` → bài tương ứng trong danh sách đầy đủ (kể cả bài bỏ chọn).
  DraftLogExercise? exerciseForPath(int includedIndex) {
    final list = included;
    return includedIndex < list.length ? list[includedIndex] : null;
  }
}
