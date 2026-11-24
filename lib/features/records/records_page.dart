import 'package:flutter/material.dart';
import '../../ledger/ledger_calculations.dart';
import '../../ledger/ledger_controller.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/scene_page.dart';
import '../entry/entry_sheet.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.controller, required this.onAdd});
  final LedgerController controller;
  final VoidCallback onAdd;

  Future<void> _pickMonth(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: controller.selectedMonth,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '選擇月份',
    );
    if (date != null) controller.selectMonth(date);
  }

  @override
  Widget build(BuildContext context) {
    final summary = controller.selectedSummary;
    final groups = groupByDay(controller.visibleRecords);
    return ScenePage(
      kind: SceneKind.records,
      title: '詳細',
      subtitle: '點按修改，左滑刪除',
      contentTop: 150,
      body:
          (context, s) => [
            MonthSelector(
              month: controller.selectedMonth,
              onShift: controller.shiftMonth,
              onTapMonth: () => _pickMonth(context),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: StatLine(
                      label: '支出',
                      value: money(summary.expense),
                      color: Palette.expense,
                    ),
                  ),
                  Expanded(
                    child: StatLine(
                      label: '收入',
                      value: money(summary.income),
                      color: Palette.income,
                      align: CrossAxisAlignment.center,
                    ),
                  ),
                  Expanded(
                    child: StatLine(
                      label: '結餘',
                      value: money(summary.balance, signed: true),
                      color: Palette.balance,
                      align: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TypeSwitch(
              labels: const ['全部', '支出', '收入'],
              selected: switch (controller.recordFilter) {
                null => 0,
                EntryType.expense => 1,
                EntryType.income => 2,
              },
              onSelected:
                  (index) => controller.setFilter(
                    [null, EntryType.expense, EntryType.income][index],
                  ),
            ),
            const SizedBox(height: 10),
            if (groups.isEmpty)
              GlassCard(
                child: EmptyNotice(
                  '這個月還沒有記錄。',
                  icon: 'records',
                  action: '記一筆',
                  onAction: onAdd,
                ),
              )
            else
              for (final group in groups.entries) ...[
                _DayCard(
                  day: group.key,
                  entries: group.value,
                  controller: controller,
                ),
                const SizedBox(height: 10),
              ],
          ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.entries,
    required this.controller,
  });
  final DateTime day;
  final List<LedgerEntry> entries;
  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final summary = LedgerSummary(entries);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel(day, controller.now),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Palette.secondary,
                    ),
                  ),
                ),
                if (summary.income > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      '收 ${money(summary.income)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.income,
                      ),
                    ),
                  ),
                if (summary.expense > 0)
                  Text(
                    '支 ${money(summary.expense)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Palette.expense,
                    ),
                  ),
              ],
            ),
          ),
          for (final entry in entries)
            Dismissible(
              key: ValueKey('entry-${entry.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8456F).withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const CuteIcon('delete', size: 26),
              ),
              confirmDismiss: (_) async {
                await deleteLedgerEntryWithUndo(
                  ScaffoldMessenger.of(context),
                  controller,
                  entry,
                );
                // The controller removes the row on success. Otherwise snap back.
                return false;
              },
              child: EntryTile(
                entry,
                onTap: () => showEntrySheet(context, controller, entry: entry),
              ),
            ),
        ],
      ),
    );
  }
}
