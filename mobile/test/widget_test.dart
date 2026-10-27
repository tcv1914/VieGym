import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/system/connection_page.dart';
import 'package:mobile/features/system/system_health_provider.dart';

Widget _connectionPage(Future<String> Function(Ref ref) health) => ProviderScope(
      overrides: [systemHealthProvider.overrideWith(health)],
      child: const MaterialApp(home: ConnectionPage()),
    );

void main() {
  testWidgets('Hiện thông điệp khi backend và database UP', (tester) async {
    await tester.pumpWidget(
      _connectionPage((ref) async => 'VieGym database connected'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kết nối backend và database thành công'), findsOneWidget);
    expect(find.text('VieGym database connected'), findsOneWidget);
  });

  testWidgets('Hiện lỗi và nút thử lại khi không kết nối được', (tester) async {
    await tester.pumpWidget(
      _connectionPage((ref) async => throw Exception('offline')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
  });
}
