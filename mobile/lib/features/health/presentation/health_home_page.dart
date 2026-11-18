import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/gym_ui.dart';
import '../../auth/presentation/logout_button.dart';
import '../application/health_profile_controller.dart';
import 'health_profile_form_page.dart';
import 'health_summary_page.dart';

/// Màn chính sau đăng nhập: chưa có hồ sơ → form tạo mới; có → tổng quan.
/// Lỗi mạng không được hiểu là "chưa có hồ sơ".
class HealthHomePage extends ConsumerWidget {
  const HealthHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(healthProfileProvider);
    return profile.when(
      // Đang thử lại sau lỗi thì hiện loading; còn lại giữ màn cũ trong lúc tải lại.
      skipLoadingOnRefresh: !profile.hasError,
      loading: () =>
          const GymScaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => GymScaffold(
        appBar: const GymAppBar(
          eyebrow: 'CHỈ SỐ CƠ THỂ',
          title: 'Hồ sơ sức khỏe',
          actions: [GymGlassAction(child: LogoutButton())],
        ),
        body: GymStateView(
          icon: Icons.error_outline_rounded,
          accent: Theme.of(context).colorScheme.error,
          message: error.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(healthProfileProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        ),
      ),
      data: (data) => data == null
          ? const HealthProfileFormPage()
          : HealthSummaryPage(data: data),
    );
  }
}
