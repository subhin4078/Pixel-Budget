import 'package:flutter/foundation.dart';
import 'ledger_calculations.dart';
import 'ledger_repository.dart';
import 'ledger_validation.dart';
import 'models.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    selectedMonth = DateTime(now.year, now.month);
  }
  final LedgerRepository repository;
  final DateTime Function() _clock;
  List<LedgerEntry> _entries = [];
  bool loading = true;
  String? error;
  late DateTime selectedMonth;
  EntryType? recordFilter;

  DateTime get now => _clock();
  List<LedgerCategory> get categories => repository.categories;
  List<LedgerCategory> pickerCategories(EntryType type) {
    final defaults = LedgerCategory.pickerCategories(type);
    final categories = [
      for (final original in defaults)
        ...this.categories.where(
          (item) => item == original && item.type == type && item.visible,
        ),
      ...this.categories.where(
        (item) => item.type == type && item.visible && !defaults.contains(item),
      ),
    ];
    if (type == EntryType.income) return categories;
    final defaultOrder = {
      for (var i = 0; i < categories.length; i++) categories[i].name: i,
    };
    final savedOrder = repository.categoryOrder;
    return categories..sort((a, b) {
      final purposeOrder = a.purpose.index.compareTo(b.purpose.index);
      if (purposeOrder != 0) return purposeOrder;
      final order = (savedOrder[a.name] ?? defaultOrder[a.name]!).compareTo(
        savedOrder[b.name] ?? defaultOrder[b.name]!,
      );
      return order == 0
          ? defaultOrder[a.name]!.compareTo(defaultOrder[b.name]!)
          : order;
    });
  }

  Future<void> reorderExpenseCategory(
    LedgerCategory source,
    LedgerCategory target,
  ) async {
    if (source.type != EntryType.expense ||
        target.type != EntryType.expense ||
        source.purpose != target.purpose) {
      throw ArgumentError(
        'Expense categories can only move within the same purpose',
      );
    }
    if (source == target) return;
    final categories =
        pickerCategories(
          EntryType.expense,
        ).where((category) => category.purpose == source.purpose).toList();
    final from = categories.indexOf(source);
    final to = categories.indexOf(target);
    if (from < 0 || to < 0) return;
    categories.insert(to, categories.removeAt(from));
    await repository.saveCategoryOrder([
      for (final category in categories) category.name,
    ]);
    notifyListeners();
  }

  bool categoryNameExists(String label, EntryType type, {String? except}) =>
      categories.any(
        (category) =>
            category.name != except &&
            category.type == type &&
            categoryLabelKey(category.label) == categoryLabelKey(label),
      );

  bool categoryInUse(LedgerCategory category) =>
      _entries.any((entry) => entry.category == category);

  Future<LedgerCategory> saveCategory({
    LedgerCategory? original,
    required String label,
    required String icon,
    required int colorValue,
    required ExpensePurpose purpose,
    required EntryType type,
    required bool visible,
  }) async {
    final name = label.trim();
    if (name.isEmpty ||
        categoryNameExists(name, type, except: original?.name)) {
      throw const FormatException('種類名稱不能留空或重複。');
    }
    if (original != null && original.type != type && categoryInUse(original)) {
      throw const FormatException('已有帳目使用這個種類，不能更改收支類型。');
    }
    final category =
        original == null
            ? await repository.createCategory(
              label: name,
              icon: icon,
              colorValue: colorValue,
              purpose: purpose,
              type: type,
              visible: visible,
            )
            : original.copyWith(
              label: name,
              icon: icon,
              colorValue: colorValue,
              purpose: purpose,
              type: type,
              visible: visible,
            );
    if (original != null) await repository.updateCategory(category);
    final saved = category;
    _entries = [
      for (final entry in _entries)
        entry.category == saved
            ? LedgerEntry(
              id: entry.id,
              type: entry.type,
              amountMinor: entry.amountMinor,
              category: saved,
              occurredAt: entry.occurredAt,
              title: entry.title,
              note: entry.note,
              accountId: entry.accountId,
            )
            : entry,
    ];
    notifyListeners();
    return saved;
  }

  Iterable<LedgerEntry> forMonth(DateTime month) =>
      _entries.where((entry) => sameMonth(entry.occurredAt, month));
  LedgerSummary get currentMonthSummary => LedgerSummary(forMonth(now));
  LedgerSummary get allTimeSummary => LedgerSummary(_entries);
  LedgerSummary get selectedSummary => LedgerSummary(forMonth(selectedMonth));
  LedgerSummary get todaySummary =>
      LedgerSummary(_entries.where((entry) => sameDay(entry.occurredAt, now)));
  List<LedgerEntry> get visibleRecords => forMonth(selectedMonth)
      .where((entry) => recordFilter == null || entry.type == recordFilter)
      .toList(growable: false);

  LedgerCategory? lastCategory(EntryType type) {
    final remembered = repository.lastCategory(type);
    if (remembered != null) return remembered;
    for (final entry in _entries) {
      if (entry.type == type && entry.category.visible) return entry.category;
    }
    return null;
  }

  Future<void> rememberCategory(LedgerCategory category) =>
      repository.rememberCategory(category);

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await repository.open();
      _entries = await repository.readAll();
    } catch (_) {
      error = '暫時無法開啟帳本，請再試一次。';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectMonth(DateTime month) {
    selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void shiftMonth(int offset) =>
      selectMonth(DateTime(selectedMonth.year, selectedMonth.month + offset));

  void setFilter(EntryType? type) {
    recordFilter = type;
    notifyListeners();
  }

  Future<LedgerEntry> addEntry(
    LedgerEntry draft, {
    bool restored = false,
  }) async {
    _validate(draft);
    final saved = await repository.insert(
      draft.withId(null),
      restored: restored,
    );
    _entries = [..._entries, saved];
    _sort();
    notifyListeners();
    return saved;
  }

  Future<void> updateEntry(LedgerEntry entry) async {
    _validate(entry);
    await repository.update(entry);
    _entries = [
      for (final item in _entries) item.id == entry.id ? entry : item,
    ];
    _sort();
    notifyListeners();
  }

  Future<void> deleteEntry(LedgerEntry entry, {bool undoAdded = false}) async {
    await repository.delete(entry.id!, undoAdded: undoAdded);
    _entries = _entries.where((item) => item.id != entry.id).toList();
    notifyListeners();
  }

  void _validate(LedgerEntry entry) {
    final error = ledgerEntryValidationError(entry);
    if (error != null) throw FormatException(error);
  }

  void _sort() => _entries.sort((a, b) {
    final dateOrder = b.occurredAt.compareTo(a.occurredAt);
    return dateOrder == 0 ? b.id!.compareTo(a.id!) : dateOrder;
  });
}
