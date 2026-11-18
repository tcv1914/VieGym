import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/ui/gym_ui.dart';
import '../../workout_widgets.dart';
import '../application/log_providers.dart';
import '../data/log_api.dart';
import '../data/log_models.dart';
import 'log_detail_page.dart';
import 'log_format.dart';

/// Lịch sử luyện tập: mới nhất trước, lọc theo khoảng ngày tập, tải thêm từng trang.
/// Lỗi ở trang sau giữ nguyên các mục đã tải.
class LogHistoryPage extends ConsumerStatefulWidget {
  const LogHistoryPage({super.key});

  @override
  ConsumerState<LogHistoryPage> createState() => _LogHistoryPageState();
}

class _LogHistoryPageState extends ConsumerState<LogHistoryPage> {
  static const _pageSize = 20;

  DateTimeRange? _range;
  final _items = <LogSummary>[];
  int _nextPage = 0;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _generation++;
    setState(() {
      _items.clear();
      _nextPage = 0;
      _hasNext = true;
      _error = null;
      _loading = false;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(logApiProvider)
          .list(
            from: _range == null ? null : dateOnly(_range!.start),
            to: _range == null ? null : dateOnly(_range!.end),
            page: _nextPage,
            size: _pageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _nextPage = page.page + 1;
        _hasNext = page.hasNext;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Lọc theo ngày tập',
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays + 1 > 366) {
      if (mounted) showSnack(context, 'Chọn khoảng tối đa 366 ngày');
      return;
    }
    _range = picked;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(logHistoryVersionProvider, (_, _) => _reload());
    final range = _range;
    return GymScaffold(
      appBar: GymAppBar(
        eyebrow: 'NHẬT KÝ HOÀN THÀNH',
        title: 'Lịch sử tập',
        actions: [
          GymGlassAction(
            child: IconButton(
              key: const Key('history-filter'),
              tooltip: 'Lọc theo ngày',
              visualDensity: VisualDensity.compact,
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (range != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: GymColors.vibrantGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: GymColors.heroMid,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${viDate(range.start)} – ${viDate(range.end)}',
                      key: const Key('history-range'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GymColors.heroMid,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('history-clear'),
                    onPressed: () {
                      _range = null;
                      _reload();
                    },
                    child: const Text('Bỏ lọc'),
                  ),
                ],
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) return ErrorRetry(error: _error!, onRetry: _loadMore);
      return StatusMessage(
        key: const Key('history-empty'),
        icon: Icons.history_rounded,
        text: _range == null
            ? 'Chưa có buổi tập nào được ghi. Mở một buổi trong "Lịch tập" và bấm "Bắt đầu tập".'
            : 'Không có buổi tập nào trong khoảng ngày này.',
      );
    }
    return RefreshIndicator(
      color: GymColors.vibrantGreen,
      onRefresh: () async => _reload(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) return _LogTile(log: _items[i]);
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return GymCard(
              child: Row(
                children: [
                  Expanded(child: Text(_error.toString())),
                  TextButton(
                    onPressed: _loadMore,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          if (_hasNext) {
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: FilledButton.tonalIcon(
                  key: const Key('history-more'),
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Tải thêm'),
                ),
              ),
            );
          }
          return const SizedBox(height: 16);
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final LogSummary log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = log.durationMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GymCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: Key('history-${log.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: Container(
            width: 54,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              gradient: GymColors.heroGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    viDayMonth(log.workoutDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    '${log.workoutDate.year}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          title: Text(
            log.workoutName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              [
                log.programName,
                totalsText(log),
                if (duration != null) '$duration phút',
              ].join(' · '),
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LogDetailPage(id: log.id)),
          ),
        ),
      ),
    );
  }
}
