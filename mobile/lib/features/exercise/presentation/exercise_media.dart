import 'package:flutter/material.dart';

/// Ảnh nhỏ trên thẻ danh sách. URL null/lỗi → icon, không để ô trống hay crash.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.url, this.size = 56});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.fitness_center),
    );
    final src = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
    Widget message(String text) => Container(
      height: _size,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 40),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );

    final src = url;
    if (src == null || src.isEmpty) {
      return message('Bài này chưa có hình minh họa');
    }
    return Column(
      children: [
        Center(
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
            errorBuilder: (context, error, stackTrace) =>
                message('Chưa tải được hình minh họa'),
          ),
        ),
        if (license != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              license!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
