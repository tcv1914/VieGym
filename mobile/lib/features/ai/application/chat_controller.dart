import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../data/ai_api.dart';
import '../data/ai_models.dart';

/// Câu hỏi đang gửi hoặc chưa chắc đã tới server. Giữ [clientRequestId] để gửi lại an toàn.
class PendingQuestion {
  const PendingQuestion({
    required this.clientRequestId,
    required this.content,
    this.error,
  });

  final String clientRequestId;
  final String content;

  /// null = đang gửi.
  final String? error;
}

class ChatState {
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.loading = false,
    this.loadError,
    this.pending,
    this.notice,
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final bool loading;
  final Object? loadError;
  final PendingQuestion? pending;

  /// Thông báo lỗi AI sau khi câu hỏi đã được lưu (câu hỏi hiện trong danh sách với nút Thử lại).
  final String? notice;

  bool get sending => pending != null && pending!.error == null;

  ChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? loading,
    Object? loadError,
    PendingQuestion? pending,
    bool clearPending = false,
    String? notice,
    bool clearNotice = false,
  }) => ChatState(
    conversationId: conversationId ?? this.conversationId,
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    loadError: loadError,
    pending: clearPending ? null : (pending ?? this.pending),
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

const _newPrefix = 'new:';

/// Khóa trang chat: id hội thoại có sẵn, hoặc `new:<uuid>` cho hội thoại mới.
String newChatKey() => '$_newPrefix${newRequestId()}';

/// Một màn chat. Phụ thuộc phiên đăng nhập: đổi tài khoản/đăng xuất → dựng lại, không còn tin cũ.
class ChatController extends Notifier<ChatState> {
  ChatController(this.key);

  final String key;
  int _generation = 0;

  AiApi get _api => ref.read(aiApiProvider);

  @override
  ChatState build() {
    final auth = ref.watch(authControllerProvider).value;
    _generation++;
    if (auth is! Authenticated) {
      return const ChatState(loadError: SessionExpiredException());
    }
    if (key.startsWith(_newPrefix)) return const ChatState();
    final generation = _generation;
    Future.microtask(() => _load(generation, key));
    return ChatState(conversationId: key, loading: true);
  }

  Future<void> reload() async {
    final id = state.conversationId;
    if (id == null) return;
    final generation = ++_generation;
    state = state.copyWith(loading: true, loadError: null);
    await _load(generation, id);
  }

  Future<void> _load(int generation, String id) async {
    try {
      final messages = await _api.messages(id);
      if (!_current(generation)) return;
      state = state.copyWith(messages: messages, loading: false);
    } catch (e) {
      if (!_current(generation)) return;
      state = state.copyWith(loading: false, loadError: e);
    }
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  /// Câu hỏi mới: sinh key một lần.
  Future<void> send(String text) {
    final content = text.trim();
    if (content.isEmpty || state.sending) return Future.value();
    return _submit(
      PendingQuestion(clientRequestId: newRequestId(), content: content),
    );
  }

  /// Gửi lại câu đang chờ bằng **cùng** key: server trả kết quả cũ nếu đã xong, không tạo câu trùng.
  Future<void> retryPending() {
    final p = state.pending;
    if (p == null || state.sending) return Future.value();
    return _submit(
      PendingQuestion(clientRequestId: p.clientRequestId, content: p.content),
    );
  }

  /// Thử lại câu hỏi đã lưu ở trạng thái FAILED (BR-AI06: cùng key, cùng tin nhắn).
  Future<void> retryFailed(ChatMessage message) {
    final key = message.clientRequestId;
    if (key == null || state.sending) return Future.value();
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != message.id).toList(),
    );
    return _submit(
      PendingQuestion(clientRequestId: key, content: message.content),
    );
  }

  /// Bỏ câu chưa gửi được (lỗi trước khi server lưu) để sửa lại; trả nội dung cho ô nhập.
  String? discardPending() {
    final p = state.pending;
    if (p == null || state.sending) return null;
    state = state.copyWith(clearPending: true);
    return p.content;
  }

  Future<void> _submit(PendingQuestion question) async {
    final generation = _generation;
    state = state.copyWith(pending: question, clearNotice: true);
    try {
      final result = await _api.chat(
        clientRequestId: question.clientRequestId,
        message: question.content,
        conversationId: state.conversationId,
      );
      if (!_current(generation)) return;
      final ids = {result.userMessage.id, result.assistantMessage?.id};
      state = state.copyWith(
        conversationId: result.conversationId,
        messages: [
          ...state.messages.where((m) => !ids.contains(m.id)),
          result.userMessage,
          ?result.assistantMessage,
        ],
        clearPending: true,
      );
    } on ApiException catch (e) {
      if (!_current(generation)) return;
      if (e.data['retryable'] == true) {
        // AI lỗi nhưng câu hỏi đã lưu (BR-AI05): tải lại để câu hỏi hiện với nút Thử lại.
        final id = e.data['conversationId'] as String?;
        state = state.copyWith(
          conversationId: id,
          clearPending: true,
          notice: e.message,
        );
        await reload();
        return;
      }
      state = state.copyWith(
        pending: PendingQuestion(
          clientRequestId: question.clientRequestId,
          content: question.content,
          error: _errorText(e),
        ),
      );
    } on NetworkException {
      if (!_current(generation)) return;
      state = state.copyWith(
        pending: PendingQuestion(
          clientRequestId: question.clientRequestId,
          content: question.content,
          error:
              'Mất kết nối, chưa rõ câu hỏi đã tới máy chủ chưa. '
              'Bấm "Thử lại" để kiểm tra — không tạo câu hỏi trùng.',
        ),
      );
    }
  }

  static String _errorText(ApiException e) => switch (e.code) {
    'RATE_LIMITED' => e.data['retryAfterSeconds'] is num
        ? '${e.message} (khoảng ${e.data['retryAfterSeconds']} giây).'
        : e.message,
    'AI_REQUEST_IN_PROGRESS' =>
      'AI đang trả lời câu hỏi trước. Chờ vài giây rồi bấm "Thử lại".',
    'VALIDATION_ERROR' => e.fieldErrors['message'] ?? e.message,
    _ => e.message,
  };
}

final chatProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, String>(ChatController.new);

/// Danh sách hội thoại của user đang đăng nhập.
final conversationsProvider = FutureProvider.autoDispose<List<AiConversation>>(
  (ref) {
    final auth = ref.watch(authControllerProvider).value;
    if (auth is! Authenticated) throw const SessionExpiredException();
    return ref.read(aiApiProvider).conversations();
  },
  retry: (retryCount, error) => null,
);
