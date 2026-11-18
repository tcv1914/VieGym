import 'package:flutter/material.dart';

import 'password_rules.dart';

/// Bảng màu chủ đạo phong cách thể thao – năng động cho cụm màn hình xác thực.
abstract final class AuthGymColors {
  static const heroDark = Color(0xFF092C22);
  static const heroMid = Color(0xFF0F5138);
  static const heroLight = Color(0xFF157347);
  static const accentLime = Color(0xFFA3E635);
  static const vibrantGreen = Color(0xFF16A34A);
}

/// Header gradient đậm chất phòng tập với huy hiệu icon, nhãn năng lượng và tiêu đề lớn.
class AuthGymHeader extends StatelessWidget {
  const AuthGymHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badgeText = 'VIEGYM • FITNESS & NUTRITION',
    this.icon = Icons.fitness_center_rounded,
    this.showBackButton = false,
    this.showFeaturePills = false,
    this.compact = false,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final bool showBackButton;
  final bool showFeaturePills;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthGymColors.heroDark,
            AuthGymColors.heroMid,
            AuthGymColors.heroLight,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Họa tiết vòng tròn ánh sáng tạo chiều sâu năng động
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuthGymColors.accentLime.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -25,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                compact ? 8 : 12,
                24,
                compact ? 22 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBackButton) ...[
                        _HeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AuthGymColors.accentLime.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 15,
                              color: AuthGymColors.accentLime,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: compact ? 48 : 58,
                        height: compact ? 48 : 58,
                        decoration: BoxDecoration(
                          color: AuthGymColors.accentLime.withValues(
                            alpha: 0.18,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AuthGymColors.accentLime.withValues(
                              alpha: 0.5,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: compact ? 26 : 30,
                          color: AuthGymColors.accentLime,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 22 : 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showFeaturePills) ...[
                    const SizedBox(height: 18),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeaturePill(
                          icon: Icons.fitness_center_rounded,
                          label: 'Lịch tập thông minh',
                        ),
                        _FeaturePill(
                          icon: Icons.restaurant_menu_rounded,
                          label: 'Dinh dưỡng Việt',
                        ),
                        _FeaturePill(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI Coach 24/7',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

/// Nút icon trên nền tối của AuthGymHeader (ví dụ nút kiểm tra kết nối).
class AuthHeaderActionButton extends StatelessWidget {
  const AuthHeaderActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AuthGymColors.accentLime),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kiểu ô nhập liệu bo góc, nền sáng, viền nổi bật khi focus.
InputDecoration authInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? helperText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  final borderRadius = BorderRadius.circular(14);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    prefixIcon: Icon(prefixIcon, size: 21),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: borderRadius),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(
        color: AuthGymColors.vibrantGreen,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: scheme.error, width: 2),
    ),
  );
}

/// Nút con mắt bật/tắt hiển thị mật khẩu.
class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({
    super.key,
    required this.obscured,
    required this.onToggle,
  });

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 21,
      ),
      onPressed: onToggle,
    );
  }
}

/// Nút hành động chính cao 52px, chữ đậm, hỗ trợ trạng thái đang gửi.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: buttonKey,
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AuthGymColors.vibrantGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: busy ? 0 : 1.5,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 20),
                ],
              ],
            ),
    );
  }
}

/// Khung thông báo lỗi hoặc thông tin phiên đăng nhập rõ ràng, có biểu tượng.
class AuthNoticeBanner extends StatelessWidget {
  const AuthNoticeBanner({
    super.key,
    required this.message,
    this.isError = true,
    this.textKey,
  });

  final String message;
  final bool isError;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = isError
        ? scheme.errorContainer.withValues(alpha: 0.65)
        : AuthGymColors.vibrantGreen.withValues(alpha: 0.10);
    final borderColor = isError
        ? scheme.error.withValues(alpha: 0.40)
        : AuthGymColors.vibrantGreen.withValues(alpha: 0.35);
    final fgColor = isError ? scheme.onErrorContainer : AuthGymColors.heroMid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 20,
            color: isError ? scheme.error : AuthGymColors.vibrantGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              key: textKey,
              style: TextStyle(
                color: fgColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh mức độ + checklist 3 điều kiện mật khẩu cập nhật trực tiếp khi người dùng gõ.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        final okLen = hasPasswordLength(text);
        final okLetter = hasPasswordLetter(text);
        final okDigit = hasPasswordDigit(text);
        final score = (okLen ? 1 : 0) + (okLetter ? 1 : 0) + (okDigit ? 1 : 0);

        final barColor = switch (score) {
          0 => scheme.outlineVariant,
          1 => Colors.orange,
          2 => Colors.amber.shade700,
          _ => AuthGymColors.vibrantGreen,
        };

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                Row(
                  children: List.generate(3, (index) {
                    final active = index < score && text.isNotEmpty;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: active
                              ? barColor
                              : scheme.outlineVariant.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _RuleChip(label: 'Độ dài 8–72 ký tự', met: okLen),
                  _RuleChip(label: 'Có chữ cái', met: okLetter),
                  _RuleChip(label: 'Có chữ số', met: okDigit),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = met ? AuthGymColors.vibrantGreen : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}
