import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ledger/models.dart';
import '../theme/app_theme.dart';

class CategoryShare {
  const CategoryShare(this.label, this.amount, this.color);
  final String label;
  final int amount;
  final Color color;
}

List<MapEntry<LedgerCategory, int>> orderedCategoryAmounts(
  Map<LedgerCategory, int> amounts, {
  bool groupExpenses = false,
}) =>
    amounts.entries.where((item) => item.value > 0).toList()..sort((a, b) {
      if (groupExpenses) {
        final purposeOrder = a.key.purpose.index.compareTo(b.key.purpose.index);
        if (purposeOrder != 0) return purposeOrder;
      }
      final order = b.value.compareTo(a.value);
      return order == 0 ? a.key.index.compareTo(b.key.index) : order;
    });

List<CategoryShare> categoryShares(
  Map<LedgerCategory, int> amounts, {
  bool groupExpenses = false,
}) {
  final sorted = orderedCategoryAmounts(amounts, groupExpenses: groupExpenses);
  if (groupExpenses) {
    return [
      for (final item in sorted)
        CategoryShare(item.key.label, item.value, Color(item.key.colorValue)),
    ];
  }
  final result = [
    for (final item in sorted.take(sorted.length <= 5 ? 5 : 4))
      CategoryShare(item.key.label, item.value, Color(item.key.colorValue)),
  ];
  if (sorted.length > 5) {
    result.add(
      CategoryShare(
        '其他分類',
        sorted.skip(4).fold<int>(0, (sum, item) => sum + item.value),
        Palette.balance,
      ),
    );
  }
  return result;
}

List<CategoryShare> expensePurposeShares(Map<LedgerCategory, int> amounts) {
  final usedColors = {
    for (final item in amounts.entries)
      if (item.value > 0) item.key.colorValue,
  };
  Color distinctColor(int preferred, int alternate) {
    if (usedColors.add(preferred)) return Color(preferred);
    // Imported categories can supply colors outside the built-in palette.
    var value = alternate;
    while (!usedColors.add(value)) {
      value = 0xFF000000 | ((value + 0x002B452F) & 0xFFFFFF);
    }
    return Color(value);
  }

  return [
    for (final purpose in ExpensePurpose.values)
      CategoryShare(
        purpose.label,
        amounts.entries
            .where((item) => item.key.purpose == purpose)
            .fold<int>(0, (sum, item) => sum + item.value),
        switch (purpose) {
          ExpensePurpose.self => distinctColor(0xFF4E90FF, 0xFF34D6EE),
          ExpensePurpose.others => distinctColor(0xFFD8F34D, 0xFFFF8651),
        },
      ),
  ];
}

String shareText(int amount, int total) {
  if (total == 0) return '0%';
  final value = (amount * 100 / total)
      .toStringAsFixed(1)
      .replaceFirst(RegExp(r'\.0$'), '');
  return '$value%';
}

class CategoryRing extends StatelessWidget {
  const CategoryRing({
    super.key,
    required this.amounts,
    required this.size,
    required this.center,
    this.groupExpenses = false,
  });
  final Map<LedgerCategory, int> amounts;
  final double size;
  final Widget center;
  final bool groupExpenses;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _RingPainter(amounts, groupExpenses)),
        ),
        Padding(
          padding: EdgeInsets.all(size * (groupExpenses ? .27 : .2)),
          child: center,
        ),
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.amounts, this.groupExpenses);
  final Map<LedgerCategory, int> amounts;
  final bool groupExpenses;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.stroke;
    final total = amounts.values.fold<int>(0, (sum, amount) => sum + amount);
    void drawRing(
      double diameter,
      double thickness,
      List<CategoryShare> shares,
    ) {
      final radius = (diameter - thickness) / 2;
      paint.strokeWidth = thickness;
      canvas.drawCircle(
        center,
        radius,
        paint..color = Palette.line.withValues(alpha: .45),
      );
      if (total == 0) return;
      final slices = shares.where((item) => item.amount > 0).toList();
      var angle = -math.pi / 2;
      for (final item in slices) {
        final sweep = item.amount / total * 2 * math.pi;
        final gap = slices.length == 1 ? 0.0 : math.min(.03, sweep * .1);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          angle + gap / 2,
          sweep - gap,
          false,
          paint..color = item.color,
        );
        angle += sweep;
      }
    }

    final innerDiameter = size.shortestSide * (groupExpenses ? .76 : 1);
    drawRing(
      innerDiameter,
      innerDiameter * .14,
      categoryShares(amounts, groupExpenses: groupExpenses),
    );
    if (groupExpenses) {
      drawRing(
        size.shortestSide,
        size.shortestSide * .065,
        expensePurposeShares(amounts),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.amounts != amounts ||
      oldDelegate.groupExpenses != groupExpenses;
}
