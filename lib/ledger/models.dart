enum EntryType { expense, income }

String categoryLabelKey(String label) => label.trim().toLowerCase();

enum ExpensePurpose {
  self('自用', 0xFFC6B5EE),
  others('為他人', 0xFF8ADBC8);

  const ExpensePurpose(this.label, this.colorValue);
  final String label;
  final int colorValue;
}

class LedgerCategory {
  const LedgerCategory._(
    this.name,
    this.label,
    this.icon,
    this.type,
    this.colorValue, {
    this.purpose = ExpensePurpose.self,
    this.customId,
    this.visible = true,
  });

  static const dining = LedgerCategory._(
    'dining',
    '食物',
    'dining',
    EntryType.expense,
    0xFFF28BB8,
  );
  static const transport = LedgerCategory._(
    'transport',
    '交通',
    'transport',
    EntryType.expense,
    0xFF84B9ED,
  );
  static const shopping = LedgerCategory._(
    'shopping',
    '網上購物',
    'shopping',
    EntryType.expense,
    0xFFB49AEE,
  );
  // Retained for existing records and CSV imports; omitted from the picker.
  static const entertainment = LedgerCategory._(
    'entertainment',
    '娛樂',
    'entertainment',
    EntryType.expense,
    0xFFF0C272,
    visible: false,
  );
  static const other = LedgerCategory._(
    'other',
    '其他',
    'other',
    EntryType.expense,
    0xFF83CFC3,
    visible: false,
  );
  static const salary = LedgerCategory._(
    'salary',
    '薪水',
    'income',
    EntryType.income,
    0xFF8ADBC8,
  );
  static const otherIncome = LedgerCategory._(
    'otherIncome',
    '其他',
    'salary',
    EntryType.income,
    0xFFD9CBFF,
  );
  static const fitness = LedgerCategory._(
    'fitness',
    '健身',
    'fitness',
    EntryType.expense,
    0xFFA2CF80,
  );
  static const bills = LedgerCategory._(
    'bills',
    '繳費',
    'bills',
    EntryType.expense,
    0xFFB5ACE8,
  );
  static const treat = LedgerCategory._(
    'treat',
    '請食飯',
    'treat',
    EntryType.expense,
    0xFFF0C272,
    purpose: ExpensePurpose.others,
  );
  static const medicine = LedgerCategory._(
    'medicine',
    '藥',
    'medicine',
    EntryType.expense,
    0xFFEF9EA8,
  );
  static const household = LedgerCategory._(
    'household',
    '家用',
    'household',
    EntryType.expense,
    0xFFF0BA8F,
    purpose: ExpensePurpose.others,
  );
  static const supplies = LedgerCategory._(
    'supplies',
    '家裡物資',
    'supplies',
    EntryType.expense,
    0xFF83CFC3,
    purpose: ExpensePurpose.others,
  );
  static const snacks = LedgerCategory._(
    'snacks',
    '零食',
    'snacks',
    EntryType.expense,
    0xFFF3B5CF,
  );
  static const clothes = LedgerCategory._(
    'clothes',
    '衣服',
    'clothes',
    EntryType.expense,
    0xFFB59CEA,
  );
  static const gameCredit = LedgerCategory._(
    'gameCredit',
    '課金',
    'game-credit',
    EntryType.expense,
    0xFF97B6EF,
  );
  static const travel = LedgerCategory._(
    'travel',
    '旅行',
    'travel',
    EntryType.expense,
    0xFFC4AAE5,
  );
  static const investment = LedgerCategory._(
    'investment',
    '理財',
    'investment',
    EntryType.income,
    0xFF8ECAC8,
  );
  static const partTime = LedgerCategory._(
    'partTime',
    '兼職',
    'gift',
    EntryType.income,
    0xFFF0BA8F,
  );
  static const gift = LedgerCategory._(
    'gift',
    '禮金',
    'part-time',
    EntryType.income,
    0xFFEDABC9,
  );

  static const values = [
    dining,
    transport,
    shopping,
    entertainment,
    other,
    salary,
    otherIncome,
    fitness,
    bills,
    treat,
    medicine,
    household,
    supplies,
    snacks,
    clothes,
    gameCredit,
    travel,
    investment,
    partTime,
    gift,
  ];

  factory LedgerCategory.custom({
    required int id,
    required String label,
    required String icon,
    required int colorValue,
    required ExpensePurpose purpose,
    EntryType type = EntryType.expense,
    bool visible = true,
  }) => LedgerCategory._(
    'custom_$id',
    label,
    icon,
    type,
    colorValue,
    purpose: type == EntryType.income ? ExpensePurpose.self : purpose,
    customId: id,
    visible: visible,
  );

  factory LedgerCategory.fromMap(Map<String, Object?> row) => LedgerCategory._(
    row['name'] as String,
    row['label'] as String,
    row['icon'] as String,
    EntryType.values.byName(row['type'] as String),
    row['color_value'] as int,
    purpose: ExpensePurpose.values.byName(row['purpose'] as String),
    customId: (row['id'] as int) > 0 ? row['id'] as int : null,
    visible: row['visible'] == 1,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'label': label,
    'icon': icon,
    'type': type.name,
    'color_value': colorValue,
    'purpose': purpose.name,
    'visible': visible ? 1 : 0,
  };

  LedgerCategory copyWith({
    String? label,
    String? icon,
    EntryType? type,
    int? colorValue,
    ExpensePurpose? purpose,
    bool? visible,
  }) => LedgerCategory._(
    name,
    label ?? this.label,
    icon ?? this.icon,
    type ?? this.type,
    colorValue ?? this.colorValue,
    purpose:
        (type ?? this.type) == EntryType.income
            ? ExpensePurpose.self
            : purpose ?? this.purpose,
    customId: customId,
    visible: visible ?? this.visible,
  );

  final String name;
  final String label;
  final String icon;
  final EntryType type;
  final int colorValue;
  final ExpensePurpose purpose;
  final int? customId;
  final bool visible;
  int get index =>
      customId == null ? values.indexOf(this) : values.length + customId!;

  @override
  bool operator ==(Object other) =>
      other is LedgerCategory && name == other.name;

  @override
  int get hashCode => name.hashCode;

  static List<LedgerCategory> forType(EntryType type) =>
      values.where((category) => category.type == type).toList(growable: false);

  static List<LedgerCategory> pickerCategories(EntryType type) =>
      type == EntryType.expense
          ? [
            fitness,
            bills,
            treat,
            medicine,
            shopping,
            household,
            supplies,
            transport,
            dining,
            snacks,
            clothes,
            gameCredit,
            travel,
          ]
          : [salary, investment, partTime, gift, otherIncome];
}

class LedgerEntry {
  const LedgerEntry({
    this.id,
    required this.type,
    required this.amountMinor,
    required this.category,
    required this.occurredAt,
    required this.title,
    this.note = '',
    this.accountId = 'cash',
  });

  final int? id;
  final EntryType type;
  final int amountMinor;
  final LedgerCategory category;
  final DateTime occurredAt;
  final String title;
  final String note;
  final String accountId;

  LedgerEntry withId(int? value) => LedgerEntry(
    id: value,
    type: type,
    amountMinor: amountMinor,
    category: category,
    occurredAt: occurredAt,
    title: title,
    note: note,
    accountId: accountId,
  );

  Map<String, Object?> toMap() => {
    'type': type.name,
    'amount_minor': amountMinor,
    'category': category.name,
    'account_id': accountId,
    'occurred_at': occurredAt.toIso8601String(),
    'title': title,
    'note': note,
  };

  factory LedgerEntry.fromMap(
    Map<String, Object?> row, {
    Iterable<LedgerCategory> categories = LedgerCategory.values,
  }) {
    final type = EntryType.values.byName(row['type'] as String);
    final categoryName = row['category'] as String;
    final fallback =
        type == EntryType.income
            ? LedgerCategory.otherIncome
            : LedgerCategory.other;
    return LedgerEntry(
      id: row['id'] as int,
      type: type,
      amountMinor: row['amount_minor'] as int,
      category: categories.firstWhere(
        (category) => category.name == categoryName,
        orElse:
            () => categories.firstWhere(
              (category) => category.name == fallback.name,
              orElse: () => fallback,
            ),
      ),
      accountId: row['account_id'] as String,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      title: row['title'] as String,
      note: row['note'] as String,
    );
  }
}

const maxAmountMinor = 900000000000099;

bool isValidAmountMinor(int value, {bool allowZero = false}) =>
    value >= (allowZero ? 0 : 1) && value <= maxAmountMinor;

int? parseAmountMinor(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d+(?:\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final major = int.tryParse(parts.first);
  if (major == null || major > maxAmountMinor ~/ 100) return null;
  final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return major * 100 + int.parse(fraction);
}

String money(int minor, {bool signed = false, String symbol = r'$'}) {
  final absolute = minor.abs();
  final major = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final cents = absolute % 100;
  final fraction = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  final sign = minor < 0 ? '−' : (signed && minor > 0 ? '+' : '');
  return '$sign$symbol$major$fraction';
}

String amountInputText(int minor) {
  final cents = minor % 100;
  return cents == 0
      ? '${minor ~/ 100}'
      : '${minor ~/ 100}.${cents.toString().padLeft(2, '0')}'.replaceFirst(
        RegExp(r'0$'),
        '',
      );
}

const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

String dayLabel(DateTime day, DateTime now) {
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final prefix =
      sameDay(day, now)
          ? '今天 · '
          : sameDay(day, yesterday)
          ? '昨天 · '
          : '';
  return '$prefix${day.month}月${day.day}日 週${weekdayLabels[day.weekday - 1]}';
}

String twoDigits(int number) => number.toString().padLeft(2, '0');
String shortDate(DateTime date) => '${date.month}/${twoDigits(date.day)}';
String clockText(DateTime date) =>
    '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
String dateKey(DateTime date) =>
    '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
