import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/workout_widgets.dart';
import '../application/chat_controller.dart';
import '../data/ai_models.dart';
import 'coach_text.dart';

/// BR-AI04: câu hỏi tối đa 2.000 ký tự.
const maxQuestionLength = 2000;

/// Khung chat. Không render HTML, không tự mở link; câu trả lời AI chỉ nhận đậm và gạch đầu
/// dòng ([CoachText]), câu hỏi của user hiển thị nguyên văn.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatKey});

  /// Id hội thoại có sẵn hoặc khóa `new:` từ [newChatKey].
  final String chatKey;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatController get _controller =>
      ref.read(chatProvider(widget.chatKey).notifier);

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _scrollToEnd();
    await _controller.send(text);
    _scrollToEnd();
  }

  void _edit() {
    final text = _controller.discardPending();
    if (text != null) _input.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.chatKey));
    ref.listen(
      chatProvider(widget.chatKey).select((s) => s.messages.length),
      (_, _) => _scrollToEnd(),
    );
    final theme = Theme.of(context);
    final length = _input.text.trim().length;
    final canSend =
        !state.sending && length > 0 && length <= maxQuestionLength;

    Widget body;
    if (state.messages.isEmpty && state.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.messages.isEmpty && state.loadError != null) {
      body = ErrorRetry(error: state.loadError!, onRetry: _controller.reload);
    } else {
      final pending = state.pending;
      body = ListView(
        key: const Key('ai-messages'),
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        children: [
          if (state.messages.isEmpty && pending == null)
            const _Intro(),
          for (final m in state.messages)
            _Bubble(
              message: m,
              onRetry: m.isFailedQuestion && !state.sending
                  ? () => _controller.retryFailed(m)
                  : null,
            ),
          if (pending != null)
            _PendingBubble(
              pending: pending,
              onRetry: _controller.retryPending,
              onEdit: _edit,
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Coach')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Gợi ý của AI chỉ để tham khảo, không thay thế bác sĩ hay chuyên gia. '
              'AI không tự sửa lịch tập, thực đơn hay hồ sơ của bạn.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (state.notice != null)
            MaterialBanner(
              key: const Key('ai-notice'),
              backgroundColor: theme.colorScheme.errorContainer,
              content: Text(state.notice!),
              actions: [
                TextButton(
                  onPressed: () => _controller.reload(),
                  child: const Text('Tải lại'),
                ),
              ],
            ),
          Expanded(child: body),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: maxQuestionLength,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Hỏi về bữa ăn, lịch tập…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: IconButton.filled(
                      key: const Key('ai-send'),
                      tooltip: 'Gửi',
                      onPressed: canSend ? _send : null,
                      icon: state.sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Text(
      'AI Coach xem hồ sơ, mục tiêu, thực đơn hôm nay, các buổi tập gần đây và lịch 7 ngày tới '
      'của bạn để trả lời. Ví dụ: "Hôm nay tôi còn thiếu bao nhiêu đạm?"',
      textAlign: TextAlign.center,
    ),
  );
}

class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({
    super.key,
    required this.mine,
    required this.child,
    this.error = false,
  });

  final bool mine;
  final bool error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: error
                ? scheme.errorContainer
                : mine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message.isFailedQuestion;
    return _BubbleFrame(
      key: Key('ai-message-${message.id}'),
      mine: message.role == ChatRole.user,
      error: failed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.role == ChatRole.assistant)
            CoachText(message.content)
          else
            SelectableText(message.content),
          if (failed) ...[
            const SizedBox(height: 6),
            Text(
              message.errorCode == 'AI_TIMEOUT'
                  ? 'AI phản hồi quá lâu.'
                  : 'AI chưa trả lời được câu này.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onRetry != null)
              TextButton.icon(
                key: Key('ai-retry-${message.id}'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
          ],
        ],
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({
    required this.pending,
    required this.onRetry,
    required this.onEdit,
  });

  final PendingQuestion pending;
  final VoidCallback onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final error = pending.error;
    return Column(
      children: [
        _BubbleFrame(
          key: const Key('ai-pending'),
          mine: true,
          error: error != null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pending.content),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error, style: Theme.of(context).textTheme.bodySmall),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: const Key('ai-pending-retry'),
                      onPressed: onRetry,
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      key: const Key('ai-pending-edit'),
                      onPressed: onEdit,
                      child: const Text('Sửa'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (error == null)
          const _BubbleFrame(
            mine: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('AI đang trả lời…', key: Key('ai-typing')),
              ],
            ),
          ),
      ],
    );
  }
}
