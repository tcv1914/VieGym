import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_models.dart';
import '../data/program_api.dart';
import '../data/program_models.dart';

/// Mọi provider phụ thuộc phiên đăng nhập: logout/đổi tài khoản là tính lại,
/// không còn giáo án của người trước. Không tự retry (lỗi hiện nút "Thử lại").
ProgramApi _api(Ref ref) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth is! Authenticated) throw const SessionExpiredException();
  return ref.read(programApiProvider);
}

final myProgramsProvider = FutureProvider.autoDispose<List<ProgramSummary>>(
  (ref) => _api(ref).list(),
  retry: (retryCount, error) => null,
);

final programTemplatesProvider =
    FutureProvider.autoDispose<List<ProgramSummary>>(
      (ref) => _api(ref).list(templates: true),
      retry: (retryCount, error) => null,
    );

final programDetailProvider = FutureProvider.autoDispose
    .family<ProgramDetail, String>(
      (ref, id) => _api(ref).detail(id),
      retry: (retryCount, error) => null,
    );
