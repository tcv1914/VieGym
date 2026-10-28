import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import 'home_shell.dart';

class VieGymApp extends StatelessWidget {
  const VieGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VieGym',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const AuthGate(),
    );
  }
}

/// Chọn màn theo trạng thái phiên: khôi phục → đăng nhập / các tab chính / lỗi mạng.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (auth.value) {
      Authenticated() => const HomeShell(),
      Unauthenticated(:final message) => LoginPage(message: message),
      RestoreFailed(:final message) => _RestoreFailedPage(message: message),
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _RestoreFailedPage extends ConsumerWidget {
  const _RestoreFailedPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).retryRestore(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
