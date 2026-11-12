import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'ai_models.dart';

/// Backend chờ AI tối đa 30 giây (BR-AI04); app chờ thêm để kịp nhận lỗi có mã.
const chatTimeout = Duration(seconds: 35);

/// Số trang tối đa tải cho một hội thoại (100 tin/trang).
const _maxHistoryPages = 5;

/// /api/v1/ai (docs/05 §12). App chỉ gửi câu hỏi; context do backend tự lấy.
class AiApi {
  AiApi(this._auth);

  final AuthRepository _auth;

  static const _base = '/api/v1/ai';

  Future<ChatResult> chat({
    required String clientRequestId,
    required String message,
    String? conversationId,
  }) async => ChatResult.fromJson(
    (await _auth.authorizedRequest(
      'POST',
      '$_base/coach/chat',
      body: {
        'clientRequestId': clientRequestId,
        'conversationId': conversationId,
        'message': message,
      },
      timeout: chatTimeout,
    ))!,
  );

  Future<List<AiConversation>> conversations({int size = 50}) async {
    final json = (await _auth.authorizedRequest(
      'GET',
      '$_base/conversations?page=0&size=$size',
    ))!;
    return (json['items'] as List)
        .map((e) => AiConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Toàn bộ tin nhắn theo thời gian tăng dần (tối đa [_maxHistoryPages] trang).
  Future<List<ChatMessage>> messages(String conversationId) async {
    final result = <ChatMessage>[];
    for (var page = 0; page < _maxHistoryPages; page++) {
      final json = (await _auth.authorizedRequest(
        'GET',
        '$_base/conversations/${Uri.encodeComponent(conversationId)}/messages'
            '?page=$page&size=100',
      ))!;
      result.addAll(
        (json['items'] as List).map(
          (e) => ChatMessage.fromJson(e as Map<String, dynamic>),
        ),
      );
      if (json['hasNext'] != true) break;
    }
    return result;
  }
}

final aiApiProvider = Provider<AiApi>(
  (ref) => AiApi(ref.watch(authRepositoryProvider)),
);
