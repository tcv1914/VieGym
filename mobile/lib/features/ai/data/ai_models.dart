import 'dart:math';

/// UUID v4 cho `clientRequestId`: sinh một lần cho mỗi câu hỏi, giữ nguyên khi thử lại (BR-AI06).
String newRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum ChatRole { user, assistant }

enum RequestStatus { processing, succeeded, failed }

RequestStatus? _status(Object? code) => switch (code) {
  'PROCESSING' => RequestStatus.processing,
  'SUCCEEDED' => RequestStatus.succeeded,
  'FAILED' => RequestStatus.failed,
  _ => null,
};

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.lastMessageAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) => AiConversation(
    id: json['id'] as String,
    title: json['title'] as String,
    lastMessageAt: DateTime.parse(json['lastMessageAt'] as String).toLocal(),
  );

  final String id;
  final String title;
  final DateTime lastMessageAt;
}

/// Tin nhắn đã lưu trên server. [requestStatus]/[clientRequestId] chỉ có ở tin của người dùng.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.requestStatus,
    this.clientRequestId,
    this.errorCode,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    role: json['role'] == 'ASSISTANT' ? ChatRole.assistant : ChatRole.user,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    requestStatus: _status(json['requestStatus']),
    clientRequestId: json['clientRequestId'] as String?,
    errorCode: json['errorCode'] as String?,
  );

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final RequestStatus? requestStatus;
  final String? clientRequestId;
  final String? errorCode;

  bool get isFailedQuestion =>
      role == ChatRole.user && requestStatus == RequestStatus.failed;
}

class ChatResult {
  const ChatResult({
    required this.conversationId,
    required this.conversationTitle,
    required this.userMessage,
    this.assistantMessage,
  });

  factory ChatResult.fromJson(Map<String, dynamic> json) {
    final conversation = json['conversation'] as Map<String, dynamic>;
    final user = json['userMessage'] as Map<String, dynamic>;
    final answer = json['assistantMessage'] as Map<String, dynamic>?;
    return ChatResult(
      conversationId: conversation['id'] as String,
      conversationTitle: conversation['title'] as String,
      userMessage: ChatMessage.fromJson({
        ...user,
        'requestStatus': json['status'],
        'clientRequestId': json['clientRequestId'],
      }),
      assistantMessage: answer == null ? null : ChatMessage.fromJson(answer),
    );
  }

  final String conversationId;
  final String conversationTitle;
  final ChatMessage userMessage;
  final ChatMessage? assistantMessage;
}
