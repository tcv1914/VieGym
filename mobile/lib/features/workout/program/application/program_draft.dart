import '../data/program_models.dart';

/// Bản nháp của form giáo án, giữ trong màn hình (lỗi mạng không mất dữ liệu đã nhập).
///
/// Mỗi dòng có [key] riêng, không theo vị trí: xóa hay đổi thứ tự không làm số liệu
/// nhảy sang dòng khác. Lỗi dùng cùng đường dẫn với backend
/// (`days[0].exercises[1].targetSets`) nên lỗi server hiện đúng dòng.
class ProgramDraft {
  ProgramDraft({
    this.programId,
    this.version,
    this.name = '',
    this.description = '',
    List<DraftDay>? days,
  }) : days = days ?? [];

  factory ProgramDraft.fromDetail(ProgramDetail p) => ProgramDraft(
    programId: p.id,
    version: p.version,
    name: p.name,
    description: p.description ?? '',
    days: [
      for (final d in p.days)
        DraftDay(
          id: d.id,
          name: d.name,
          exercises: [
            for (final e in d.exercises)
              DraftExercise(
                exerciseId: e.exerciseId,
                exerciseName: e.exerciseName,
                thumbnailUrl: e.thumbnailUrl,
                active: e.exerciseActive,
                sets: '${e.targetSets}',
                reps: '${e.targetReps}',
                rest: '${e.restSeconds}',
              ),
          ],
        ),
    ],
  );

  /// null = giáo án mới (POST).
  final String? programId;
  final int? version;
  String name;
  String description;
  final List<DraftDay> days;

  bool get isNew => programId == null;

  static int _nextKey = 0;
  static int newKey() => _nextKey++;

  DraftDay addDay() {
    final day = DraftDay(name: 'Buổi ${days.length + 1}');
    days.add(day);
    return day;
  }

  static void move<T>(List<T> list, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= list.length) return;
    final item = list.removeAt(index);
    list.insert(target, item);
  }

  /// Kiểm tra ở app trước khi gửi; server kiểm tra lại toàn bộ.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (name.trim().isEmpty) {
      errors['name'] = 'Vui lòng nhập tên giáo án';
    } else if (name.trim().length > ProgramLimits.nameMax) {
      errors['name'] = 'Tên giáo án tối đa ${ProgramLimits.nameMax} ký tự';
    }
    if (description.trim().length > ProgramLimits.descriptionMax) {
      errors['description'] =
          'Mô tả tối đa ${ProgramLimits.descriptionMax} ký tự';
    }
    if (days.isEmpty || days.length > ProgramLimits.maxDays) {
      errors['days'] = 'Giáo án có từ 1 đến ${ProgramLimits.maxDays} buổi';
    }
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day.name.trim().isEmpty) {
        errors['days[$i].name'] = 'Vui lòng nhập tên buổi';
      } else if (day.name.trim().length > ProgramLimits.nameMax) {
        errors['days[$i].name'] =
            'Tên buổi tối đa ${ProgramLimits.nameMax} ký tự';
      }
      if (day.exercises.isEmpty ||
          day.exercises.length > ProgramLimits.maxExercisesPerDay) {
        errors['days[$i].exercises'] =
            'Mỗi buổi có từ 1 đến ${ProgramLimits.maxExercisesPerDay} bài';
      }
      final seen = <String>{};
      for (var j = 0; j < day.exercises.length; j++) {
        final e = day.exercises[j];
        final path = 'days[$i].exercises[$j]';
        if (!seen.add(e.exerciseId)) {
          errors['$path.exerciseId'] = 'Bài tập đã có trong buổi này';
        } else if (!e.active) {
          errors['$path.exerciseId'] = 'Bài này đã ngừng sử dụng, hãy thay bài khác';
        }
        _range(errors, '$path.targetSets', e.sets, ProgramLimits.setsMin,
            ProgramLimits.setsMax, 'Số hiệp');
        _range(errors, '$path.targetReps', e.reps, ProgramLimits.repsMin,
            ProgramLimits.repsMax, 'Số lần');
        _range(errors, '$path.restSeconds', e.rest, ProgramLimits.restMin,
            ProgramLimits.restMax, 'Thời gian nghỉ', unit: ' giây');
      }
    }
    return errors;
  }

  static void _range(
    Map<String, String> errors,
    String path,
    String text,
    int min,
    int max,
    String label, {
    String unit = '',
  }) {
    final value = parseWholeNumber(text);
    if (value == null || value < min || value > max) {
      errors[path] = '$label từ $min đến $max$unit';
    }
  }

  /// Body cho POST/PUT. Chỉ gọi khi [validate] rỗng. Không gửi userId/isTemplate/dayOrder.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': description.trim().isEmpty ? null : description.trim(),
    'version': ?version,
    'days': [
      for (final d in days)
        {
          'id': ?d.id,
          'name': d.name.trim(),
          'exercises': [
            for (final e in d.exercises)
              {
                'exerciseId': e.exerciseId,
                'targetSets': parseWholeNumber(e.sets),
                'targetReps': parseWholeNumber(e.reps),
                'restSeconds': parseWholeNumber(e.rest),
              },
          ],
        },
    ],
  };
}

class DraftDay {
  DraftDay({this.id, this.name = '', List<DraftExercise>? exercises})
    : key = ProgramDraft.newKey(),
      exercises = exercises ?? [];

  final int key;

  /// ID buổi đã có trên server; gửi lại để giữ buổi (lịch đã xếp vẫn trỏ vào nó).
  final String? id;
  String name;
  final List<DraftExercise> exercises;

  bool contains(String exerciseId) =>
      exercises.any((e) => e.exerciseId == exerciseId);
}

class DraftExercise {
  DraftExercise({
    required this.exerciseId,
    required this.exerciseName,
    this.thumbnailUrl,
    this.active = true,
    this.sets = '3',
    this.reps = '10',
    this.rest = '60',
  }) : key = ProgramDraft.newKey();

  final int key;
  final String exerciseId;
  final String exerciseName;
  final String? thumbnailUrl;
  final bool active;
  String sets;
  String reps;
  String rest;
}

/// "12" → 12; rỗng, số âm, có dấu chấm/phẩy → null.
int? parseWholeNumber(String text) {
  final t = text.trim();
  if (!RegExp(r'^\d{1,4}$').hasMatch(t)) return null;
  return int.parse(t);
}
