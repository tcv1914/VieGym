import '../../../core/format/date_format.dart';

/// Một lần cân (docs/05 §4). [logDate] là ngày lịch (UTC 0h, xem `dateOnly`).
class WeightLog {
  const WeightLog({
    required this.id,
    required this.logDate,
    required this.weightKg,
    this.note,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) => WeightLog(
        id: json['id'] as String,
        logDate: parseIsoDate(json['logDate'] as String),
        weightKg: (json['weightKg'] as num).toDouble(),
        note: json['note'] as String?,
      );

  final String id;
  final DateTime logDate;
  final double weightKg;
  final String? note;
}

/// Chênh lệch giữa bản ghi đầu và cuối của danh sách (đã sắp theo ngày). Chỉ so hai mốc có dữ
/// liệu, không nội suy ngày thiếu; null khi chưa đủ hai bản ghi.
class WeightChange {
  const WeightChange(this.first, this.last);

  final WeightLog first;
  final WeightLog last;

  /// Làm tròn 0,1 kg như dữ liệu gốc để tránh 69.8 - 70 = -0.20000000000000284.
  double get deltaKg => ((last.weightKg - first.weightKg) * 10).round() / 10;

  static WeightChange? of(List<WeightLog> logs) =>
      logs.length < 2 ? null : WeightChange(logs.first, logs.last);
}
