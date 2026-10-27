import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(actions: const [LogoutButton()]),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(healthProfileProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) => data == null
          ? const HealthProfileFormPage()
          : HealthSummaryPage(data: data),
    );
  }
}
