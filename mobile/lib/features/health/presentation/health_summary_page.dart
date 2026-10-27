import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/number_format.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/logout_button.dart';
import '../application/health_profile_controller.dart';
import '../data/health_models.dart';
import 'health_profile_form_page.dart';

/// Màn chính tạm sau khi có hồ sơ: chỉ số và mục tiêu do backend tính. Dashboard ở ngày 11.
class HealthSummaryPage extends ConsumerWidget {
  const HealthSummaryPage({super.key, required this.data});

  final HealthProfileData data;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => HealthProfileFormPage(initial: data.profile),
    ));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ sức khỏe'),
        actions: const [LogoutButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(healthProfileProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Xin chào, $name', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mục tiêu mỗi ngày', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${formatVi(t.targetKcal)} kcal',
                        key: const Key('target-kcal'),
                        style: theme.textTheme.headlineMedium),
                    if (t.kcalFloorApplied)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Mục tiêu đã được nâng lên mức tối thiểu an toàn của ứng dụng.',
                          style: TextStyle(color: theme.colorScheme.tertiary),
                        ),
                      ),
                    const Divider(height: 24),
                    _Row('Protein', '${formatVi(t.proteinG)} g'),
                    _Row('Carbs', '${formatVi(t.carbsG)} g'),
                    _Row('Chất béo', '${formatVi(t.fatG)} g'),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chỉ số', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _Row('BMI', formatVi(t.bmi, decimals: 2)),
                    _Row('BMR (năng lượng nghỉ)', '${formatVi(t.bmrKcal)} kcal'),
                    _Row('TDEE (tiêu hao mỗi ngày)', '${formatVi(t.tdeeKcal)} kcal'),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hồ sơ', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _Row('Giới tính', p.sex.label),
                    _Row('Tuổi', '${data.age}'),
                    _Row('Chiều cao', '${formatVi(p.heightCm)} cm'),
                    _Row('Cân nặng', '${formatVi(p.weightKg)} kg'),
                    _Row('Vận động', p.activityLevel.label),
                    _Row('Mục tiêu', p.goal.label),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const Key('health-edit'),
              onPressed: () => _edit(context, ref),
              child: const Text('Sửa hồ sơ'),
            ),
            const SizedBox(height: 12),
            Text(
              'Các số trên là ước tính theo công thức Mifflin-St Jeor '
              '(${t.formulaVersion}), không thay thế tư vấn của chuyên gia y tế.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
