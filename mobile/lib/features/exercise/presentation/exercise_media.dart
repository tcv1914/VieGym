import 'package:flutter/material.dart';

import '../../../core/ui/gym_ui.dart';

/// Ảnh nhỏ trên thẻ danh sách. URL null/lỗi → icon, không để ô trống hay crash.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.url, this.size = 60});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GymColors.vibrantGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.fitness_center_rounded,
        color: GymColors.vibrantGreen,
        size: 26,
      ),
    );
    final src = url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: src == null || src.isEmpty
          ? placeholder
          : Image.network(
              src,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Ảnh 180×180: giải mã nhỏ cho thẻ danh sách.
              cacheWidth: 180,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}

/// GIF/ảnh minh họa ở màn chi tiết, kèm dòng bản quyền bắt buộc của nguồn media.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({super.key, required this.url, this.license});

  final String? url;
  final String? license;

  /// Media gốc 180×180; không phóng to quá cỡ phân phối (NOTICE của nguồn).
  static const _size = 180.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget message(String text) => Container(
      width: double.infinity,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 38,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    final src = url;
    if (src == null || src.isEmpty) {
      return message('Bài này chưa có hình minh họa');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: GymColors.vibrantGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GymColors.vibrantGreen.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                src,
                key: const Key('exercise-media'),
                width: _size,
                height: _size,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox.square(
                        dimension: _size,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  width: _size,
                  child: message('Chưa tải được hình minh họa'),
                ),
              ),
            ),
          ),
          if (license != null) ...[
            const SizedBox(height: 10),
            Text(
              license!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
