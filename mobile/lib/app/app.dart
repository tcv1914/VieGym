import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/gym_ui.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import 'home_shell.dart';

class VieGymApp extends StatelessWidget {
  const VieGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(
      seedColor: GymColors.vibrantGreen,
      primary: GymColors.vibrantGreen,
    );
    return MaterialApp(
      title: 'VieGym',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: base,
        scaffoldBackgroundColor: GymColors.pageBg,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: GymColors.vibrantGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
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
      return const GymScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return switch (auth.value) {
      Authenticated() => const HomeShell(),
      Unauthenticated(:final message) => LoginPage(message: message),
      RestoreFailed(:final message) => _RestoreFailedPage(message: message),
      null => const GymScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _RestoreFailedPage extends ConsumerWidget {
  const _RestoreFailedPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GymScaffold(
      body: GymStateView(
        icon: Icons.cloud_off_rounded,
        accent: Theme.of(context).colorScheme.error,
        message: message,
        action: FilledButton.icon(
          onPressed: () =>
              ref.read(authControllerProvider.notifier).retryRestore(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Thử lại'),
        ),
      ),
    );
  }
}
