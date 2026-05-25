import 'package:flutter/material.dart';

import '../../controllers/dashboard_controller.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.buckets,
    required this.symbol,
    this.height = 160,
  });

  final List<TrendBucket> buckets;
  final String symbol;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold<double>(0, (max, bucket) {
      final value = bucket.incomes > bucket.expenses
          ? bucket.incomes
          : bucket.expenses;
      return value > max ? value : max;
    });

    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrendChartPainter(
          buckets: buckets,
          maxValue: maxValue,
          incomeColor: Colors.green.shade400,
          expenseColor: Colors.red.shade400,
          axisColor: theme.dividerColor,
          labelStyle:
              theme.textTheme.labelSmall ??
              const TextStyle(fontSize: 10),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.buckets,
    required this.maxValue,
    required this.incomeColor,
    required this.expenseColor,
    required this.axisColor,
    required this.labelStyle,
  });

  final List<TrendBucket> buckets;
  final double maxValue;
  final Color incomeColor;
  final Color expenseColor;
  final Color axisColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const bottomReservedForLabels = 18.0;
    final chartHeight = size.height - bottomReservedForLabels;
    final n = buckets.length;
    final slotWidth = size.width / n;
    final groupWidth = slotWidth * 0.7;
    final barWidth = groupWidth / 2;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    final effectiveMax = maxValue <= 0 ? 1.0 : maxValue;

    // Decide label step: print at most ~6 labels.
    final labelStep = (n / 6).ceil().clamp(1, n);

    for (var i = 0; i < n; i++) {
      final bucket = buckets[i];
      final slotLeft = i * slotWidth;
      final groupLeft = slotLeft + (slotWidth - groupWidth) / 2;

      final incomeHeight = (bucket.incomes / effectiveMax) * chartHeight;
      final expenseHeight = (bucket.expenses / effectiveMax) * chartHeight;

      final incomePaint = Paint()..color = incomeColor;
      final expensePaint = Paint()..color = expenseColor;

      final incomeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          groupLeft,
          chartHeight - incomeHeight,
          barWidth,
          incomeHeight,
        ),
        const Radius.circular(3),
      );
      final expenseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          groupLeft + barWidth,
          chartHeight - expenseHeight,
          barWidth,
          expenseHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(incomeRect, incomePaint);
      canvas.drawRRect(expenseRect, expensePaint);

      if (i % labelStep == 0 || i == n - 1) {
        final tp = TextPainter(
          text: TextSpan(text: bucket.label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: slotWidth);
        tp.paint(
          canvas,
          Offset(slotLeft + (slotWidth - tp.width) / 2, chartHeight + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) {
    return old.buckets != buckets || old.maxValue != maxValue;
  }
}
