import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/exercise_list_controller.dart';
import '../data/exercise_models.dart';
import 'exercise_media.dart';

/// Tải theo ID mỗi lần mở; bài bị ẩn sau khi danh sách đã tải → backend trả 404, hiện thông báo.
class ExerciseDetailPage extends ConsumerWidget {
  const ExerciseDetailPage({super.key, required this.id, required this.title});

  final String id;

  /// Tên từ thẻ danh sách, hiện trên AppBar trong lúc tải.
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(id));
    final filters = ref.watch(exerciseFiltersProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: detail.when(
        skipLoadingOnRefresh: !detail.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(exerciseDetailProvider(id)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (d) => _Content(detail: d, filters: filters),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail, required this.filters});

  final ExerciseDetail detail;
  final ExerciseFilters? filters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = detail.summary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              label: Text(
                filters?.muscleGroupLabel(s.muscleGroup) ?? s.muscleGroup,
              ),
            ),
            Chip(
              label: Text(filters?.equipmentLabel(s.equipment) ?? s.equipment),
            ),
            Chip(
              label: Text(
                filters?.difficultyLabel(s.difficulty) ?? s.difficulty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Ngày 6 chỉ hiển thị ảnh/GIF; VIDEO (chưa có dữ liệu) coi như chưa có media.
        ExerciseMedia(
          url: detail.hasImageMedia ? detail.mediaUrl : null,
          license: detail.hasImageMedia ? detail.mediaLicense : null,
        ),
        const SizedBox(height: 24),
        Text('Các bước thực hiện', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (i, step) in detail.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('${i + 1}', style: theme.textTheme.labelSmall),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step)),
              ],
            ),
          ),
        if (detail.commonMistakes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Lỗi thường gặp', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final mistake in detail.commonMistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(mistake)),
                ],
              ),
            ),
        ],
        if (detail.contentSource != null) ...[
          const Divider(height: 32),
          Text(
            'Nguồn nội dung: ${detail.contentSource}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Hướng dẫn mang tính tham khảo, không thay thế chỉ dẫn của huấn luyện viên.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
