/// Giáo án theo docs/05 §6. Thứ tự buổi/bài do server gán theo thứ tự mảng.
class ProgramSummary {
  const ProgramSummary({
    required this.id,
    required this.name,
    this.description,
    required this.isTemplate,
    required this.isActive,
    required this.dayCount,
  });

  factory ProgramSummary.fromJson(Map<String, dynamic> json) => ProgramSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    isTemplate: json['isTemplate'] as bool,
    isActive: json['isActive'] as bool,
    dayCount: json['dayCount'] as int,
  );

  final String id;
  final String name;
  final String? description;
  final bool isTemplate;
  final bool isActive;
  final int dayCount;
}

class ProgramExercise {
  const ProgramExercise({
    required this.id,
    required this.orderNo,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseActive,
    this.thumbnailUrl,
    required this.targetSets,
    required this.targetReps,
    required this.restSeconds,
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> json) =>
      ProgramExercise(
        id: json['id'] as String,
        orderNo: json['orderNo'] as int,
        exerciseId: json['exerciseId'] as String,
        exerciseName: json['exerciseName'] as String,
        exerciseActive: json['exerciseActive'] as bool? ?? true,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        targetSets: json['targetSets'] as int,
        targetReps: json['targetReps'] as int,
        restSeconds: json['restSeconds'] as int,
      );

  final String id;
  final int orderNo;
  final String exerciseId;
  final String exerciseName;

  /// false: bài đã bị ẩn khỏi thư viện, cần thay trước khi lưu hoặc xếp lịch.
  final bool exerciseActive;
  final String? thumbnailUrl;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
}

class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.dayOrder,
    required this.name,
    required this.exercises,
  });

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
    id: json['id'] as String,
    dayOrder: json['dayOrder'] as int,
    name: json['name'] as String,
    exercises: (json['exercises'] as List)
        .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final int dayOrder;
  final String name;
  final List<ProgramExercise> exercises;

  bool get hasInactiveExercise => exercises.any((e) => !e.exerciseActive);
}

class ProgramDetail {
  const ProgramDetail({
    required this.id,
    required this.name,
    this.description,
    required this.isTemplate,
    required this.isActive,
    this.sourceTemplateId,
    required this.version,
    required this.days,
  });

  factory ProgramDetail.fromJson(Map<String, dynamic> json) => ProgramDetail(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    isTemplate: json['isTemplate'] as bool,
    isActive: json['isActive'] as bool,
    sourceTemplateId: json['sourceTemplateId'] as String?,
    version: json['version'] as int? ?? 0,
    days: (json['days'] as List)
        .map((e) => ProgramDay.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String name;
  final String? description;
  final bool isTemplate;
  final bool isActive;
  final String? sourceTemplateId;

  /// Gửi lại khi PUT; lệch với server → 409 VERSION_CONFLICT.
  final int version;
  final List<ProgramDay> days;
}

/// Giới hạn kỹ thuật (docs/03 §5, docs/05 §6), không phải khuyến nghị luyện tập.
abstract final class ProgramLimits {
  static const maxDays = 7;
  static const maxExercisesPerDay = 15;
  static const nameMax = 100;
  static const descriptionMax = 1000;
  static const setsMin = 1, setsMax = 10;
  static const repsMin = 1, repsMax = 100;
  static const restMin = 0, restMax = 600;
}
