import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/number_format.dart';
import '../../../core/ui/gym_ui.dart';
import '../data/weight_models.dart';

/// Đường cân nặng theo ngày đo. Trục X theo khoảng cách ngày thật giữa [from] và [to]; ngày không
/// cân thì không có điểm (không chèn 0, không nội suy). Một bản ghi vẫn có chấm tròn.
/// Vẽ tay bằng CustomPainter kèm dải màu gradient bên dưới đường biểu đồ.
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.logs,
    required this.from,
    required this.to,
  });

  final List<WeightLog> logs;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall!;
    return Semantics(
      label:
          'Biểu đồ cân nặng ${logs.length} lần cân từ ${viDate(from)} đến ${viDate(to)}',
      child: SizedBox(
        height: 210,
        child: CustomPaint(
          size: Size.infinite,
          painter: _WeightPainter(
            logs: logs,
            from: from,
            to: to,
            line: GymColors.vibrantGreen,
            grid: scheme.outlineVariant.withValues(alpha: 0.65),
            dotInner: scheme.surface,
            textStyle: text.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter({
    required this.logs,
    required this.from,
    required this.to,
    required this.line,
    required this.grid,
    required this.dotInner,
    required this.textStyle,
  });

  final List<WeightLog> logs;
  final DateTime from;
  final DateTime to;
  final Color line;
  final Color grid;
  final Color dotInner;
  final TextStyle textStyle;

  static const _left = 44.0;
  static const _bottom = 24.0;
  static const _top = 10.0;
  static const _right = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final weights = logs.map((l) => l.weightKg);
    var minKg = weights.reduce(math.min);
    var maxKg = weights.reduce(math.max);
    // Biên tối thiểu 1 kg để đường gần phẳng không bị phóng to thành dao động lớn.
    final pad = math.max(0.5, (maxKg - minKg) * 0.15);
    minKg = (minKg - pad).floorToDouble();
    maxKg = (maxKg + pad).ceilToDouble();

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final kg in [minKg, (minKg + maxKg) / 2, maxKg]) {
      final y = _y(kg, minKg, maxKg, plot);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        formatViCompact(kg, maxDecimals: 1),
        Offset(plot.left - 8, y),
        alignRight: true,
      );
    }
    _label(
      canvas,
      viDayMonth(from),
      Offset(plot.left, plot.bottom + 13),
      alignLeft: true,
    );
    _label(
      canvas,
      viDayMonth(to),
      Offset(plot.right, plot.bottom + 13),
      alignRight: true,
    );

    final spanDays = math.max(1, to.difference(from).inDays);
    final points = [
      for (final l in logs)
        Offset(
          plot.left + plot.width * l.logDate.difference(from).inDays / spanDays,
          _y(l.weightKg, minKg, maxKg, plot),
        ),
    ];

    if (points.length > 1) {
      final areaPath = Path()..moveTo(points.first.dx, plot.bottom);
      for (final p in points) {
        areaPath.lineTo(p.dx, p.dy);
      }
      areaPath
        ..lineTo(points.last.dx, plot.bottom)
        ..close();

      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              line.withValues(alpha: 0.24),
              line.withValues(alpha: 0.0),
            ],
          ).createShader(plot),
      );

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.8,
      );
    }

    final outerDot = Paint()..color = line;
    final innerDot = Paint()..color = dotInner;
    for (final p in points) {
      canvas.drawCircle(p, 5.0, outerDot);
      canvas.drawCircle(p, 2.3, innerDot);
    }
  }

  double _y(double kg, double minKg, double maxKg, Rect plot) =>
      plot.bottom - plot.height * (kg - minKg) / (maxKg - minKg);

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool alignLeft = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? anchor.dx - tp.width
        : alignLeft
        ? anchor.dx
        : anchor.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_WeightPainter old) =>
      old.logs != logs ||
      old.from != from ||
      old.to != to ||
      old.line != line ||
      old.dotInner != dotInner;
}
