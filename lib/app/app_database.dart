import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'activity_log.dart';
import '../ledger/models.dart';

class AppDatabase {
  Future<Database>? _opening;
  late final activityLog = ActivityLog(open);

  Future<Database> open() =>
      _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });

  Future<Database> _open() async {
    final db = await openDatabase(
      path.join(await getDatabasesPath(), 'pixel_budget.db'),
      version: 7,
      onCreate: (db, version) async {
        await _createLedger(db);
        await _createTravel(db);
        await _createCategories(db);
        await _createCategoryOrder(db);
        await _createActivityLog(db);
        await _createEntryDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTravel(db);
        }
        if (oldVersion < 3) await _createExpenseCategories(db);
        if (oldVersion < 4) await _createCategoryOrder(db);
        if (oldVersion < 5) await _createActivityLog(db);
        if (oldVersion < 6) {
          await _createCategories(db);
          final existing = await db.query(
            'ledger_categories',
            columns: ['label'],
            where: 'type = ?',
            whereArgs: ['expense'],
          );
          final usedLabels = {
            for (final row in existing)
              categoryLabelKey(row['label'] as String),
          };
          final rows = await db.query('expense_categories', orderBy: 'id ASC');
          for (final row in rows) {
            final id = row['id'] as int;
            final label = resolveUniqueCategoryLabel(
              row['label'] as String,
              id: id,
              usedLabels: usedLabels,
            );
            usedLabels.add(categoryLabelKey(label));
            await db.insert('ledger_categories', {
              ...row,
              'label': label,
              'name': 'custom_$id',
              'type': 'expense',
              'visible': 1,
            });
          }
          await db.execute('DROP TABLE expense_categories');
        }
        if (oldVersion < 7) await _createEntryDefaults(db);
      },
    );
    try {
      await activityLog.load(db);
    } catch (_) {
      // Keep personal and travel books accessible even if activity log is damaged.
    }
    return db;
  }

  static String resolveUniqueCategoryLabel(
    String rawLabel, {
    required int id,
    required Set<String> usedLabels,
  }) {
    final base = rawLabel.trim().isEmpty ? '自訂種類' : rawLabel.trim();
    if (!usedLabels.contains(categoryLabelKey(base))) return base;
    var candidate = '$base ($id)';
    var suffix = 2;
    while (usedLabels.contains(categoryLabelKey(candidate))) {
      candidate = '$base ($id-$suffix)';
      suffix++;
    }
    return candidate;
  }

  static Future<void> _createEntryDefaults(Database db) => db.execute('''
    CREATE TABLE entry_defaults (
      type TEXT PRIMARY KEY CHECK(type IN ('expense', 'income')),
      category TEXT NOT NULL
    )
  ''');

  static Future<void> _createCategories(Database db) async {
    await db.execute('''
      CREATE TABLE ledger_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL COLLATE NOCASE,
        icon TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('expense', 'income')),
        color_value INTEGER NOT NULL,
        purpose TEXT NOT NULL CHECK(purpose IN ('self', 'others')),
        visible INTEGER NOT NULL CHECK(visible IN (0, 1)),
        UNIQUE(type, label)
      )
    ''');
    for (var i = 0; i < LedgerCategory.values.length; i++) {
      await db.insert('ledger_categories', {
        'id': -i - 1,
        ...LedgerCategory.values[i].toMap(),
      });
    }
  }

  static Future<void> _createActivityLog(Database db) => db.execute('''
    CREATE TABLE activity_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      kind TEXT NOT NULL,
      title TEXT NOT NULL,
      trip_name TEXT,
      amount TEXT,
      occurred_at TEXT NOT NULL
    )
  ''');

  static Future<void> _createLedger(Database db) async {
    await db.execute('''CREATE TABLE entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL CHECK(type IN ('expense', 'income')),
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      category TEXT NOT NULL,
      account_id TEXT NOT NULL,
      occurred_at TEXT NOT NULL,
      title TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT ''
    )''');
    await db.execute(
      'CREATE INDEX entries_date ON entries(occurred_at DESC, id DESC)',
    );
  }

  static Future<void> _createExpenseCategories(Database db) => db.execute('''
    CREATE TABLE expense_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT NOT NULL COLLATE NOCASE UNIQUE,
      icon TEXT NOT NULL,
      color_value INTEGER NOT NULL,
      purpose TEXT NOT NULL CHECK(purpose IN ('self', 'others'))
    )
  ''');

  static Future<void> _createCategoryOrder(Database db) => db.execute('''
    CREATE TABLE category_order (
      category TEXT PRIMARY KEY,
      position INTEGER NOT NULL
    )
  ''');

  static Future<void> _createTravel(Database db) async {
    await db.execute('''CREATE TABLE trips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created_at TEXT NOT NULL,
      data TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE trip_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id INTEGER NOT NULL,
      occurred_on TEXT NOT NULL,
      data TEXT NOT NULL
    )''');
    await db.execute(
      'CREATE INDEX trip_entries_trip ON trip_entries(trip_id, occurred_on DESC, id DESC)',
    );
  }
}
