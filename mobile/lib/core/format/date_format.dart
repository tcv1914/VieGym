/// Ngày lịch (không giờ, không múi giờ) như `scheduledDate` của backend. Dùng
/// DateTime UTC lúc 0h chỉ làm "hộp chứa" ngày để cộng trừ không vướng giờ mùa hè.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Hôm nay theo giờ máy. MVP chỉ hỗ trợ Asia/Ho_Chi_Minh (BR-G04).
DateTime today() => dateOnly(DateTime.now());

/// Thứ Hai của tuần chứa [d] (tuần thứ Hai–Chủ nhật, như backend).
DateTime weekStart(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime addDays(DateTime d, int days) =>
    DateTime.utc(d.year, d.month, d.day + days);

String _two(int v) => v.toString().padLeft(2, '0');

/// 2026-11-02
String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// "2026-11-02" → ngày; sai định dạng → FormatException.
DateTime parseIsoDate(String text) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (m == null) throw FormatException('Ngày không hợp lệ', text);
  return DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// 02/11/2026
String viDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// 02/11
String viDayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

String viWeekday(DateTime d) => _weekdays[d.weekday - 1];

/// "18:05"
String hhmm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';
