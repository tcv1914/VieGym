import '../../../../core/format/date_format.dart';
import '../../../../core/format/number_format.dart';
import '../data/log_models.dart';

/// 20 → "20", 22.5 → "22,5", 12.25 → "12,25".
String kgText(double kg) {
  if (kg == kg.roundToDouble()) return formatVi(kg, decimals: 0);
  final two = formatVi(kg, decimals: 2);
  return two.endsWith('0') ? two.substring(0, two.length - 1) : two;
}

/// "2 bài · 4 hiệp · 40 lần"
String totalsText(LogSummary s) =>
    '${s.exerciseCount} bài · ${s.setCount} hiệp · ${s.totalReps} lần';

/// "18:00–18:45 (45 phút)" hoặc null nếu không có giờ.
String? timeRangeText(LogSummary s) {
  final start = s.startedAt;
  if (start == null) return null;
  final startText = hhmm(start.hour, start.minute);
  final end = s.endedAt;
  if (end == null) return 'Bắt đầu $startText';
  return '$startText–${hhmm(end.hour, end.minute)} (${s.durationMinutes} phút)';
}
