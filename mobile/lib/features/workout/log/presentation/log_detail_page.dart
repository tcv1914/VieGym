import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/format/number_format.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../workout_widgets.dart';
import '../application/log_providers.dart';
import '../data/log_models.dart';
import 'log_format.dart';

/// Kết quả đã lưu, đọc từ server. Không có sửa/xóa (MVP chưa hỗ trợ).
class LogDetailPage extends ConsumerWidget {
  const LogDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(logDetailProvider(id));
    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'TỔNG KẾT BUỔI TẬP',
        title: 'Kết quả buổi tập',
      ),
      body: log.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(logDetailProvider(id)),
        ),
        data: (d) => _LogDetailView(log: d),
      ),
    );
  }
}

class _LogDetailView extends StatelessWidget {
  const _LogDetailView({required this.log});

  final LogDetail log;

  @override
  Widget build(BuildContext context) {
    final s = log.summary;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time = timeRangeText(s);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        GymCard(
          padding: const EdgeInsets.all(18),
          borderColor: GymColors.vibrantGreen.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: GymColors.heroGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: GymColors.accentLime,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.workoutName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          s.programName,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${viWeekday(s.workoutDate)}, ${viDate(s.workoutDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (time != null)
                Text(
                  time,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Stat(
                    label: 'Bài',
                    value: '${s.exerciseCount}',
                    color: GymColors.tealAccent,
                  ),
                  _Stat(
                    label: 'Hiệp',
                    value: '${s.setCount}',
                    color: GymColors.bodyBlue,
                  ),
                  _Stat(
                    label: 'Tổng số lần',
                    value: '${s.totalReps}',
                    color: GymColors.vibrantGreen,
                  ),
                  _Stat(
                    label: 'Khối lượng tạ ngoài',
                    value: '${formatVi(s.totalVolumeKg, decimals: 0)} kg',
                    color: GymColors.flameOrange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Khối lượng tạ ngoài = Σ số lần × kg; bài không dùng tạ tính 0 nhưng vẫn được tính số lần.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (log.note != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Ghi chú: ${log.note}'),
                ),
              ],
            ],
          ),
        ),
        for (final e in log.exercises)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GymCard(
              cardKey: Key('log-detail-ex-${e.orderNo}'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.orderNo}. ${e.exerciseName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Table(
                    columnWidths: const {0: FlexColumnWidth(1)},
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: GymColors.vibrantGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        children: [
                          for (final h in ['Hiệp', 'Số lần', 'Tạ (kg)'])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: GymColors.heroMid,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (final set in e.sets)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              child: Text(
                                '${set.setNo}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              child: Text('${set.reps}'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              child: Text(
                                kgText(set.weightKg),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      GymPill(label: '$label: $value', color: color);
}
