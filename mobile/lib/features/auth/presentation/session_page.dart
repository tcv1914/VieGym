import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// Màn tạm sau đăng nhập: hiển thị /users/me để kiểm tra phiên. Dashboard làm ở ngày sau.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key});

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Phiên đăng nhập')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: me.when(
            skipLoadingOnRefresh: false,
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                Text(error.toString(), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(meProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
            data: (user) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.verified_user, color: Colors.green, size: 64),
                const SizedBox(height: 8),
                Text('Xin chào, ${user.fullName}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ListTile(title: const Text('Email'), subtitle: Text(user.email)),
                ListTile(title: const Text('Vai trò'), subtitle: Text(user.role)),
                ListTile(
                  title: const Text('Hồ sơ sức khỏe'),
                  subtitle: Text(user.hasHealthProfile ? 'Đã có' : 'Chưa có'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(meProvider),
                  child: const Text('Tải lại từ máy chủ'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _loggingOut ? null : _logout,
                  child: _loggingOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
