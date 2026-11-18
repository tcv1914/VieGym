import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bảng màu thống nhất theo phong cách thể thao – năng động cho toàn bộ ứng dụng VieGym.
abstract final class GymColors {
  static const heroDark = Color(0xFF092C22);
  static const heroMid = Color(0xFF0F5138);
  static const heroLight = Color(0xFF157347);
  static const vibrantGreen = Color(0xFF16A34A);
  static const accentLime = Color(0xFFA3E635);
  static const pageBg = Color(0xFFF3F7F4);

  static const flameOrange = Color(0xFFEA580C);
  static const proteinBlue = Color(0xFF0284C7);
  static const carbsAmber = Color(0xFFD97706);
  static const fatRose = Color(0xFFE11D48);
  static const bodyBlue = Color(0xFF2563EB);
  static const tealAccent = Color(0xFF0D9488);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroDark, heroMid, heroLight],
  );

  static Color difficultyColor(String code) => switch (code) {
    'BEGINNER' => vibrantGreen,
    'INTERMEDIATE' => carbsAmber,
    'ADVANCED' => fatRose,
    _ => tealAccent,
  };
}

/// Khung Scaffold chuẩn nền xám xanh thể thao nhẹ ở chế độ sáng.
class GymScaffold extends StatelessWidget {
  const GymScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : GymColors.pageBg,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// AppBar dải màu xanh phòng tập bo cong đáy, giữ nguyên nút Back chuẩn của Material.
class GymAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GymAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions,
    this.bottom,
    this.bottomRadius = 24,
  });

  final String title;
  final String? eyebrow;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double bottomRadius;

  @override
  Size get preferredSize => Size.fromHeight(
    (eyebrow != null ? 64.0 : kToolbarHeight) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: eyebrow != null ? 64 : kToolbarHeight,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: GymColors.heroGradient),
            ),
            Positioned(
              top: -35,
              right: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GymColors.accentLime.withValues(alpha: 0.10),
                ),
              ),
            ),
          ],
        ),
      ),
      title: eyebrow == null
          ? Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: GymColors.accentLime,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        eyebrow!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
      actions: actions == null
          ? null
          : [
              ...actions!,
              const SizedBox(width: 8),
            ],
      bottom: bottom,
    );
  }
}

/// Khung kính mờ bọc các nút Icon trên GymAppBar.
class GymGlassAction extends StatelessWidget {
  const GymGlassAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white, size: 20),
          child: child,
        ),
      ),
    );
  }
}

/// Thẻ nội dung bo góc 20px, viền mảnh sắc nét.
class GymCard extends StatelessWidget {
  const GymCard({
    super.key,
    this.cardKey,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.color,
  });

  final Key? cardKey;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: cardKey,
      elevation: 0,
      margin: margin,
      color: color ?? scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Tiêu đề mục có ô icon màu nổi bật bên trái.
class GymSectionHeader extends StatelessWidget {
  const GymSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.accent = GymColors.vibrantGreen,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Nhãn pill màu cho nhóm cơ, độ khó, trạng thái...
class GymPill extends StatelessWidget {
  const GymPill({
    super.key,
    required this.label,
    this.color = GymColors.vibrantGreen,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13.5, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung thông báo trạng thái trống hoặc lỗi có icon vòng tròn và nút hành động.
class GymStateView extends StatelessWidget {
  const GymStateView({
    super.key,
    required this.icon,
    required this.message,
    this.accent = GymColors.vibrantGreen,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Kiểu InputDecoration bo góc 14px đồng bộ trên toàn bộ form và bottom sheet.
InputDecoration gymInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  String? suffixText,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(14);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    suffixText: suffixText,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: radius),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: GymColors.vibrantGreen, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error, width: 2),
    ),
  );
}
