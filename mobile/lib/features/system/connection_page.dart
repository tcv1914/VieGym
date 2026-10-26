import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'system_health_provider.dart';

class ConnectionPage extends ConsumerWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(systemHealthProvider);
    void retry() => ref.invalidate(systemHealthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('VieGym — Kiểm tra kết nối')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: result.when(
            skipLoadingOnRefresh: false,
            loading: () => const CircularProgressIndicator(),
            data: (message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const Text('Kết nối backend và database thành công'),
                Text(message),
                TextButton(onPressed: retry, child: const Text('Kiểm tra lại')),
              ],
            ),
            error: (error, stack) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const Text('Chưa kết nối được. Kiểm tra server và địa chỉ API.'),
                TextButton(onPressed: retry, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
