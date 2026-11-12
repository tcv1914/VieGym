import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../workout/workout_widgets.dart';
import '../application/chat_controller.dart';
import 'chat_page.dart';

/// AI Coach (UC10): danh sách hội thoại, mới nhất trước; nút tạo hội thoại mới.
class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String key) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatPage(chatKey: key)));
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Coach')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ai-new-conversation'),
        onPressed: () => _open(context, ref, newChatKey()),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Hỏi mới'),
      ),
      body: switch (async) {
        AsyncData(:final value) when value.isEmpty => StatusMessage(
          icon: Icons.smart_toy_outlined,
          text:
              'Chưa có hội thoại nào.\nHỏi AI Coach về bữa ăn, lịch tập '
              'dựa trên dữ liệu bạn đã ghi.',
          action: TextButton(
            onPressed: () => _open(context, ref, newChatKey()),
            child: const Text('Bắt đầu hỏi'),
          ),
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = value[i];
              final t = c.lastMessageAt;
              return ListTile(
                key: Key('ai-conversation-${c.id}'),
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${hhmm(t.hour, t.minute)} · ${viDate(t)}'),
                onTap: () => _open(context, ref, c.id),
              );
            },
          ),
        ),
        AsyncError(:final error) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
