import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/gym_ui.dart';
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
    return GymScaffold(
      appBar: GymAppBar(eyebrow: 'CHI TIẾT ĐỘNG TÁC', title: title),
      body: detail.when(
        skipLoadingOnRefresh: !detail.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => GymStateView(
          icon: Icons.error_outline_rounded,
          accent: Theme.of(context).colorScheme.error,
          message: error.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(exerciseDetailProvider(id)),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
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
    final scheme = theme.colorScheme;
    final s = detail.summary;
    final diffColor = GymColors.difficultyColor(s.difficulty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        GymCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GymPill(
                    icon: Icons.accessibility_new_rounded,
                    label:
                        filters?.muscleGroupLabel(s.muscleGroup) ??
                        s.muscleGroup,
                    color: GymColors.tealAccent,
                  ),
                  GymPill(
                    icon: Icons.fitness_center_rounded,
                    label: filters?.equipmentLabel(s.equipment) ?? s.equipment,
                    color: GymColors.bodyBlue,
                  ),
                  GymPill(
                    icon: Icons.speed_rounded,
                    label:
                        filters?.difficultyLabel(s.difficulty) ?? s.difficulty,
                    color: diffColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Ngày 6 chỉ hiển thị ảnh/GIF; VIDEO (chưa có dữ liệu) coi như chưa có media.
              ExerciseMedia(
                url: detail.hasImageMedia ? detail.mediaUrl : null,
                license: detail.hasImageMedia ? detail.mediaLicense : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GymCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GymSectionHeader(
                icon: Icons.format_list_numbered_rounded,
                title: 'Các bước thực hiện',
              ),
              const SizedBox(height: 14),
              for (final (i, step) in detail.steps.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == detail.steps.length - 1 ? 0 : 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GymColors.vibrantGreen.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: GymColors.heroMid,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            step,
                            style: const TextStyle(fontSize: 14.5, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (detail.commonMistakes.isNotEmpty) ...[
          const SizedBox(height: 14),
          GymCard(
            padding: const EdgeInsets.all(18),
            borderColor: scheme.error.withValues(alpha: 0.28),
            color: scheme.errorContainer.withValues(alpha: 0.22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GymSectionHeader(
                  icon: Icons.warning_amber_rounded,
                  title: 'Lỗi thường gặp',
                  accent: scheme.error,
                ),
                const SizedBox(height: 12),
                for (final (i, mistake) in detail.commonMistakes.indexed)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == detail.commonMistakes.length - 1 ? 0 : 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mistake,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.contentSource != null) ...[
                Text(
                  'Nguồn nội dung: ${detail.contentSource}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                'Hướng dẫn mang tính tham khảo, không thay thế chỉ dẫn của huấn luyện viên.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
