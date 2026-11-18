import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/gym_ui.dart';
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
      if (mounted) {
        showSnack(context, 'Đã đặt "${program.name}" làm giáo án đang dùng');
      }
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
    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'CHI TIẾT GIÁO ÁN',
        title: program?.name ?? 'Giáo án',
        actions: [
          if (program != null && !program.isTemplate)
            GymGlassAction(
              child: IconButton(
                key: const Key('program-edit'),
                tooltip: 'Sửa',
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _edit(program),
                icon: const Icon(Icons.edit_outlined),
              ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (p.isTemplate)
              const _Banner(
                icon: Icons.info_outline_rounded,
                text:
                    'Giáo án mẫu chỉ để xem. Dùng mẫu sẽ tạo bản của bạn để sửa và xếp lịch.',
              )
            else if (p.isActive)
              const _Banner(
                icon: Icons.star_rounded,
                text: 'Đây là giáo án bạn đang dùng.',
              ),
            if (p.description != null && p.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GymCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    p.description!,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
            for (final d in p.days)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DayCard(day: d),
              ),
            const SizedBox(height: 8),
            if (p.isTemplate)
              BusyButton(
                key: const Key('program-copy'),
                busy: _busy,
                onPressed: () => _copy(p),
                icon: Icons.copy_rounded,
                label: 'Dùng giáo án này',
              )
            else if (!p.isActive)
              BusyButton(
                key: const Key('program-activate'),
                busy: _busy,
                onPressed: () => _activate(p),
                icon: Icons.star_rounded,
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: GymColors.vibrantGreen.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: GymColors.vibrantGreen.withValues(alpha: 0.30),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: GymColors.vibrantGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: GymColors.heroMid,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Một buổi và các bài của nó (dùng ở chi tiết giáo án và chi tiết lịch).
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.day, this.title});

  final ProgramDay day;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return GymCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GymSectionHeader(
            icon: Icons.fitness_center_rounded,
            title: title ?? day.name,
            trailing: GymPill(
              label: '${day.exercises.length} bài',
              color: GymColors.tealAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          for (final e in day.exercises) ExerciseLine(exercise: e),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: ExerciseThumbnail(url: e.thumbnailUrl, size: 50),
      title: Text(
        e.exerciseName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          e.exerciseActive
              ? planText(e.targetSets, e.targetReps, e.restSeconds)
              : 'Bài đã ngừng sử dụng — cần thay bài khác',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: e.exerciseActive
                ? GymColors.heroMid
                : scheme.error,
          ),
        ),
      ),
    );
  }
}
