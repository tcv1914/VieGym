import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/application/dashboard_providers.dart';

import '../../../exercise/presentation/exercise_media.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../workout_widgets.dart';
import '../application/program_providers.dart';
import '../data/program_api.dart';
import '../data/program_models.dart';
import 'program_form_page.dart';

/// Chi tiết giáo án của mình hoặc giáo án mẫu. Tải lại theo ID mỗi lần mở.
class ProgramDetailPage extends ConsumerStatefulWidget {
  const ProgramDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends ConsumerState<ProgramDetailPage> {
  bool _busy = false;

  Future<void> _copy(ProgramDetail template) async {
    setState(() => _busy = true);
    try {
      final copy = await ref.read(programApiProvider).copyTemplate(template.id);
      ref.invalidate(myProgramsProvider);
      if (!mounted) return;
      showSnack(context, 'Đã tạo "${copy.name}" trong giáo án của bạn');
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProgramDetailPage(id: copy.id)),
      );
    } catch (e) {
      if (mounted) showSnack(context, createErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate(ProgramDetail program) async {
    setState(() => _busy = true);
    try {
      await ref.read(programApiProvider).activate(program.id);
      ref.invalidate(myProgramsProvider);
      ref.invalidate(programDetailProvider(program.id));
      if (mounted) showSnack(context, 'Đã đặt "${program.name}" làm giáo án đang dùng');
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ProgramDetail program) async {
    final saved = await Navigator.of(context).push<ProgramDetail>(
      MaterialPageRoute(builder: (_) => ProgramFormPage(initial: program)),
    );
    // Lưu xong hoặc form báo xung đột (cần bản mới): đều tải lại.
    ref.invalidate(programDetailProvider(program.id));
    if (saved != null) {
      ref.invalidate(myProgramsProvider);
      // Lịch của buổi bị gỡ đổi trạng thái archived; tên buổi có thể đổi.
      ref.invalidate(weekSchedulesProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(programDetailProvider(widget.id));
    final program = detail.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(program?.name ?? 'Giáo án'),
        actions: [
          if (program != null && !program.isTemplate)
            IconButton(
              key: const Key('program-edit'),
              tooltip: 'Sửa',
              onPressed: _busy ? null : () => _edit(program),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: detail.when(
        skipLoadingOnRefresh: !detail.hasError,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(programDetailProvider(widget.id)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (p.isTemplate)
              const _Banner(
                icon: Icons.info_outline,
                text:
                    'Giáo án mẫu chỉ để xem. Dùng mẫu sẽ tạo bản của bạn để sửa và xếp lịch.',
              )
            else if (p.isActive)
              const _Banner(
                icon: Icons.star,
                text: 'Đây là giáo án bạn đang dùng.',
              ),
            if (p.description != null && p.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(p.description!),
              ),
            for (final d in p.days) DayCard(day: d),
            const SizedBox(height: 16),
            if (p.isTemplate)
              BusyButton(
                key: const Key('program-copy'),
                busy: _busy,
                onPressed: () => _copy(p),
                icon: Icons.copy,
                label: 'Dùng giáo án này',
              )
            else if (!p.isActive)
              BusyButton(
                key: const Key('program-activate'),
                busy: _busy,
                onPressed: () => _activate(p),
                icon: Icons.star_outline,
                label: 'Đặt làm giáo án đang dùng',
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(leading: Icon(icon), title: Text(text)),
  );
}

/// Một buổi và các bài của nó (dùng ở chi tiết giáo án và chi tiết lịch).
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.day, this.title});

  final ProgramDay day;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title ?? day.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final e in day.exercises) ExerciseLine(exercise: e),
          ],
        ),
      ),
    );
  }
}

class ExerciseLine extends StatelessWidget {
  const ExerciseLine({super.key, required this.exercise});

  final ProgramExercise exercise;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return ListTile(
      dense: true,
      leading: ExerciseThumbnail(url: e.thumbnailUrl),
      title: Text(e.exerciseName),
      subtitle: Text(
        e.exerciseActive
            ? planText(e.targetSets, e.targetReps, e.restSeconds)
            : 'Bài đã ngừng sử dụng — cần thay bài khác',
        style: e.exerciseActive
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
