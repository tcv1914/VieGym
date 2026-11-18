import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/ui/gym_ui.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'TRỢ LÝ CÁ NHÂN THÔNG MINH',
        title: 'AI Coach',
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ai-new-conversation'),
        heroTag: 'ai-new-conversation-fab',
        onPressed: () => _open(context, ref, newChatKey()),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text(
          'Hỏi mới',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: switch (async) {
        AsyncData(:final value) when value.isEmpty => GymStateView(
          icon: Icons.auto_awesome_rounded,
          message:
              'Chưa có hội thoại nào.\nHỏi AI Coach về bữa ăn, lịch tập '
              'dựa trên dữ liệu bạn đã ghi.',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: GymColors.vibrantGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _open(context, ref, newChatKey()),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Bắt đầu hỏi'),
          ),
        ),
        AsyncData(:final value) => RefreshIndicator(
          color: GymColors.vibrantGreen,
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: value.length,
            itemBuilder: (context, i) {
              final c = value[i];
              final t = c.lastMessageAt;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GymCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    key: Key('ai-conversation-${c.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: GymColors.heroGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: GymColors.accentLime,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${hhmm(t.hour, t.minute)} · ${viDate(t)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => _open(context, ref, c.id),
                  ),
                ),
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
