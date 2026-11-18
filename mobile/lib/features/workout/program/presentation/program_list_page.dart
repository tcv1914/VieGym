import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/gym_ui.dart';
import '../../../auth/presentation/logout_button.dart';
import '../../workout_widgets.dart';
import '../application/program_providers.dart';
import '../data/program_models.dart';
import 'program_detail_page.dart';
import 'program_form_page.dart';

/// Tab "Giáo án": giáo án của mình, badge "Đang dùng" theo server.
class ProgramListPage extends ConsumerWidget {
  const ProgramListPage({super.key});

  static Future<void> openTemplates(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const TemplateListPage()));

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
    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'CHƯƠNG TRÌNH LUYỆN TẬP',
        title: 'Giáo án của tôi',
        actions: [
          GymGlassAction(
            child: TextButton.icon(
              key: const Key('program-open-templates'),
              style: TextButton.styleFrom(
                foregroundColor: GymColors.accentLime,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              onPressed: () => openTemplates(context),
              icon: const Icon(
                Icons.library_books_outlined,
                size: 18,
                color: GymColors.accentLime,
              ),
              label: const Text('Dùng mẫu'),
            ),
          ),
          const GymGlassAction(child: LogoutButton()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('program-create'),
        heroTag: 'program-create-fab',
        onPressed: () => openCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tự tạo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: programs.when(
        skipLoadingOnRefresh: !programs.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(myProgramsProvider),
        ),
        data: (items) => items.isEmpty
            ? StatusMessage(
                icon: Icons.event_note_outlined,
                text:
                    'Bạn chưa có giáo án. Chọn một giáo án mẫu hoặc tự tạo từ thư viện bài tập.',
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: GymColors.vibrantGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => openTemplates(context),
                  icon: const Icon(Icons.library_books_outlined, size: 18),
                  label: const Text('Xem giáo án mẫu'),
                ),
              )
            : RefreshIndicator(
                color: GymColors.vibrantGreen,
                onRefresh: () => ref.refresh(myProgramsProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    for (final p in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ProgramTile(program: p),
                      ),
                  ],
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
    final scheme = Theme.of(context).colorScheme;
    return GymCard(
      cardKey: Key('program-${p.id}'),
      padding: const EdgeInsets.all(16),
      borderColor: p.isActive
          ? GymColors.vibrantGreen.withValues(alpha: 0.55)
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProgramDetailPage(id: p.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: p.isActive ? GymColors.heroGradient : null,
              color: p.isActive
                  ? null
                  : GymColors.tealAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              p.isActive ? Icons.star_rounded : Icons.event_note_rounded,
              color: p.isActive ? GymColors.accentLime : GymColors.tealAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '${p.dayCount} buổi',
                    if (p.description != null && p.description!.isNotEmpty)
                      p.description!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (p.isActive)
            const GymPill(
              key: Key('program-active-badge'),
              icon: Icons.check_circle_rounded,
              label: 'Đang dùng',
            )
          else
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class TemplateListPage extends ConsumerWidget {
  const TemplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(programTemplatesProvider);
    final scheme = Theme.of(context).colorScheme;
    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'GỢI Ý LỘ TRÌNH',
        title: 'Giáo án mẫu',
      ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GymColors.vibrantGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: GymColors.vibrantGreen.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 19,
                          color: GymColors.vibrantGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dùng mẫu sẽ tạo một bản riêng của bạn để sửa tùy ý; mẫu gốc không đổi. '
                            'Số hiệp/lần/nghỉ trong mẫu là dữ liệu minh họa, chưa được chuyên gia rà.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final p in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProgramTile(program: p),
                    ),
                ],
              ),
      ),
    );
  }
}
