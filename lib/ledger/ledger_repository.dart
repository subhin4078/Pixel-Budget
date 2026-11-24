import 'package:sqflite/sqflite.dart';
import '../app/activity_log.dart';
import '../app/app_database.dart';
import 'models.dart';

class LedgerRepository {
  LedgerRepository(this._database);
  final AppDatabase _database;
  AppDatabase get database => _database;
  List<LedgerCategory> _categories = List.of(LedgerCategory.values);
  Map<String, int> _categoryOrder = {};
  final Map<EntryType, String> _lastCategories = {};
  Map<String, int> get categoryOrder => Map.unmodifiable(_categoryOrder);
  List<LedgerCategory> get categories => List.unmodifiable(_categories);

  LedgerCategory? lastCategory(EntryType type) =>
      _categories
          .where(
            (category) =>
                category.name == _lastCategories[type] &&
                category.type == type &&
                category.visible,
          )
          .firstOrNull;

  Future<void> rememberCategory(LedgerCategory category) async {
    final previous = _lastCategories[category.type];
    _lastCategories[category.type] = category.name;
    try {
      final db = await _database.open();
      await _saveLastCategory(db, category);
    } catch (_) {
      if (_lastCategories[category.type] == category.name) {
        if (previous == null) {
          _lastCategories.remove(category.type);
        } else {
          _lastCategories[category.type] = previous;
        }
      }
      rethrow;
    }
  }

  static Future<void> _saveLastCategory(
    DatabaseExecutor db,
    LedgerCategory category,
  ) => db.insert('entry_defaults', {
    'type': category.type.name,
    'category': category.name,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<LedgerCategory>> readCategories(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query('ledger_categories', orderBy: 'id ASC');
    final categories = rows.map(LedgerCategory.fromMap).toList();
    categories.sort((a, b) => a.index.compareTo(b.index));
    return categories;
  }

  Future<void> open() async {
    final db = await _database.open();
    _categories = await readCategories(db);
    final defaults = await db.query('entry_defaults');
    _lastCategories
      ..clear()
      ..addEntries(
        defaults.map(
          (row) => MapEntry(
            EntryType.values.byName(row['type'] as String),
            row['category'] as String,
          ),
        ),
      );
    final order = await db.query('category_order');
    _categoryOrder = {
      for (final row in order)
        row['category'] as String: row['position'] as int,
    };
  }

  Future<void> saveCategoryOrder(List<String> names) async {
    final db = await _database.open();
    final batch = db.batch();
    for (var i = 0; i < names.length; i++) {
      batch.insert('category_order', {
        'category': names[i],
        'position': i,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _categoryOrder = {
      ..._categoryOrder,
      for (var i = 0; i < names.length; i++) names[i]: i,
    };
  }

  Future<List<LedgerEntry>> readAll() async {
    final db = await _database.open();
    final rows = await db.query(
      'entries',
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows
        .map((row) => LedgerEntry.fromMap(row, categories: _categories))
        .toList(growable: false);
  }

  Future<LedgerCategory> createCategory({
    required String label,
    required String icon,
    required int colorValue,
    required ExpensePurpose purpose,
    required EntryType type,
    required bool visible,
  }) async {
    final db = await _database.open();
    final category = await db.transaction(
      (txn) => insertCategory(
        txn,
        LedgerCategory.custom(
          id: 1,
          label: label,
          icon: icon,
          colorValue: colorValue,
          purpose: purpose,
          type: type,
          visible: visible,
        ),
      ),
    );
    _categories = [..._categories, category];
    return category;
  }

  static Future<LedgerCategory> insertCategory(
    DatabaseExecutor db,
    LedgerCategory source,
  ) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) + 1 AS id FROM ledger_categories WHERE id > 0',
    );
    final id = rows.single['id'] as int;
    final category = LedgerCategory.custom(
      id: id,
      label: source.label,
      icon: source.icon,
      colorValue: source.colorValue,
      purpose: source.purpose,
      type: source.type,
      visible: source.visible,
    );
    await db.insert('ledger_categories', {'id': id, ...category.toMap()});
    return category;
  }

  Future<void> updateCategory(LedgerCategory category) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      final incompatible = await txn.query(
        'entries',
        columns: ['id'],
        where: 'category = ? AND type != ?',
        whereArgs: [category.name, category.type.name],
        limit: 1,
      );
      if (incompatible.isNotEmpty) {
        throw const FormatException('已有帳目使用這個種類，不能更改收支類型。');
      }
      await txn.update(
        'ledger_categories',
        category.toMap(),
        where: 'name = ?',
        whereArgs: [category.name],
      );
    });
    _categories = [
      for (final item in _categories) item == category ? category : item,
    ];
  }

  Future<LedgerEntry> insert(LedgerEntry entry, {bool restored = false}) async {
    final id = await _database.activityLog.write(
      (txn) async {
        final id = await txn.insert('entries', entry.toMap());
        if (!restored) await _saveLastCategory(txn, entry.category);
        return id;
      },
      (_) => _event(
        restored ? ActivityAction.restored : ActivityAction.added,
        entry,
      ),
    );
    if (!restored) _lastCategories[entry.type] = entry.category.name;
    return entry.withId(id);
  }

  Future<void> update(LedgerEntry entry) async {
    final updated = await _database.activityLog.write((txn) async {
      final updated = await txn.update(
        'entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (updated > 0) await _saveLastCategory(txn, entry.category);
      return updated;
    }, (_) => _event(ActivityAction.edited, entry));
    if (updated > 0) _lastCategories[entry.type] = entry.category.name;
  }

  Future<void> delete(int id, {bool undoAdded = false}) async {
    await _database.activityLog.write(
      (txn) => txn.delete('entries', where: 'id = ?', whereArgs: [id]),
      (txn) async {
        final rows = await txn.query(
          'entries',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return null;
        final entry = LedgerEntry.fromMap(rows.single, categories: _categories);
        return _event(
          undoAdded ? ActivityAction.undone : ActivityAction.deleted,
          entry,
        );
      },
    );
  }

  ActivityEvent _event(ActivityAction action, LedgerEntry entry) =>
      ActivityEvent(
        action: action,
        kind:
            entry.type == EntryType.income
                ? ActivityKind.income
                : ActivityKind.expense,
        title: entry.title.trim().isEmpty ? entry.category.label : entry.title,
        amount: money(entry.amountMinor),
      );
}
