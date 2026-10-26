import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/features/system/system_health_provider.dart';

void main() {
  testWidgets('Hiện thông điệp khi backend và database UP', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemHealthProvider.overrideWith(
            (ref) async => 'VieGym database connected',
          ),
        ],
        child: const VieGymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kết nối backend và database thành công'), findsOneWidget);
    expect(find.text('VieGym database connected'), findsOneWidget);
  });

  testWidgets('Hiện lỗi và nút thử lại khi không kết nối được', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemHealthProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
        child: const VieGymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
  });
}
