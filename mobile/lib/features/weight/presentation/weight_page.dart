import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/number_format.dart';
import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../health/application/health_profile_controller.dart';
import '../../health/data/health_api.dart';
import '../../health/data/health_models.dart';
import '../application/weight_providers.dart';
import '../data/weight_api.dart';
import '../data/weight_models.dart';
import 'weight_chart.dart';
import 'weight_form_sheet.dart';

/// UC08: lịch sử cân nặng + biểu đồ. Ghi cân nặng không tự đổi hồ sơ (BR-H02); sau khi ghi bản
/// mới nhất, app hỏi user có muốn cập nhật hồ sơ không.
class WeightPage extends ConsumerWidget {
  const WeightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    if (auth is! Authenticated) return const SizedBox.shrink();
    final range = ref.watch(weightRangeProvider);
    final key = (userId: auth.user.id, range: range);
    final logs = ref.watch(weightLogsProvider(key));

    return Scaffold(
      appBar: AppBar(title: const Text('Cân nặng')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('weight-add'),
        onPressed: logs.hasValue
            ? () => _openForm(context, ref, logs.value!, range)
            : null,
        icon: const Icon(Icons.add),
        label: const Text('Ghi cân nặng'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(weightLogsProvider(key).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SegmentedButton<WeightRange>(
              segments: [
                for (final r in WeightRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {range},
              onSelectionChanged: (s) =>
                  ref.read(weightRangeProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 12),
            ...logs.when(
              skipLoadingOnRefresh: true,
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                Text(e.toString(), key: const Key('weight-error')),
                TextButton(
                  onPressed: () => ref.invalidate(weightLogsProvider(key)),
                  child: const Text('Thử lại'),
                ),
              ],
              data: (items) => _content(context, ref, items, range),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref,
      List<WeightLog> items, WeightRange range) {
    if (items.isEmpty) {
      return [
        Card(
          key: const Key('weight-empty'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Chưa có lần cân nào trong ${range.label.toLowerCase()} qua.'),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => _openForm(context, ref, items, range),
                  child: const Text('Ghi lần cân đầu tiên'),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final change = WeightChange.of(items);
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: WeightChart(logs: items, from: range.from, to: today()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          change == null
              ? 'Cần ít nhất 2 lần cân để so sánh.'
              : 'Từ ${viDate(change.first.logDate)} đến ${viDate(change.last.logDate)}: '
                  '${_signed(change.deltaKg)} kg',
          key: const Key('weight-change'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final log in items.reversed)
        Card(
          child: ListTile(
            key: Key('weight-item-${log.id}'),
            title: Text('${formatViCompact(log.weightKg, maxDecimals: 1)} kg'),
            subtitle: Text([
              '${viWeekday(log.logDate)}, ${viDate(log.logDate)}',
              if (log.note != null) log.note!,
            ].join('\n')),
            isThreeLine: log.note != null,
            onTap: () =>
                _openForm(context, ref, items, range, existing: log),
            trailing: IconButton(
              key: Key('weight-delete-${log.id}'),
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, log),
            ),
          ),
        ),
    ];
  }

  static String _signed(double kg) {
    final text = formatViCompact(kg.abs(), maxDecimals: 1);
    return kg > 0 ? '+$text' : (kg < 0 ? '-$text' : '0');
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      List<WeightLog> current, WeightRange range,
      {WeightLog? existing}) async {
    final saved = await showModalBottomSheet<WeightLog>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WeightFormSheet(existing: existing, existingLogs: current),
    );
    if (saved == null || !context.mounted) return;
    ref.invalidate(weightLogsProvider);
    ref.invalidate(dashboardProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cân nặng.')),
    );
    // Chỉ hỏi khi đây là lần cân mới nhất trong khoảng đang xem (khoảng luôn kết thúc hôm nay).
    final isLatest = !saved.logDate.isBefore(range.from) &&
        current.every((l) => !l.logDate.isAfter(saved.logDate));
    if (isLatest) await offerProfileUpdate(context, ref, saved);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WeightLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lần cân?'),
        content: Text(
            'Xóa ${formatViCompact(log.weightKg, maxDecimals: 1)} kg ngày ${viDate(log.logDate)}. '
            'Hồ sơ sức khỏe không thay đổi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              key: const Key('weight-delete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(weightApiProvider).delete(log.id);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa lần cân.')));
    } on ApiException catch (e) {
      // 404: đã bị xóa ở nơi khác; tải lại là đủ.
      if (e.statusCode != 404) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on NetworkException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    ref.invalidate(weightLogsProvider);
    ref.invalidate(dashboardProvider);
  }
}

/// BR-H02: hỏi trước khi đổi cân nặng hồ sơ; chỉ khi user đồng ý mới gọi PUT /health-profile/me
/// (backend tính lại mục tiêu). Không có hồ sơ hoặc cân nặng đã khớp thì không hỏi.
Future<void> offerProfileUpdate(
    BuildContext context, WidgetRef ref, WeightLog saved) async {
  HealthProfileData? data;
  try {
    data = await ref.read(healthProfileProvider.future);
  } catch (_) {
    return;
  }
  if (data == null || data.profile.weightKg == saved.weightKg || !context.mounted) {
    return;
  }
  final profile = data.profile;
  final kg = formatViCompact(saved.weightKg, maxDecimals: 1);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cập nhật hồ sơ?'),
      content: Text(
          'Cân nặng trong hồ sơ là ${formatViCompact(profile.weightKg, maxDecimals: 1)} kg. '
          'Cập nhật thành $kg kg và tính lại mục tiêu dinh dưỡng?'),
      actions: [
        TextButton(
            key: const Key('weight-profile-skip'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau')),
        FilledButton(
            key: const Key('weight-profile-update'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cập nhật')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(healthApiProvider).save(HealthProfileInput(
          sex: profile.sex,
          dateOfBirth: profile.dateOfBirth,
          heightCm: profile.heightCm,
          weightKg: saved.weightKg,
          activityLevel: profile.activityLevel,
          goal: profile.goal,
        ));
    ref.invalidate(healthProfileProvider);
    ref.invalidate(dashboardProvider);
    messenger.showSnackBar(
        const SnackBar(content: Text('Đã cập nhật hồ sơ và tính lại mục tiêu.')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on NetworkException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
