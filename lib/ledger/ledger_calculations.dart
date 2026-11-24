import 'models.dart';

class LedgerSummary {
  LedgerSummary(Iterable<LedgerEntry> entries) {
    for (final entry in entries) {
      if (entry.type == EntryType.expense) {
        expense += entry.amountMinor;
      } else {
        income += entry.amountMinor;
      }
    }
  }

  int expense = 0;
  int income = 0;
  int get balance => income - expense;
}

Map<DateTime, List<LedgerEntry>> groupByDay(Iterable<LedgerEntry> entries) {
  final groups = <DateTime, List<LedgerEntry>>{};
  for (final entry in entries) {
    final day = DateTime(
      entry.occurredAt.year,
      entry.occurredAt.month,
      entry.occurredAt.day,
    );
    groups.putIfAbsent(day, () => []).add(entry);
  }
  return groups;
}
