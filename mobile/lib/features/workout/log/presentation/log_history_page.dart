import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
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

  /// Mỗi lần tải lại từ đầu tăng lên; phản hồi của lần tải cũ bị bỏ qua.
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
    // Backend giới hạn 366 ngày mỗi lần lọc.
    if (picked.end.difference(picked.start).inDays + 1 > 366) {
      if (mounted) showSnack(context, 'Chọn khoảng tối đa 366 ngày');
      return;
    }
    _range = picked;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Có log mới ở màn khác → tải lại.
    ref.listen(logHistoryVersionProvider, (_, _) => _reload());
    final range = _range;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử tập'),
        actions: [
          IconButton(
            key: const Key('history-filter'),
            tooltip: 'Lọc theo ngày',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      body: Column(
        children: [
          if (range != null)
            ListTile(
              dense: true,
              title: Text(
                '${viDate(range.start)} – ${viDate(range.end)}',
                key: const Key('history-range'),
              ),
              trailing: TextButton(
                key: const Key('history-clear'),
                onPressed: () {
                  _range = null;
                  _reload();
                },
                child: const Text('Bỏ lọc'),
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
        icon: Icons.history,
        text: _range == null
            ? 'Chưa có buổi tập nào được ghi. Mở một buổi trong "Lịch tập" và bấm "Bắt đầu tập".'
            : 'Không có buổi tập nào trong khoảng ngày này.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
            return ListTile(
              title: Text(_error.toString()),
              trailing: TextButton(
                onPressed: _loadMore,
                child: const Text('Thử lại'),
              ),
            );
          }
          if (_hasNext) {
            return Center(
              child: TextButton(
                key: const Key('history-more'),
                onPressed: _loadMore,
                child: const Text('Tải thêm'),
              ),
            );
          }
          return const SizedBox(height: 24);
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
    final duration = log.durationMinutes;
    return ListTile(
      key: Key('history-${log.id}'),
      leading: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(viDayMonth(log.workoutDate)),
            Text(
              '${log.workoutDate.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      title: Text(log.workoutName),
      subtitle: Text(
        [
          log.programName,
          totalsText(log),
          if (duration != null) '$duration phút',
        ].join(' · '),
      ),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LogDetailPage(id: log.id))),
    );
  }
}
