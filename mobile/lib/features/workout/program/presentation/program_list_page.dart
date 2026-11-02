import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/logout_button.dart';
import '../../workout_widgets.dart';
import '../application/program_providers.dart';
import '../data/program_models.dart';
import 'program_detail_page.dart';
import 'program_form_page.dart';

/// Tab "Giáo án": giáo án của mình, badge "Đang dùng" theo server.
class ProgramListPage extends ConsumerWidget {
  const ProgramListPage({super.key});

  static Future<void> openTemplates(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TemplateListPage()),
      );

  static Future<void> openCreate(BuildContext context) async {
    final created = await Navigator.of(context).push<ProgramDetail>(
      MaterialPageRoute(builder: (_) => const ProgramFormPage()),
    );
    if (created != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProgramDetailPage(id: created.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(myProgramsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giáo án của tôi'),
        actions: [
          TextButton.icon(
            key: const Key('program-open-templates'),
            onPressed: () => openTemplates(context),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Dùng mẫu'),
          ),
          const LogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('program-create'),
        onPressed: () => openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Tự tạo'),
      ),
      body: programs.when(
        skipLoadingOnRefresh: !programs.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorRetry(error: e, onRetry: () => ref.invalidate(myProgramsProvider)),
        data: (items) => items.isEmpty
            ? StatusMessage(
                icon: Icons.event_note_outlined,
                text:
                    'Bạn chưa có giáo án. Chọn một giáo án mẫu hoặc tự tạo từ thư viện bài tập.',
                action: TextButton(
                  onPressed: () => openTemplates(context),
                  child: const Text('Xem giáo án mẫu'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myProgramsProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [for (final p in items) ProgramTile(program: p)],
                ),
              ),
      ),
    );
  }
}

class ProgramTile extends StatelessWidget {
  const ProgramTile({super.key, required this.program});

  final ProgramSummary program;

  @override
  Widget build(BuildContext context) {
    final p = program;
    return ListTile(
      key: Key('program-${p.id}'),
      leading: Icon(
        p.isActive ? Icons.star : Icons.event_note_outlined,
        color: p.isActive ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(p.name),
      subtitle: Text(
        [
          '${p.dayCount} buổi',
          if (p.description != null && p.description!.isNotEmpty)
            p.description!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: p.isActive
          ? const Chip(
              key: Key('program-active-badge'),
              label: Text('Đang dùng'),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProgramDetailPage(id: p.id)),
      ),
    );
  }
}

class TemplateListPage extends ConsumerWidget {
  const TemplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(programTemplatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Giáo án mẫu')),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(programTemplatesProvider),
        ),
        data: (items) => items.isEmpty
            ? const StatusMessage(
                icon: Icons.library_books_outlined,
                text: 'Chưa có giáo án mẫu.',
              )
            : ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Dùng mẫu sẽ tạo một bản riêng của bạn để sửa tùy ý; mẫu gốc không đổi. '
                      'Số hiệp/lần/nghỉ trong mẫu là dữ liệu minh họa, chưa được chuyên gia rà.',
                    ),
                  ),
                  for (final p in items) ProgramTile(program: p),
                ],
              ),
      ),
    );
  }
}
