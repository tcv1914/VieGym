import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/number_format.dart';
import '../../../core/ui/gym_ui.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/logout_button.dart';
import '../../weight/presentation/weight_page.dart';
import '../application/health_profile_controller.dart';
import '../data/health_models.dart';
import 'health_profile_form_page.dart';

/// Màn chính sau khi có hồ sơ: chỉ số và mục tiêu do backend tính.
class HealthSummaryPage extends ConsumerWidget {
  const HealthSummaryPage({super.key, required this.data});

  final HealthProfileData data;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthProfileFormPage(initial: data.profile),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu hồ sơ và tính lại mục tiêu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final name = auth is Authenticated ? auth.user.fullName : '';
    final t = data.targets;
    final p = data.profile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'CHỈ SỐ & DINH DƯỠNG',
        title: 'Hồ sơ sức khỏe',
        actions: [GymGlassAction(child: LogoutButton())],
      ),
      body: RefreshIndicator(
        color: GymColors.vibrantGreen,
        onRefresh: () => ref.refresh(healthProfileProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (name.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Xin chào, $name',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GymPill(
                    icon: Icons.flag_rounded,
                    label: p.goal.label,
                    color: GymColors.vibrantGreen,
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            // Thẻ Hero Mục tiêu Calo & Macro mỗi ngày
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: GymColors.heroGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: GymColors.heroDark.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GymColors.accentLime.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: GymColors.accentLime,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Mục tiêu mỗi ngày',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${formatVi(t.targetKcal)} kcal',
                    key: const Key('target-kcal'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (t.kcalFloorApplied)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Mục tiêu đã được nâng lên mức tối thiểu an toàn của ứng dụng.',
                          style: TextStyle(
                            color: GymColors.accentLime,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroTargetBox(
                          label: 'Protein',
                          value: '${formatVi(t.proteinG)} g',
                          accent: const Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroTargetBox(
                          label: 'Carbs',
                          value: '${formatVi(t.carbsG)} g',
                          accent: const Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroTargetBox(
                          label: 'Chất béo',
                          value: '${formatVi(t.fatG)} g',
                          accent: const Color(0xFFFB7185),
                        ),
                      ),
                    ],
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
                    icon: Icons.analytics_outlined,
                    title: 'Chỉ số năng lượng & BMI',
                    accent: GymColors.bodyBlue,
                  ),
                  const SizedBox(height: 12),
                  _MetricTile(
                    icon: Icons.speed_rounded,
                    label: 'BMI',
                    value: formatVi(t.bmi, decimals: 2),
                    accent: GymColors.bodyBlue,
                  ),
                  const Divider(height: 18),
                  _MetricTile(
                    icon: Icons.bedtime_outlined,
                    label: 'BMR (năng lượng nghỉ)',
                    value: '${formatVi(t.bmrKcal)} kcal',
                    accent: GymColors.tealAccent,
                  ),
                  const Divider(height: 18),
                  _MetricTile(
                    icon: Icons.bolt_rounded,
                    label: 'TDEE (tiêu hao mỗi ngày)',
                    value: '${formatVi(t.tdeeKcal)} kcal',
                    accent: GymColors.flameOrange,
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
                    icon: Icons.person_outline_rounded,
                    title: 'Thông tin hồ sơ',
                  ),
                  const SizedBox(height: 12),
                  _Row('Giới tính', p.sex.label),
                  _Row('Tuổi', '${data.age}'),
                  _Row('Chiều cao', '${formatVi(p.heightCm)} cm'),
                  _Row('Cân nặng', '${formatVi(p.weightKg)} kg'),
                  _Row('Vận động', p.activityLevel.label),
                  _Row('Mục tiêu', p.goal.label),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('health-weight'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GymColors.heroMid,
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(
                        color: GymColors.vibrantGreen.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WeightPage(),
                      ),
                    ),
                    icon: const Icon(Icons.monitor_weight_outlined, size: 20),
                    label: const Text('Theo dõi cân nặng'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('health-edit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: GymColors.vibrantGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _edit(context, ref),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    label: const Text('Sửa hồ sơ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Các số trên là ước tính theo công thức Mifflin-St Jeor '
              '(${t.formulaVersion}), không thay thế tư vấn của chuyên gia y tế.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroTargetBox extends StatelessWidget {
  const _MacroTargetBox({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
