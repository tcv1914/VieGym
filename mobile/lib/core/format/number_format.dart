/// Hiển thị số theo vi-VN (BR-G06): dấu chấm nhóm nghìn, dấu phẩy thập phân. 2791.6 → "2.791,6".
String formatVi(double value, {int decimals = 1}) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  final sign = value < 0 && double.parse(fixed) != 0 ? '-' : '';
  return parts.length > 1 ? '$sign$grouped,${parts[1]}' : '$sign$grouped';
}

/// Nhận "170", "170.5" hoặc "170,5"; tối đa [maxDecimals] chữ số lẻ. Sai định dạng → null.
double? parseViDecimal(String text, {int maxDecimals = 1}) {
  final normalized = text.trim().replaceAll(',', '.');
  final pattern = RegExp('^\\d{1,3}(\\.\\d{1,$maxDecimals})?\$');
  if (!pattern.hasMatch(normalized)) return null;
  return double.tryParse(normalized);
}
