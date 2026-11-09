import '../../../core/format/date_format.dart';
import '../../health/data/health_models.dart';
import '../../nutrition/meal/data/meal_models.dart';
import '../../workout/schedule/data/schedule_models.dart';

double? _numOrNull(Object? v) => v == null ? null : (v as num).toDouble();

Goal? _goal(Object? api) => api == null
    ? null
    : Goal.values.firstWhere(
        (g) => g.api == api,
        orElse: () => throw FormatException('Mục tiêu không hỗ trợ: $api'),
      );

/// GET /dashboard (docs/05 §11, docs/25). Mọi khối luôn có; thiếu dữ liệu → null/0/rỗng.
class Dashboard {
  const Dashboard({
    required this.date,
    required this.timezone,
    required this.health,
    required this.nutrition,
    required this.training,
    required this.generatedAt,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
    date: parseIsoDate(json['date'] as String),
    timezone: json['timezone'] as String,
    health: DashboardHealth.fromJson(json['health'] as Map<String, dynamic>),
    nutrition: DashboardNutrition.fromJson(
      json['nutrition'] as Map<String, dynamic>,
    ),
    training: DashboardTraining.fromJson(
      json['training'] as Map<String, dynamic>,
    ),
    generatedAt: DateTime.parse(json['generatedAt'] as String).toLocal(),
  );

  final DateTime date;
  final String timezone;
  final DashboardHealth health;
  final DashboardNutrition nutrition;
  final DashboardTraining training;
  final DateTime generatedAt;
}

class DashboardHealth {
  const DashboardHealth({
    required this.hasProfile,
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.goal,
  });

  factory DashboardHealth.fromJson(Map<String, dynamic> json) =>
      DashboardHealth(
        hasProfile: json['hasProfile'] as bool,
        weightKg: _numOrNull(json['weightKg']),
        heightCm: _numOrNull(json['heightCm']),
        bmi: _numOrNull(json['bmi']),
        goal: _goal(json['goal']),
      );

  final bool hasProfile;
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final Goal? goal;
}

/// [targets]/[remaining] null khi chưa có mục tiêu; [remaining] âm = vượt.
class DashboardNutrition {
  const DashboardNutrition({
    required this.entryCount,
    required this.totals,
    this.targets,
    this.remaining,
    this.targetsCalculatedAt,
  });

  factory DashboardNutrition.fromJson(Map<String, dynamic> json) =>
      DashboardNutrition(
        entryCount: json['entryCount'] as int,
        totals: Nutrients.fromJson(json['totals'] as Map<String, dynamic>),
        targets: Nutrients.fromJsonOrNull(json['targets']),
        remaining: Nutrients.fromJsonOrNull(json['remaining']),
        targetsCalculatedAt: json['targetsCalculatedAt'] == null
            ? null
            : DateTime.parse(json['targetsCalculatedAt'] as String).toLocal(),
      );

  final int entryCount;
  final Nutrients totals;
  final Nutrients? targets;
  final Nutrients? remaining;
  final DateTime? targetsCalculatedAt;
}

class DashboardSchedule {
  const DashboardSchedule({
    required this.scheduleId,
    required this.date,
    required this.name,
    required this.programName,
    required this.status,
    this.startTime,
    this.workoutLogId,
  });

  factory DashboardSchedule.fromJson(Map<String, dynamic> json) =>
      DashboardSchedule(
        scheduleId: json['scheduleId'] as String,
        date: parseIsoDate(json['scheduledDate'] as String),
        startTime: json['startTime'] as String?,
        name: json['name'] as String,
        programName: json['programName'] as String,
        status: ScheduleStatus.parse(json['status'] as String),
        workoutLogId: json['workoutLogId'] as String?,
      );

  final String scheduleId;
  final DateTime date;

  /// "HH:mm" hoặc null.
  final String? startTime;
  final String name;
  final String programName;
  final ScheduleStatus status;
  final String? workoutLogId;
}

/// [scheduled] = số lịch không hủy trong tuần (mẫu số); [completed] ⊂ scheduled.
class WeekStats {
  const WeekStats({
    required this.from,
    required this.to,
    required this.scheduled,
    required this.completed,
    required this.cancelled,
  });

  factory WeekStats.fromJson(Map<String, dynamic> json) => WeekStats(
    from: parseIsoDate(json['from'] as String),
    to: parseIsoDate(json['to'] as String),
    scheduled: json['scheduled'] as int,
    completed: json['completed'] as int,
    cancelled: json['cancelled'] as int,
  );

  final DateTime from;
  final DateTime to;
  final int scheduled;
  final int completed;
  final int cancelled;

  /// null khi tuần không có lịch (không chia cho 0).
  double? get progress => scheduled == 0 ? null : completed / scheduled;
}

/// [next] theo hôm nay thực (30 ngày tới), không theo ngày đang xem.
class DashboardTraining {
  const DashboardTraining({
    required this.today,
    required this.week,
    this.next,
  });

  factory DashboardTraining.fromJson(Map<String, dynamic> json) =>
      DashboardTraining(
        today: (json['today'] as List)
            .map((e) => DashboardSchedule.fromJson(e as Map<String, dynamic>))
            .toList(),
        week: WeekStats.fromJson(json['week'] as Map<String, dynamic>),
        next: json['next'] == null
            ? null
            : DashboardSchedule.fromJson(json['next'] as Map<String, dynamic>),
      );

  final List<DashboardSchedule> today;
  final WeekStats week;
  final DashboardSchedule? next;
}
