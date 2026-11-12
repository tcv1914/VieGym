import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/ai/application/chat_controller.dart';
import 'package:mobile/features/ai/data/ai_api.dart';
import 'package:mobile/features/ai/data/ai_models.dart';
import 'package:mobile/features/ai/presentation/chat_page.dart';
import 'package:mobile/features/ai/presentation/coach_text.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/auth_models.dart';

AuthUser _user(String id) => AuthUser(
  id: id,
  email: '$id@example.com',
  fullName: 'Minh',
  role: 'USER',
  hasHealthProfile: true,
);

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => Authenticated(_user('u1'));

  void switchTo(String id) => state = AsyncData(Authenticated(_user(id)));
}

Map<String, dynamic> _msg(
  String id,
  String role,
  String content, {
  String? status,
  String? key,
  String? error,
}) => {
  'id': id,
  'role': role,
  'content': content,
  'createdAt': '2026-11-09T03:00:00Z',
  'requestStatus': ?status,
  'clientRequestId': ?key,
  'errorCode': ?error,
};

class _FakeAiApi implements AiApi {
  final chats = <Map<String, Object?>>[];
  final history = <String, List<ChatMessage>>{};
  Object? Function(Map<String, Object?> call)? fail;
  Completer<ChatResult>? hold;
  int _n = 0;

  @override
  Future<ChatResult> chat({
    required String clientRequestId,
    required String message,
    String? conversationId,
  }) async {
    final call = {
      'key': clientRequestId,
      'message': message,
      'conversationId': conversationId,
    };
    chats.add(call);
    final h = hold;
    if (h != null) return h.future;
    final error = fail?.call(call);
    if (error != null) throw error;
    _n++;
    final conv = conversationId ?? 'c1';
    final result = ChatResult.fromJson({
      'requestId': 'r$_n',
      'clientRequestId': clientRequestId,
      'status': 'SUCCEEDED',
      'conversation': {'id': conv, 'title': message},
      'userMessage': _msg('q-$clientRequestId', 'USER', message),
      'assistantMessage': _msg('a$_n', 'ASSISTANT', 'Đáp: $message'),
    });
    history[conv] = [
      ...?history[conv],
      result.userMessage,
      result.assistantMessage!,
    ];
    return result;
  }

  @override
  Future<List<AiConversation>> conversations({int size = 50}) async => [];

  @override
  Future<List<ChatMessage>> messages(String conversationId) async =>
      history[conversationId] ?? [];
}

ProviderContainer _container(_FakeAiApi api) {
  final c = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      aiApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

ApiException _aiError(String code, int status) => ApiException(
  'Dịch vụ AI đang gặp sự cố. Câu hỏi đã được lưu, bạn có thể thử lại',
  statusCode: status,
  code: code,
  data: {
    'code': code,
    'retryable': true,
    'conversationId': 'c1',
    'requestId': 'r-failed',
    'userMessageId': 'q-failed',
  },
);

void main() {
  test('newRequestId: UUID v4 hợp lệ, khác nhau', () {
    final a = newRequestId();
    final b = newRequestId();
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(v4.hasMatch(a), isTrue);
    expect(a, isNot(b));
  });

  group('ChatController', () {
    late _FakeAiApi api;
    late ProviderContainer c;
    late String key;

    setUp(() async {
      api = _FakeAiApi();
      c = _container(api);
      await c.read(authControllerProvider.future);
      key = newChatKey();
      c.listen(chatProvider(key), (_, _) {});
    });

    ChatController ctrl() => c.read(chatProvider(key).notifier);
    ChatState st() => c.read(chatProvider(key));

    test('Gửi thành công: thêm câu hỏi + trả lời, nhớ hội thoại cho lượt sau', () async {
      await ctrl().send('  Câu 1  ');
      expect(st().conversationId, 'c1');
      expect(st().messages.map((m) => m.content), ['Câu 1', 'Đáp: Câu 1']);
      expect(st().pending, isNull);
      expect(api.chats.single['conversationId'], isNull);

      await ctrl().send('Câu 2');
      expect(api.chats.last['conversationId'], 'c1');
      expect(api.chats[0]['key'], isNot(api.chats[1]['key']));
      expect(st().messages, hasLength(4));
    });

    test('Không gửi câu rỗng; không gửi lặp khi đang chờ', () async {
      await ctrl().send('   ');
      expect(api.chats, isEmpty);
      api.hold = Completer();
      final first = ctrl().send('Câu 1');
      expect(st().sending, isTrue);
      await ctrl().send('Câu 2');
      expect(api.chats, hasLength(1));
      final hold = api.hold!;
      api.hold = null;
      hold.completeError(const NetworkException());
      await first;
      expect(st().pending!.error, isNotNull);
    });

    test('AI05: lỗi AI → câu hỏi đã lưu hiện FAILED + thông báo; thử lại dùng cùng key', () async {
      api.fail = (_) => _aiError('AI_TIMEOUT', 504);
      api.history['c1'] = [
        ChatMessage.fromJson(
          _msg('q-failed', 'USER', 'Câu lỗi', status: 'FAILED', key: 'k-1',
              error: 'AI_TIMEOUT'),
        ),
      ];
      await ctrl().send('Câu lỗi');
      expect(st().pending, isNull);
      expect(st().notice, isNotNull);
      expect(st().conversationId, 'c1');
      final failed = st().messages.single;
      expect(failed.isFailedQuestion, isTrue);

      api.fail = null;
      api.history['c1'] = [];
      await ctrl().retryFailed(failed);
      expect(api.chats.last['key'], 'k-1');
      expect(api.chats.last['message'], 'Câu lỗi');
      expect(st().messages.map((m) => m.content), ['Câu lỗi', 'Đáp: Câu lỗi']);
      expect(st().notice, isNull);
    });

    test('AI04: mất mạng → giữ câu hỏi, thử lại cùng key (không tạo câu trùng)', () async {
      api.fail = (_) => const NetworkException();
      await ctrl().send('Câu mạng');
      final pending = st().pending!;
      expect(pending.error, contains('Thử lại'));
      expect(st().messages, isEmpty);

      api.fail = null;
      await ctrl().retryPending();
      expect(api.chats.map((x) => x['key']).toSet(), {pending.clientRequestId});
      expect(st().pending, isNull);
      expect(st().messages, hasLength(2));
    });

    test('429: giữ câu hỏi kèm thời gian chờ; Sửa trả nội dung về ô nhập', () async {
      api.fail = (_) => ApiException(
        'Bạn hỏi hơi nhanh, vui lòng chờ một chút rồi thử lại',
        statusCode: 429,
        code: 'RATE_LIMITED',
        data: {'retryAfterSeconds': 42},
      );
      await ctrl().send('Câu nhanh');
      expect(st().pending!.error, contains('42 giây'));
      expect(ctrl().discardPending(), 'Câu nhanh');
      expect(st().pending, isNull);
    });

    test('AI08: đổi tài khoản → không còn tin nhắn của người trước', () async {
      await ctrl().send('Bí mật của A');
      expect(st().messages, isNotEmpty);
      (c.read(authControllerProvider.notifier) as _Auth).switchTo('u2');
      await Future<void>.delayed(Duration.zero);
      expect(st().messages, isEmpty);
      expect(st().conversationId, isNull);
    });

    test('Mở hội thoại có sẵn: tải lịch sử theo thứ tự server', () async {
      api.history['c9'] = [
        ChatMessage.fromJson(_msg('1', 'USER', 'Một')),
        ChatMessage.fromJson(_msg('2', 'ASSISTANT', 'Hai')),
      ];
      c.listen(chatProvider('c9'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final s = c.read(chatProvider('c9'));
      expect(s.conversationId, 'c9');
      expect(s.messages.map((m) => m.content), ['Một', 'Hai']);
    });
  });

  group('ChatPage', () {
    Future<_FakeAiApi> pump(WidgetTester tester, {String? chatKey}) async {
      final api = _FakeAiApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_Auth.new),
            aiApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(home: ChatPage(chatKey: chatKey ?? newChatKey())),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('Gửi: khóa nút khi chờ, hiện "đang trả lời", rồi hiện câu trả lời', (
      tester,
    ) async {
      final api = await pump(tester);
      expect(find.textContaining('chỉ để tham khảo'), findsOneWidget);
      final send = find.byKey(const Key('ai-send'));
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      api.hold = Completer();
      await tester.enterText(find.byKey(const Key('ai-input')), 'Hôm nay ăn gì?');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      expect(find.byKey(const Key('ai-typing')), findsOneWidget);
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      final hold = api.hold!;
      api.hold = null;
      hold.complete(
        ChatResult.fromJson({
          'requestId': 'r1',
          'clientRequestId': api.chats.single['key'],
          'status': 'SUCCEEDED',
          'conversation': {'id': 'c1', 'title': 't'},
          'userMessage': _msg('q1', 'USER', 'Hôm nay ăn gì?'),
          'assistantMessage': _msg('a1', 'ASSISTANT', '<b>Phở</b> và rau'),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-typing')), findsNothing);
      // Văn bản thuần: thẻ HTML hiện nguyên, không được diễn giải.
      expect(find.text('<b>Phở</b> và rau'), findsOneWidget);
    });

    testWidgets('AI05: lỗi AI → câu hỏi đỏ có nút Thử lại', (tester) async {
      final api = await pump(tester);
      api.fail = (_) => _aiError('AI_UPSTREAM_ERROR', 502);
      api.history['c1'] = [
        ChatMessage.fromJson(
          _msg('q-failed', 'USER', 'Câu lỗi', status: 'FAILED', key: 'k-1',
              error: 'AI_UPSTREAM_ERROR'),
        ),
      ];
      await tester.enterText(find.byKey(const Key('ai-input')), 'Câu lỗi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-notice')), findsOneWidget);
      expect(find.byKey(const Key('ai-retry-q-failed')), findsOneWidget);
      expect(find.byKey(const Key('ai-typing')), findsNothing);
    });

    testWidgets('AI07: quá 2.000 ký tự không gửi được', (tester) async {
      final api = await pump(tester);
      final field = tester.widget<TextField>(find.byKey(const Key('ai-input')));
      expect(field.maxLength, 2000);
      await tester.enterText(find.byKey(const Key('ai-input')), 'x' * 2000);
      await tester.pump();
      expect(
        tester.widget<IconButton>(find.byKey(const Key('ai-send'))).onPressed,
        isNotNull,
      );
      expect(api.chats, isEmpty);
    });
  });

  group('CoachText', () {
    String plain(List<TextSpan> spans) => spans.map((s) => s.text).join();
    List<String> bold(List<TextSpan> spans) => [
      for (final s in spans)
        if (s.style?.fontWeight == FontWeight.bold) s.text!,
    ];

    test('Markdown Gemini thật: **đậm** và "*   " thành chữ đậm + gạch đầu dòng', () {
      final spans = coachSpans(
        'Chào bạn,\n\n*   **Lượng kcal:**\n    *   Mục tiêu là 2084.6 kcal.\n- Nghỉ ngơi',
      );
      expect(
        plain(spans),
        'Chào bạn,\n\n• Lượng kcal:\n    ◦ Mục tiêu là 2084.6 kcal.\n• Nghỉ ngơi',
      );
      expect(bold(spans), ['Lượng kcal:']);
    });

    test('Tiêu đề # thành dòng đậm; ** lẻ, HTML và link giữ nguyên văn', () {
      final spans = coachSpans(
        '## Gợi ý **bữa tối**\n2 ** 3 <b>x</b> [link](http://a.b) 5*3',
      );
      expect(
        plain(spans),
        'Gợi ý bữa tối\n2 ** 3 <b>x</b> [link](http://a.b) 5*3',
      );
      expect(bold(spans), ['Gợi ý bữa tối']);
    });
  });
}
