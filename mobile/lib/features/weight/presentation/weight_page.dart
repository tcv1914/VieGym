import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/number_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/gym_ui.dart';
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

    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'TIẾN ĐỘ CƠ THỂ',
        title: 'Cân nặng',
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('weight-add'),
        heroTag: 'weight-add-fab',
        onPressed: logs.hasValue
            ? () => _openForm(context, ref, logs.value!, range)
            : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Ghi cân nặng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: GymColors.vibrantGreen,
        onRefresh: () => ref.refresh(weightLogsProvider(key).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            SegmentedButton<WeightRange>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: GymColors.vibrantGreen.withValues(
                  alpha: 0.16,
                ),
                selectedForegroundColor: GymColors.heroMid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              segments: [
                for (final r in WeightRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {range},
              onSelectionChanged: (s) =>
                  ref.read(weightRangeProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 14),
            ...logs.when(
              skipLoadingOnRefresh: true,
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                GymCard(
                  child: Column(
                    children: [
                      Text(
                        e.toString(),
                        key: const Key('weight-error'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            ref.invalidate(weightLogsProvider(key)),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ],
              data: (items) => _content(context, ref, items, range),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    List<WeightLog> items,
    WeightRange range,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return [
        GymCard(
          cardKey: const Key('weight-empty'),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: GymColors.bodyBlue.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: GymColors.bodyBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có lần cân nào trong ${range.label.toLowerCase()} qua.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _openForm(context, ref, items, range),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ghi lần cân đầu tiên'),
              ),
            ],
          ),
        ),
      ];
    }

    final change = WeightChange.of(items);
    return [
      GymCard(
        padding: const EdgeInsets.fromLTRB(12, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 10),
              child: GymSectionHeader(
                icon: Icons.show_chart_rounded,
                title: 'Biểu đồ biến thiên',
              ),
            ),
            WeightChart(logs: items, from: range.from, to: today()),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GymColors.vibrantGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: GymColors.vibrantGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      change == null
                          ? 'Cần ít nhất 2 lần cân để so sánh.'
                          : 'Từ ${viDate(change.first.logDate)} đến ${viDate(change.last.logDate)}: '
                                '${_signed(change.deltaKg)} kg',
                      key: const Key('weight-change'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (final log in items.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GymCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: Key('weight-item-${log.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: GymColors.bodyBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.scale_outlined,
                  color: GymColors.bodyBlue,
                  size: 20,
                ),
              ),
              title: Text(
                '${formatViCompact(log.weightKg, maxDecimals: 1)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                [
                  '${viWeekday(log.logDate)}, ${viDate(log.logDate)}',
                  if (log.note != null) log.note!,
                ].join('\n'),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
              ),
              isThreeLine: log.note != null,
              onTap: () => _openForm(context, ref, items, range, existing: log),
              trailing: IconButton(
                key: Key('weight-delete-${log.id}'),
                tooltip: 'Xóa',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () => _delete(context, ref, log),
              ),
            ),
          ),
        ),
    ];
  }

  static String _signed(double kg) {
    final text = formatViCompact(kg.abs(), maxDecimals: 1);
    return kg > 0 ? '+$text' : (kg < 0 ? '-$text' : '0');
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    List<WeightLog> current,
    WeightRange range, {
    WeightLog? existing,
  }) async {
    final saved = await showModalBottomSheet<WeightLog>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          WeightFormSheet(existing: existing, existingLogs: current),
    );
    if (saved == null || !context.mounted) return;
    ref.invalidate(weightLogsProvider);
    ref.invalidate(dashboardProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu cân nặng.')));
    // Chỉ hỏi khi đây là lần cân mới nhất trong khoảng đang xem (khoảng luôn kết thúc hôm nay).
    final isLatest =
        !saved.logDate.isBefore(range.from) &&
        current.every((l) => !l.logDate.isAfter(saved.logDate));
    if (isLatest) await offerProfileUpdate(context, ref, saved);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WeightLog log,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lần cân?'),
        content: Text(
          'Xóa ${formatViCompact(log.weightKg, maxDecimals: 1)} kg ngày ${viDate(log.logDate)}. '
          'Hồ sơ sức khỏe không thay đổi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            key: const Key('weight-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
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
  BuildContext context,
  WidgetRef ref,
  WeightLog saved,
) async {
  HealthProfileData? data;
  try {
    data = await ref.read(healthProfileProvider.future);
  } catch (_) {
    return;
  }
  if (data == null ||
      data.profile.weightKg == saved.weightKg ||
      !context.mounted) {
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
        'Cập nhật thành $kg kg và tính lại mục tiêu dinh dưỡng?',
      ),
      actions: [
        TextButton(
          key: const Key('weight-profile-skip'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          key: const Key('weight-profile-update'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cập nhật'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(healthApiProvider)
        .save(
          HealthProfileInput(
            sex: profile.sex,
            dateOfBirth: profile.dateOfBirth,
            heightCm: profile.heightCm,
            weightKg: saved.weightKg,
            activityLevel: profile.activityLevel,
            goal: profile.goal,
          ),
        );
    ref.invalidate(healthProfileProvider);
    ref.invalidate(dashboardProvider);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật hồ sơ và tính lại mục tiêu.'),
      ),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on NetworkException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
