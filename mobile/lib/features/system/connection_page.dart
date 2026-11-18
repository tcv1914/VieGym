import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/gym_ui.dart';
import 'system_health_provider.dart';

class ConnectionPage extends ConsumerWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(systemHealthProvider);
    final scheme = Theme.of(context).colorScheme;
    void retry() => ref.invalidate(systemHealthProvider);

    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'HỆ THỐNG MÁY CHỦ',
        title: 'VieGym — Kiểm tra kết nối',
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: result.when(
            skipLoadingOnRefresh: false,
            loading: () => const CircularProgressIndicator(),
            data: (message) => GymCard(
              padding: const EdgeInsets.all(28),
              borderColor: GymColors.vibrantGreen.withValues(alpha: 0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: GymColors.vibrantGreen.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: GymColors.vibrantGreen,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kết nối backend và database thành công',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: GymColors.vibrantGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GymColors.heroMid,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Kiểm tra lại'),
                  ),
                ],
              ),
            ),
            error: (error, stack) => GymCard(
              padding: const EdgeInsets.all(28),
              borderColor: scheme.error.withValues(alpha: 0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: scheme.error,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa kết nối được. Kiểm tra server và địa chỉ API.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: retry,
                    style: FilledButton.styleFrom(
                      backgroundColor: GymColors.vibrantGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
