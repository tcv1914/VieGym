import '../../../../core/format/date_format.dart';
import '../../program/data/program_models.dart';

/// docs/05 §7. `scheduledDate` là ngày theo múi giờ user (không có giờ UTC) nên nhóm theo
/// ngày hiển thị trực tiếp, không lệch ngày.
enum ScheduleStatus {
  scheduled('SCHEDULED'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const ScheduleStatus(this.code);

  final String code;

  static ScheduleStatus parse(String code) =>
      values.firstWhere((s) => s.code == code);
}

class ScheduleDayRef {
  const ScheduleDayRef({
    required this.id,
    required this.name,
    required this.programId,
    required this.programName,
    required this.archived,
  });

  factory ScheduleDayRef.fromJson(Map<String, dynamic> json) => ScheduleDayRef(
    id: json['id'] as String,
    name: json['name'] as String,
    programId: json['programId'] as String,
    programName: json['programName'] as String,
    archived: json['archived'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String programId;
  final String programName;

  /// Buổi đã bị gỡ khỏi giáo án; lịch này vẫn tập được (BR-W07).
  final bool archived;
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.date,
    this.startTime,
    required this.status,
    this.note,
    required this.workoutDay,
    this.workoutLogId,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    id: json['id'] as String,
    date: parseIsoDate(json['scheduledDate'] as String),
    startTime: json['startTime'] as String?,
    status: ScheduleStatus.parse(json['status'] as String),
    note: json['note'] as String?,
    workoutDay: ScheduleDayRef.fromJson(
      json['workoutDay'] as Map<String, dynamic>,
    ),
    workoutLogId: json['workoutLogId'] as String?,
  );

  final String id;
  final DateTime date;

  /// "HH:mm" giờ địa phương; null = chưa đặt giờ.
  final String? startTime;
  final ScheduleStatus status;
  final String? note;
  final ScheduleDayRef workoutDay;
  final String? workoutLogId;

  /// Lịch quá ngày mà chưa tập: chỉ hiển thị "Đã qua", server không có trạng thái riêng (docs/16 §1).
  bool isOverdue(DateTime today) =>
      status == ScheduleStatus.scheduled && date.isBefore(today);
}

class ScheduleDetail {
  const ScheduleDetail({required this.item, required this.exercises});

  factory ScheduleDetail.fromJson(Map<String, dynamic> json) => ScheduleDetail(
    item: ScheduleItem.fromJson(json),
    exercises: (json['exercises'] as List)
        .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final ScheduleItem item;

  /// Bài hiện tại của buổi (không phải snapshot; snapshot nằm ở log ngày 8).
  final List<ProgramExercise> exercises;
}

class ScheduleList {
  const ScheduleList({
    required this.from,
    required this.to,
    required this.items,
  });

  factory ScheduleList.fromJson(Map<String, dynamic> json) => ScheduleList(
    from: parseIsoDate(json['from'] as String),
    to: parseIsoDate(json['to'] as String),
    items: (json['items'] as List)
        .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final DateTime from;
  final DateTime to;
  final List<ScheduleItem> items;

  /// Lịch của từng ngày trong [from, to], giữ thứ tự server (ngày, giờ).
  List<ScheduleItem> on(DateTime day) =>
      items.where((s) => s.date == dateOnly(day)).toList();
}
