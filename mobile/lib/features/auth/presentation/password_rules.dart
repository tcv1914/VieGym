final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\p{Nd}', unicode: true);

bool hasPasswordLength(String v) => v.length >= 8 && v.length <= 72;
bool hasPasswordLetter(String v) => _letter.hasMatch(v);
bool hasPasswordDigit(String v) => _digit.hasMatch(v);

/// BR-A02 phía app (đăng ký, đặt lại mật khẩu). Chỉ để báo sớm; backend vẫn kiểm đầy đủ,
/// kể cả giới hạn 72 byte UTF-8.
String? passwordRuleError(String? v) {
  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
  if (!hasPasswordLength(v)) return 'Mật khẩu từ 8 đến 72 ký tự';
  if (!hasPasswordLetter(v) || !hasPasswordDigit(v)) {
    return 'Mật khẩu cần ít nhất một chữ cái và một chữ số';
  }
  return null;
}
