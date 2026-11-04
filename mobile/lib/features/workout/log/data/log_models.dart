import '../../../../core/format/date_format.dart';

/// docs/05 §8. Số liệu đều là dữ liệu thực tế đã lưu (snapshot), không phải kế hoạch.
class LogSet {
  const LogSet({
    required this.setNo,
    required this.reps,
    required this.weightKg,
  });

  factory LogSet.fromJson(Map<String, dynamic> json) => LogSet(
    setNo: json['setNo'] as int,
    reps: json['reps'] as int,
    weightKg: (json['weightKg'] as num).toDouble(),
  );

  final int setNo;
  final int reps;

  /// Tạ ngoài; 0 = không dùng tạ.
  final double weightKg;
}

class LogExercise {
  const LogExercise({
    required this.orderNo,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  factory LogExercise.fromJson(Map<String, dynamic> json) => LogExercise(
    orderNo: json['orderNo'] as int,
    exerciseId: json['exerciseId'] as String,
    exerciseName: json['exerciseName'] as String,
    sets: (json['sets'] as List)
        .map((e) => LogSet.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int orderNo;
  final String exerciseId;

  /// Tên lúc ghi; không đổi khi bài trong thư viện đổi tên hay bị ẩn.
  final String exerciseName;
  final List<LogSet> sets;
}

/// Phần chung của danh sách và chi tiết.
class LogSummary {
  const LogSummary({
    required this.id,
    this.scheduleId,
    required this.workoutDate,
    required this.workoutName,
    required this.programName,
    this.startedAt,
    this.endedAt,
    required this.exerciseCount,
    required this.setCount,
    required this.totalReps,
    required this.totalVolumeKg,
  });

  factory LogSummary.fromJson(Map<String, dynamic> json) => LogSummary(
    id: json['id'] as String,
    scheduleId: json['scheduleId'] as String?,
    workoutDate: parseIsoDate(json['workoutDate'] as String),
    workoutName: json['workoutName'] as String,
    programName: json['programName'] as String,
    startedAt: _instant(json['startedAt']),
    endedAt: _instant(json['endedAt']),
    exerciseCount: json['exerciseCount'] as int,
    setCount: json['setCount'] as int,
    totalReps: json['totalReps'] as int,
    totalVolumeKg: (json['totalVolumeKg'] as num).toDouble(),
  );

  final String id;
  final String? scheduleId;

  /// Ngày của lịch (theo múi giờ user), kể cả khi ghi muộn.
  final DateTime workoutDate;
  final String workoutName;
  final String programName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int exerciseCount;
  final int setCount;
  final int totalReps;

  /// Σ reps × kg, chỉ tạ ngoài.
  final double totalVolumeKg;

  /// Số phút giữa bắt đầu và kết thúc; null nếu thiếu một trong hai.
  int? get durationMinutes => startedAt != null && endedAt != null
      ? endedAt!.difference(startedAt!).inMinutes
      : null;
}

class LogDetail {
  const LogDetail({required this.summary, this.note, required this.exercises});

  factory LogDetail.fromJson(Map<String, dynamic> json) => LogDetail(
    summary: LogSummary.fromJson(json),
    note: json['note'] as String?,
    exercises: (json['exercises'] as List)
        .map((e) => LogExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final LogSummary summary;
  final String? note;
  final List<LogExercise> exercises;

  String get id => summary.id;
}

class LogPage {
  const LogPage({
    required this.items,
    required this.page,
    required this.totalItems,
    required this.hasNext,
  });

  factory LogPage.fromJson(Map<String, dynamic> json) => LogPage(
    items: (json['items'] as List)
        .map((e) => LogSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    page: json['page'] as int,
    totalItems: json['totalItems'] as int,
    hasNext: json['hasNext'] as bool,
  );

  final List<LogSummary> items;
  final int page;
  final int totalItems;
  final bool hasNext;
}

/// Giới hạn kỹ thuật, khớp backend (docs/04 BR-W08, docs/18).
abstract final class LogLimits {
  static const maxExercises = 20;
  static const maxSets = 20;
  static const repsMin = 1;
  static const repsMax = 1000;
  static const weightMax = 999.99;
  static const noteMax = 1000;
}

DateTime? _instant(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
