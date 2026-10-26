import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// Gọi health của backend; chỉ thành công khi cả backend và database UP.
final systemHealthProvider = FutureProvider<String>(
  (ref) async {
    final body = await ref
        .watch(apiClientProvider)
        .getJson('/api/v1/system/health');
    if (body['status'] != 'UP' || body['database'] != 'UP') {
      throw ApiException('Backend hoặc database chưa sẵn sàng');
    }
    return body['message'] as String;
  },
  // Không tự thử lại: lỗi phải hiện ngay để người dùng bấm "Thử lại".
  retry: (retryCount, error) => null,
);
