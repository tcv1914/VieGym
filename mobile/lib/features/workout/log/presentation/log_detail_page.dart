import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/format/number_format.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả buổi tập')),
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
    final time = timeRangeText(s);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(s.workoutName, style: theme.textTheme.titleLarge),
        Text(s.programName),
        const SizedBox(height: 4),
        Text('${viWeekday(s.workoutDate)}, ${viDate(s.workoutDate)}'),
        if (time != null) Text(time),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat(label: 'Bài', value: '${s.exerciseCount}'),
            _Stat(label: 'Hiệp', value: '${s.setCount}'),
            _Stat(label: 'Tổng số lần', value: '${s.totalReps}'),
            _Stat(
              label: 'Khối lượng tạ ngoài',
              value: '${formatVi(s.totalVolumeKg, decimals: 0)} kg',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Khối lượng tạ ngoài = Σ số lần × kg; bài không dùng tạ tính 0 nhưng vẫn được tính số lần.',
          style: theme.textTheme.bodySmall,
        ),
        if (log.note != null) ...[
          const SizedBox(height: 8),
          Text('Ghi chú: ${log.note}'),
        ],
        for (final e in log.exercises)
          Card(
            key: Key('log-detail-ex-${e.orderNo}'),
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.orderNo}. ${e.exerciseName}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Table(
                    columnWidths: const {0: FlexColumnWidth(1)},
                    children: [
                      TableRow(
                        children: [
                          for (final h in ['Hiệp', 'Số lần', 'Tạ (kg)'])
                            Text(h, style: theme.textTheme.labelMedium),
                        ],
                      ),
                      for (final set in e.sets)
                        TableRow(
                          children: [
                            Text('${set.setNo}'),
                            Text('${set.reps}'),
                            Text(kgText(set.weightKg)),
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
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text('$label: $value'), visualDensity: VisualDensity.compact);
}
