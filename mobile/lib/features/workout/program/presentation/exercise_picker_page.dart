import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/gym_ui.dart';
import '../../../exercise/data/exercise_api.dart';
import '../../../exercise/data/exercise_models.dart';
import '../../../exercise/presentation/exercise_media.dart';
import '../../workout_widgets.dart';

/// Chọn một bài từ thư viện ngày 6 (bài active, ID thật). Trả về [ExerciseSummary] đã chọn.
/// Bài đã có trong buổi hiện mờ, không chọn lại được.
class ExercisePickerPage extends ConsumerStatefulWidget {
  const ExercisePickerPage({super.key, this.alreadyInDay = const {}});

  final Set<String> alreadyInDay;

  static const pageSize = 100;

  @override
  ConsumerState<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends ConsumerState<ExercisePickerPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  bool _loading = true;
  Object? _error;
  ExercisePage? _page;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String keyword) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(exerciseApiProvider)
          .search(
            ExerciseQuery(keyword: keyword),
            page: 0,
            size: ExercisePickerPage.pageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(value));
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      appBar: const GymAppBar(
        eyebrow: 'THÊM VÀO BUỔI TẬP',
        title: 'Chọn bài tập',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('picker-search'),
              controller: _search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                _load(v);
              },
              textInputAction: TextInputAction.search,
              decoration: gymInputDecoration(
                context,
                hintText: 'Tìm theo tên bài Việt hoặc Anh...',
                prefixIcon: Icons.search_rounded,
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorRetry(error: _error!, onRetry: () => _load(_search.text));
    }
    final items = _page!.items;
    if (items.isEmpty) {
      return const StatusMessage(
        icon: Icons.search_off_rounded,
        text: 'Không tìm thấy bài tập phù hợp.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GymCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: Key('pick-${e.id}'),
                enabled: !widget.alreadyInDay.contains(e.id),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: ExerciseThumbnail(url: e.thumbnailUrl, size: 52),
                title: Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: widget.alreadyInDay.contains(e.id)
                    ? const Text('Đã có trong buổi này')
                    : null,
                trailing: widget.alreadyInDay.contains(e.id)
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: GymColors.vibrantGreen,
                      )
                    : const Icon(Icons.add_circle_outline_rounded),
                onTap: () => Navigator.of(context).pop(e),
              ),
            ),
          ),
        if (_page!.hasNext)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: GymPill(
                icon: Icons.search_rounded,
                label: 'Còn bài khác, hãy gõ tên để tìm.',
              ),
            ),
          ),
      ],
    );
  }
}
