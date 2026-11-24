import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ledger/ledger_controller.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/ledger_charts.dart';
import '../../shared/widgets/scene_page.dart';
import '../entry/entry_sheet.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  EntryType _type = EntryType.expense;

  Future<void> _pickMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.controller.selectedMonth,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '選擇月份',
    );
    if (date != null && mounted) widget.controller.selectMonth(date);
  }

  Future<void> _showCategory(
    LedgerCategory category,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (context) => ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final month = widget.controller.selectedMonth;
            final records =
                widget.controller
                    .forMonth(month)
                    .where((entry) => entry.category == category)
                    .toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .7,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CategoryBadge(category, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              category.label,
                              style: const TextStyle(fontSize: 19),
                            ),
                          ),
                          Text(
                            '${month.year}年${month.month}月 · ${records.length} 筆',
                            style: const TextStyle(color: Palette.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final entry in records)
                              EntryTile(
                                entry,
                                showDate: true,
                                onTap:
                                    () => showEntrySheet(
                                      context,
                                      widget.controller,
                                      entry: entry,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
  );

  @override
  Widget build(BuildContext context) {
    final amounts = <LedgerCategory, int>{};
    for (final entry in widget.controller.forMonth(
      widget.controller.selectedMonth,
    )) {
      if (entry.type == _type) {
        amounts.update(
          entry.category,
          (amount) => amount + entry.amountMinor,
          ifAbsent: () => entry.amountMinor,
        );
      }
    }
    final groupExpenses = _type == EntryType.expense;
    final sorted = orderedCategoryAmounts(
      amounts,
      groupExpenses: groupExpenses,
    );
    final total = amounts.values.fold<int>(0, (sum, amount) => sum + amount);
    final legend =
        groupExpenses ? expensePurposeShares(amounts) : categoryShares(amounts);
    final maxAmount = amounts.values.fold<int>(
      1,
      (largest, amount) => amount > largest ? amount : largest,
    );
    final label = _type == EntryType.expense ? '支出' : '收入';
    return ScenePage(
      kind: SceneKind.statistics,
      title: '統計',
      subtitle: '收支分佈，一目了然',
      contentTop: 150,
      body:
          (context, s) => [
            MonthSelector(
              month: widget.controller.selectedMonth,
              onShift: widget.controller.shiftMonth,
              onTapMonth: _pickMonth,
            ),
            const SizedBox(height: 10),
            TypeSwitch(
              labels: const ['支出', '收入'],
              selected: _type == EntryType.expense ? 0 : 1,
              onSelected:
                  (index) => setState(() => _type = EntryType.values[index]),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              opacity: .86,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ringSize =
                      groupExpenses
                          ? math.min(196.0, constraints.maxWidth * .6)
                          : math.min(150.0, constraints.maxWidth * .44);
                  final ring = CategoryRing(
                    amounts: amounts,
                    size: ringSize,
                    groupExpenses: groupExpenses,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: MoneyLabel(
                            total,
                            size: 18,
                            align: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '總$label',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.secondary,
                          ),
                        ),
                      ],
                    ),
                  );
                  final legendWidget = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (total == 0)
                        Text(
                          '這個月還沒有$label',
                          style: const TextStyle(
                            color: Palette.secondary,
                            fontSize: 14,
                          ),
                        ),
                      for (final item in legend)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                shareText(item.amount, total),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Palette.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (groupExpenses)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            '外環：用途\n內環：支出種類',
                            style: TextStyle(
                              fontSize: 11,
                              color: Palette.muted,
                            ),
                          ),
                        ),
                    ],
                  );
                  if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                      children: [
                        ring,
                        const SizedBox(height: 20),
                        legendWidget,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      ring,
                      const SizedBox(width: 16),
                      Expanded(child: legendWidget),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (sorted.isNotEmpty)
              GlassCard(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                opacity: .86,
                child: Column(
                  children: [
                    for (var i = 0; i < sorted.length; i++) ...[
                      if (groupExpenses &&
                          (i == 0 ||
                              sorted[i].key.purpose !=
                                  sorted[i - 1].key.purpose))
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            2,
                            i == 0 ? 10 : 20,
                            2,
                            4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              sorted[i].key.purpose.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    legend[sorted[i].key.purpose.index].color,
                              ),
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: () => _showCategory(sorted[i].key),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 11,
                            horizontal: 2,
                          ),
                          child: Row(
                            children: [
                              CategoryBadge(sorted[i].key, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            sorted[i].key.label,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          shareText(sorted[i].value, total),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Palette.muted,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        MoneyLabel(
                                          sorted[i].value,
                                          size: 15,
                                          align: TextAlign.right,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: LinearProgressIndicator(
                                        value: sorted[i].value / maxAmount,
                                        minHeight: 6,
                                        color: Color(sorted[i].key.colorValue),
                                        backgroundColor: Palette.line
                                            .withValues(alpha: .2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < sorted.length - 1 &&
                          (!groupExpenses ||
                              sorted[i].key.purpose ==
                                  sorted[i + 1].key.purpose))
                        const Divider(height: 1, indent: 54),
                    ],
                  ],
                ),
              ),
          ],
    );
  }
}
