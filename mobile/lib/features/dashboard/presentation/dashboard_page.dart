import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/home_tab.dart';
import '../../../core/format/date_format.dart';
import '../../../core/format/number_format.dart';
import '../../ai/presentation/conversation_list_page.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../auth/presentation/logout_button.dart';
import '../../nutrition/food/presentation/food_widgets.dart';
import '../../nutrition/meal/application/meal_plan_controller.dart';
import '../../workout/log/presentation/log_detail_page.dart';
import '../../workout/schedule/data/schedule_models.dart';
import '../../workout/schedule/presentation/schedule_detail_page.dart';
import '../../workout/schedule/presentation/schedule_form_page.dart';
import '../../workout/workout_widgets.dart';
import '../application/dashboard_providers.dart';
import '../data/dashboard_models.dart';

/// Ngày xa nhất cho phép xem: đủ để xem lịch đã lên trước.
const _maxDaysAhead = 365;

/// "645 kcal" — dashboard hiện kcal số nguyên (docs/04 §3.6).
String _kcal(double v) => '${formatVi(v, decimals: 0)} kcal';

/// Tab "Tổng quan" (UC09): dinh dưỡng, lịch tập, tiến độ tuần, cơ thể của ngày đang chọn.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    if (auth is! Authenticated) return const SizedBox.shrink();
    final date = ref.watch(dashboardDateProvider);
    final key = (userId: auth.user.id, date: date);
    final async = ref.watch(dashboardProvider(key));
    final data = async.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Future<void> refresh() async {
      ref.invalidate(dashboardProvider(key));
      try {
        await ref.read(dashboardProvider(key).future);
      } catch (_) {
        // Lỗi đã hiện trên màn (banner dữ liệu cũ hoặc nút thử lại).
      }
    }

    Widget body;
    if (data == null) {
      body = async.hasError
          ? ErrorRetry(error: async.error!, onRetry: refresh)
          : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: refresh,
        color: AuthGymColors.vibrantGreen,
        child: ListView(
          key: const Key('dashboard-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (async.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ),
            if (async.hasError) ...[
              _StaleBanner(data: data, onRetry: refresh),
              const SizedBox(height: 14),
            ],
            _NutritionCard(data: data),
            const SizedBox(height: 14),
            _TrainingCard(data: data),
            const SizedBox(height: 14),
            _BodyCard(health: data.health),
            const SizedBox(height: 14),
            const _AiCard(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF3F7F4),
      body: Column(
        children: [
          _DashboardHeroHeader(fullName: auth.user.fullName, date: date),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Header thể thao xanh đậm kết hợp lời chào, nút AI Coach, đăng xuất và thanh chọn ngày.
class _DashboardHeroHeader extends StatelessWidget {
  const _DashboardHeroHeader({required this.fullName, required this.date});

  final String fullName;
  final DateTime date;

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'V';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.last.characters.first.toUpperCase();
  }

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
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -24,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuthGymColors.accentLime.withValues(alpha: 0.10),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 14, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AuthGymColors.accentLime.withValues(
                            alpha: 0.20,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AuthGymColors.accentLime.withValues(
                              alpha: 0.65,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _initial(fullName),
                          style: const TextStyle(
                            color: AuthGymColors.accentLime,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: AuthGymColors.accentLime,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'VIEGYM DASHBOARD',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Xin chào, $fullName',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          key: const Key('dashboard-ai'),
                          tooltip: 'AI Coach',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openAi(context),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AuthGymColors.accentLime,
                            size: 21,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: const IconTheme(
                          data: IconThemeData(color: Colors.white, size: 20),
                          child: LogoutButton(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DateBar(date: date),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tải lại lỗi nhưng còn số cũ: vẫn hiện, ghi rõ thời điểm.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.data, required this.onRetry});

  final Dashboard data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = data.generatedAt;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('dashboard-stale'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không tải được dữ liệu mới',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
                Text(
                  'Đang hiện số liệu lúc ${hhmm(t.hour, t.minute)} ${viDayMonth(t)}.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onErrorContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardDateProvider.notifier);
    final now = today();
    final first = firstPlanDate;
    final last = addDays(now, _maxDaysAhead);
    final label = date == now
        ? 'Hôm nay, ${viDate(date)}'
        : '${viWeekday(date)}, ${viDate(date)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('dashboard-prev-day'),
            tooltip: 'Ngày trước',
            visualDensity: VisualDensity.compact,
            onPressed: date.isAfter(first)
                ? () => notifier.set(addDays(date, -1))
                : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: date.isAfter(first)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('dashboard-pick-date'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date.isAfter(last) ? last : date,
                  firstDate: first,
                  lastDate: last,
                  helpText: 'Chọn ngày',
                );
                if (picked != null) notifier.set(picked);
              },
              icon: const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AuthGymColors.accentLime,
              ),
              label: Text(
                label,
                key: const Key('dashboard-date'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('dashboard-next-day'),
            tooltip: 'Ngày sau',
            visualDensity: VisualDensity.compact,
            onPressed: date.isBefore(last)
                ? () => notifier.set(addDays(date, 1))
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: date.isBefore(last)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
          if (date != now)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                key: const Key('dashboard-today'),
                style: TextButton.styleFrom(
                  backgroundColor: AuthGymColors.accentLime,
                  foregroundColor: AuthGymColors.heroDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => notifier.set(now),
                child: const Text('Hôm nay'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
    this.cardKey,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;
  final Key? cardKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: cardKey,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Chuyển sang tab Thực đơn ở đúng ngày đang xem.
void _openMealPlan(WidgetRef ref, DateTime date) {
  ref.read(homeTabProvider.notifier).select(HomeTab.mealPlan);
  // Đợi tab dựng xong (lần mở đầu tiên) rồi mới đổi ngày.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => ref.read(mealPlanProvider.notifier).setDate(date),
  );
}

class _NutritionCard extends ConsumerWidget {
  const _NutritionCard({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = data.nutrition;
    final t = n.totals;
    final target = n.targets;
    final remaining = n.remaining;
    final isToday = data.date == today();
    final isOver = remaining != null && remaining.kcal < 0;
    final accent = isOver ? scheme.error : const Color(0xFFEA580C);

    return _SectionCard(
      cardKey: const Key('dashboard-nutrition'),
      title: isToday ? 'Dinh dưỡng hôm nay' : 'Dinh dưỡng ${viDate(data.date)}',
      icon: Icons.local_fire_department_rounded,
      accentColor: const Color(0xFFEA580C),
      onTap: () => _openMealPlan(ref, data.date),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      target == null
                          ? _kcal(t.kcal)
                          : '${formatVi(t.kcal, decimals: 0)} / ${_kcal(target.kcal)}',
                      key: const Key('dashboard-kcal'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (target != null && remaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOver
                            ? scheme.error.withValues(alpha: 0.14)
                            : AuthGymColors.vibrantGreen.withValues(
                                alpha: 0.14,
                              ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOver
                            ? 'Vượt ${_kcal(-remaining.kcal)}'
                            : 'Còn lại ${_kcal(remaining.kcal)}',
                        key: const Key('dashboard-remaining'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isOver
                              ? scheme.error
                              : AuthGymColors.heroMid,
                        ),
                      ),
                    ),
                ],
              ),
              if (target != null && remaining != null) ...[
                const SizedBox(height: 10),
                // Thanh chỉ dài tối đa 100%; số vượt vẫn hiện đúng ở nhãn trên.
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: target.kcal <= 0
                        ? null
                        : (t.kcal / target.kcal).clamp(0, 1).toDouble(),
                    backgroundColor: scheme.outlineVariant.withValues(
                      alpha: 0.45,
                    ),
                    color: isOver ? scheme.error : AuthGymColors.vibrantGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MacroRow(
          label: 'Đạm',
          eaten: t.protein,
          target: target?.protein,
          color: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 10),
        _MacroRow(
          label: 'Bột đường',
          eaten: t.carbs,
          target: target?.carbs,
          color: const Color(0xFFD97706),
        ),
        const SizedBox(height: 10),
        _MacroRow(
          label: 'Béo',
          eaten: t.fat,
          target: target?.fat,
          color: const Color(0xFFE11D48),
        ),
        const SizedBox(height: 12),
        if (n.entryCount == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Chưa ghi nhận bữa ăn nào trong ngày này.',
              key: const Key('dashboard-no-meal'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        if (target == null)
          Text(
            'Chưa có mục tiêu để so sánh. Hãy hoàn thiện hồ sơ sức khỏe.',
            key: const Key('dashboard-no-target'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Text(
            'So với mục tiêu hiện tại'
            '${n.targetsCalculatedAt == null ? '' : ' (tính ngày ${viDate(n.targetsCalculatedAt!)})'}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          key: const Key('dashboard-add-meal'),
          onPressed: () => _openMealPlan(ref, data.date),
          style: FilledButton.styleFrom(
            backgroundColor: AuthGymColors.vibrantGreen.withValues(alpha: 0.14),
            foregroundColor: AuthGymColors.heroMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Thêm món'),
        ),
      ],
    );
  }
}

/// Dòng chất đa lượng kèm thanh tỉ lệ riêng (dùng FractionallySizedBox thay vì LinearProgressIndicator).
class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.eaten,
    required this.target,
    required this.color,
  });

  final String label;
  final double eaten;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (target != null && target! > 0)
        ? (eaten / target!).clamp(0.0, 1.0)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            Text(
              target == null
                  ? gramText(eaten)
                  : '${formatVi(eaten)} / ${formatVi(target!)} g',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        if (ratio != null) ...[
          const SizedBox(height: 5),
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _scheduleSubtitle(DashboardSchedule s, {bool withDate = false}) {
  final parts = [
    if (withDate) '${viWeekday(s.date)} ${viDayMonth(s.date)}',
    ?s.startTime,
    s.programName,
  ];
  return parts.join(' · ');
}

class _TrainingCard extends ConsumerWidget {
  const _TrainingCard({required this.data});

  final Dashboard data;

  Future<void> _push(BuildContext context, WidgetRef ref, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    ref.invalidate(dashboardProvider);
  }

  void _open(BuildContext context, WidgetRef ref, DashboardSchedule s) {
    final logId = s.workoutLogId;
    _push(
      context,
      ref,
      s.status == ScheduleStatus.completed && logId != null
          ? LogDetailPage(id: logId)
          : ScheduleDetailPage(id: s.scheduleId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final training = data.training;
    final week = training.week;
    final progress = week.progress;
    final isToday = data.date == today();
    final next = training.next;

    return _SectionCard(
      cardKey: const Key('dashboard-training'),
      title: isToday ? 'Lịch tập hôm nay' : 'Lịch tập ${viDate(data.date)}',
      icon: Icons.fitness_center_rounded,
      accentColor: AuthGymColors.vibrantGreen,
      children: [
        if (training.today.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isToday
                        ? 'Hôm nay không có lịch.'
                        : 'Ngày này không có lịch.',
                    key: const Key('dashboard-no-schedule'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('dashboard-add-schedule'),
                  onPressed: () => _push(
                    context,
                    ref,
                    ScheduleFormPage(
                      initialDate: data.date.isBefore(today())
                          ? today()
                          : data.date,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AuthGymColors.vibrantGreen.withValues(
                      alpha: 0.14,
                    ),
                    foregroundColor: AuthGymColors.heroMid,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Lên lịch'),
                ),
              ],
            ),
          ),
        ],
        for (final s in training.today)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              key: Key('dashboard-schedule-${s.scheduleId}'),
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _open(context, ref, s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: s.status == ScheduleStatus.completed
                          ? AuthGymColors.vibrantGreen.withValues(alpha: 0.35)
                          : scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: s.status == ScheduleStatus.cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _scheduleSubtitle(s),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusAction(context, ref, s),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AuthGymColors.vibrantGreen.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 18,
                    color: AuthGymColors.vibrantGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      progress == null
                          ? 'Tuần ${viDayMonth(week.from)}–${viDayMonth(week.to)}: chưa có lịch'
                          : 'Tuần ${viDayMonth(week.from)}–${viDayMonth(week.to)}: '
                                '${week.completed}/${week.scheduled} buổi hoàn thành',
                      key: const Key('dashboard-week'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: scheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                    color: AuthGymColors.vibrantGreen,
                  ),
                ),
              ],
              if (week.cancelled > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${week.cancelled} buổi đã hủy, không tính vào tiến độ.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (next == null)
          Text(
            'Không có buổi nào sắp tới trong 30 ngày.',
            key: const Key('dashboard-no-next'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Material(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              key: const Key('dashboard-next'),
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              leading: const Icon(
                Icons.upcoming_outlined,
                color: AuthGymColors.vibrantGreen,
              ),
              title: Text(
                'Buổi tiếp theo: ${next.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_scheduleSubtitle(next, withDate: true)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              onTap: () => _open(context, ref, next),
            ),
          ),
      ],
    );
  }

  Widget _statusAction(
    BuildContext context,
    WidgetRef ref,
    DashboardSchedule s,
  ) => switch (s.status) {
    ScheduleStatus.completed => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AuthGymColors.vibrantGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AuthGymColors.vibrantGreen,
          ),
          SizedBox(width: 4),
          Text(
            'Đã xong',
            style: TextStyle(
              color: AuthGymColors.heroMid,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
    ScheduleStatus.cancelled => Text(
      'Đã hủy',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12.5,
      ),
    ),
    ScheduleStatus.scheduled =>
      s.date.isAfter(today())
          ? Text(
              'Chưa tới ngày',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            )
          : FilledButton(
              onPressed: () => _open(context, ref, s),
              style: FilledButton.styleFrom(
                backgroundColor: AuthGymColors.vibrantGreen,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('Bắt đầu'),
            ),
  };
}

class _BodyCard extends ConsumerWidget {
  const _BodyCard({required this.health});

  final DashboardHealth health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    void openHealth() =>
        ref.read(homeTabProvider.notifier).select(HomeTab.health);

    if (!health.hasProfile) {
      return _SectionCard(
        cardKey: const Key('dashboard-body'),
        title: 'Cơ thể',
        icon: Icons.monitor_heart_rounded,
        accentColor: const Color(0xFF2563EB),
        children: [
          Text(
            'Chưa có hồ sơ sức khỏe.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            key: const Key('dashboard-complete-profile'),
            onPressed: openHealth,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFF1D4ED8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Hoàn thiện hồ sơ'),
          ),
        ],
      );
    }

    final weight = health.weightKg;
    final bmi = health.bmi;
    return _SectionCard(
      cardKey: const Key('dashboard-body'),
      title: 'Cơ thể',
      icon: Icons.monitor_heart_rounded,
      accentColor: const Color(0xFF2563EB),
      onTap: openHealth,
      children: [
        if (weight != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.scale_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cân nặng ${formatViCompact(weight, maxDecimals: 1)} kg (theo hồ sơ)',
                    key: const Key('dashboard-weight'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (health.latestWeightKg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lần cân gần nhất ${formatViCompact(health.latestWeightKg!, maxDecimals: 1)} kg '
                    '(${viDate(health.latestWeightDate!)})',
                    key: const Key('dashboard-latest-weight'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if (bmi != null) 'BMI ${formatVi(bmi, decimals: 2)}',
                    if (health.goal != null) 'Mục tiêu: ${health.goal!.label}',
                  ].join(' · '),
                  key: const Key('dashboard-bmi'),
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
    );
  }
}

void _openAi(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const ConversationListPage()));

/// Lối vào AI Coach (ngày 12): chỉ mở màn chat, không hiển thị gợi ý tự sinh trên Tổng quan.
class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('dashboard-ai-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthGymColors.heroDark, AuthGymColors.heroMid],
          ),
        ),
        child: InkWell(
          onTap: () => _openAi(context),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AuthGymColors.accentLime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AuthGymColors.accentLime.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AuthGymColors.accentLime,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Coach',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hỏi về bữa ăn, lịch tập dựa trên dữ liệu bạn đã ghi.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AuthGymColors.accentLime,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AuthGymColors.heroDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
