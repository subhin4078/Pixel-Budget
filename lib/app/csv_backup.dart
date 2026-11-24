import 'dart:convert';
import 'dart:typed_data';
import '../ledger/category_icons.dart';
import '../ledger/models.dart';
import '../ledger/ledger_validation.dart';
import '../travel/travel_models.dart';
import '../travel/travel_validation.dart';

class CsvBackup {
  const CsvBackup({
    required this.categories,
    required this.entries,
    required this.trips,
    required this.tripEntries,
  });
  final List<LedgerCategory> categories;
  final List<LedgerEntry> entries;
  final List<Trip> trips;
  final List<TripEntry> tripEntries;
}

const csvBackupColumns = [
  '資料類型',
  '識別碼',
  '旅程識別碼',
  '記錄識別碼',
  '日期',
  '收支類型',
  '名稱',
  '金額',
  '種類識別碼',
  '種類',
  '用途',
  '圖示',
  '顏色',
  '帳戶',
  '備註',
  '主貨幣',
  '貨幣識別碼',
  '貨幣',
  '匯率',
  '成員識別碼',
  '成員姓名',
  '動物圖示',
  '付款人識別碼',
  '已結清',
  '顯示',
  '貨幣符號',
];

// CSV quoting does not prevent spreadsheet formulas; escape text reversibly.
final _formulaPrefix = RegExp(r'^[\t\r\n ]*[=+\-@]');

String _csvCell(String value) {
  if (value.startsWith("'") || _formulaPrefix.hasMatch(value)) {
    value = "'$value";
  }
  return '"${value.replaceAll('"', '""')}"';
}

String _csvText(String value) {
  if (value.startsWith("'")) {
    final rest = value.substring(1);
    if (rest.startsWith("'") || _formulaPrefix.hasMatch(rest)) return rest;
  }
  return value;
}

String _decimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

Uint8List encodeCsvBackup(CsvBackup backup) {
  final output = StringBuffer('\uFEFF');
  output.write('${csvBackupColumns.map(_csvCell).join(',')}\r\n');
  void row(Map<String, String> values) {
    output.write(
      csvBackupColumns
          .map((column) => _csvCell(values[column] ?? ''))
          .join(','),
    );
    output.write('\r\n');
  }

  for (final category in backup.categories) {
    row({
      '資料類型': '種類',
      '識別碼': category.name,
      '名稱': category.label,
      '收支類型': category.type == EntryType.expense ? '支出' : '收入',
      '用途': category.type == EntryType.expense ? category.purpose.label : '',
      '圖示': category.icon,
      '顏色': category.colorValue.toRadixString(16).padLeft(8, '0').toUpperCase(),
      '顯示': category.visible ? '是' : '否',
    });
  }
  for (final entry in backup.entries) {
    row({
      '資料類型': '個人帳目',
      '識別碼': '${entry.id ?? ''}',
      '日期': entry.occurredAt.toIso8601String(),
      '收支類型': entry.type == EntryType.expense ? '支出' : '收入',
      '名稱': entry.title,
      '金額': _decimal(entry.amountMinor),
      '種類識別碼': entry.category.name,
      '種類': entry.category.label,
      '用途': entry.type == EntryType.expense ? entry.category.purpose.label : '',
      '帳戶': entry.accountId,
      '備註': entry.note,
    });
  }
  for (final trip in backup.trips) {
    final tripId = '${trip.id}';
    row({
      '資料類型': '旅程',
      '識別碼': tripId,
      '名稱': trip.name,
      '日期': trip.createdAt.toIso8601String(),
      '主貨幣': trip.baseCurrency,
      '貨幣符號': trip.baseSymbol ?? '',
    });
    for (final member in trip.members) {
      row({
        '資料類型': '同行成員',
        '旅程識別碼': tripId,
        '成員識別碼': '${member.id}',
        '成員姓名': member.name,
        '動物圖示': member.animalIcon ?? '',
      });
    }
    for (final currency in trip.allCurrencies) {
      row({
        '資料類型': '旅程貨幣',
        '旅程識別碼': tripId,
        '貨幣識別碼': '${currency.id}',
        '貨幣': currency.label,
        '匯率': currency.rate?.toString() ?? '',
        '貨幣符號': currency.isCustom ? currency.symbol : '',
      });
    }
  }
  for (final entry in backup.tripEntries) {
    row({
      '資料類型': '旅程帳目',
      '識別碼': '${entry.id}',
      '旅程識別碼': '${entry.tripId}',
      '日期': dateKey(entry.date),
      '名稱': entry.title,
      '收支類型': entry.isRepayment ? '還款' : '支出',
      '金額': _decimal(entry.amountMinor),
      '付款人識別碼': '${entry.payerId}',
      '貨幣識別碼': '${entry.currencyId}',
      '匯率': entry.exchangeRate?.toString() ?? '',
      '已結清': entry.settled ? '是' : '否',
    });
    for (final share in entry.shares.entries) {
      row({
        '資料類型': '分擔',
        '旅程識別碼': '${entry.tripId}',
        '記錄識別碼': '${entry.id}',
        '成員識別碼': '${share.key}',
        '金額': share.value == null ? '' : _decimal(share.value!),
      });
    }
  }
  return Uint8List.fromList(utf8.encode(output.toString()));
}

List<List<String>> _csvRows(String input) {
  if (input.startsWith('\uFEFF')) input = input.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  var closed = false;
  void finishCell() {
    row.add(_csvText(cell.toString()));
    cell = StringBuffer();
    closed = false;
  }

  void finishRow() {
    finishCell();
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    row = [];
  }

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        cell.write(char);
      }
    } else if (char == ',') {
      finishCell();
    } else if (char == '\r' || char == '\n') {
      finishRow();
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
    } else if (char == '"' && cell.isEmpty && !closed) {
      quoted = true;
    } else {
      if (closed || char == '"') throw const FormatException('CSV 引號格式不正確。');
      cell.write(char);
    }
  }
  if (quoted) throw const FormatException('CSV 有未結束的引號。');
  if (cell.isNotEmpty || row.isNotEmpty || closed) finishRow();
  return rows;
}

class _CsvRow {
  const _CsvRow(this.number, this.values);
  final int number;
  final Map<String, String> values;
  String operator [](String column) => values[column]!;
  Never fail(String message) => throw FormatException('第 $number 筆資料：$message');

  String requiredText(String column) {
    final value = this[column];
    if (value.trim().isEmpty) fail('「$column」不能留空。');
    return value;
  }

  int id(String column, {bool allowZero = false}) {
    final value = int.tryParse(this[column].trim());
    if (value == null || value < (allowZero ? 0 : 1)) {
      fail('「$column」必須是有效的識別碼。');
    }
    return value;
  }

  int amount({bool allowZero = false}) {
    final text = this['金額'].trim();
    final value = parseAmountMinor(text);
    if (value == null) {
      if (RegExp(r'^\d+\.\d{3,}$').hasMatch(text)) fail('最多兩位小數');
      final numeric = num.tryParse(text);
      if (numeric != null && numeric > maxAmountMinor / 100) fail('金額超出上限');
      if (!allowZero && numeric != null && numeric <= 0) fail('金額須大於 0');
      fail('金額須為正數，最多兩位小數。');
    }
    if (!isValidAmountMinor(value, allowZero: allowZero)) fail('金額須大於 0');
    return value;
  }

  double? rate() {
    final text = this['匯率'].trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) fail('匯率格式不正確');
    if (value <= 0) fail('匯率須大於 0');
    return value;
  }

  DateTime date() {
    final text = this['日期'].trim();
    final value = DateTime.tryParse(text);
    if (value == null ||
        (dateKey(value) != text && value.toIso8601String() != text)) {
      fail('日期須為 YYYY-MM-DD 或完整 ISO 日期時間。');
    }
    return value;
  }
}

CsvBackup decodeCsvBackup(Uint8List bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('CSV 必須使用 UTF-8 編碼。');
  }
  final table = _csvRows(text);
  if (table.isEmpty) throw const FormatException('CSV 是空白檔案。');
  final header = table.first;
  if (header.toSet().length != header.length ||
      csvBackupColumns.any(
        (column) =>
            column != '動物圖示' &&
            column != '顯示' &&
            column != '貨幣符號' &&
            !header.contains(column),
      )) {
    throw const FormatException('CSV 欄位不符，請選擇由像素記帳匯出的 CSV。');
  }
  final groups = <String, List<_CsvRow>>{
    for (final type in ['種類', '個人帳目', '旅程', '同行成員', '旅程貨幣', '旅程帳目', '分擔'])
      type: [],
  };
  for (var i = 1; i < table.length; i++) {
    if (table[i].length != header.length) {
      throw FormatException('第 ${i + 1} 筆資料的欄位數目不符。');
    }
    final row = _CsvRow(i + 1, {
      for (var c = 0; c < header.length; c++) header[c]: table[i][c],
    });
    final group = groups[row['資料類型']];
    if (group == null) row.fail('未知資料類型「${row['資料類型']}」。');
    group.add(row);
  }
  final categories = {
    for (final category in LedgerCategory.values) category.name: category,
  };
  final seenCategories = <String>{};
  final validIcons = {
    for (final group in categoryIconGroups)
      for (final icon in group.icons) icon.name,
    for (final category in LedgerCategory.values) category.icon,
  };
  for (final row in groups['種類']!) {
    final id = row.requiredText('識別碼');
    if (!seenCategories.add(id)) row.fail('種類識別碼重複。');
    final builtin = categories[id];
    final match = RegExp(r'^custom_([1-9][0-9]*)$').firstMatch(id);
    final type = switch (row['收支類型']) {
      '支出' => EntryType.expense,
      '收入' => EntryType.income,
      _ => null,
    };
    if ((builtin == null && match == null) || type == null) {
      row.fail('未知的種類識別碼或收支類型。');
    }
    final purpose =
        type == EntryType.income
            ? ExpensePurpose.self
            : ExpensePurpose.values
                .where((purpose) => purpose.label == row['用途'])
                .firstOrNull;
    if (purpose == null) row.fail('用途須為「自用」或「為他人」。');
    final color = int.tryParse(row['顏色'], radix: 16);
    if (color == null || color < 0 || color > 0xFFFFFFFF) {
      row.fail('種類顏色格式不正確。');
    }
    if (!validIcons.contains(row['圖示'])) row.fail('找不到種類圖示「${row['圖示']}」。');
    final visible = switch (row.values['顯示']) {
      '是' => true,
      '否' => false,
      null => builtin?.visible ?? true,
      _ => null,
    };
    if (visible == null) row.fail('顯示欄位須為「是」或「否」。');
    if (builtin != null) {
      categories[id] = builtin.copyWith(
        label: row.requiredText('名稱').trim(),
        icon: row['圖示'],
        colorValue: color,
        purpose: purpose,
        type: type,
        visible: visible,
      );
      continue;
    }
    final customId = int.tryParse(match!.group(1)!);
    if (customId == null) row.fail('自訂種類識別碼不正確。');
    categories[id] = LedgerCategory.custom(
      id: customId,
      label: row.requiredText('名稱').trim(),
      icon: row['圖示'],
      colorValue: color,
      purpose: purpose,
      type: type,
      visible: visible,
    );
  }
  final names = <String>{};
  for (final category in categories.values) {
    if (!names.add(
      '${category.type.name}:${categoryLabelKey(category.label)}',
    )) {
      throw const FormatException('CSV 有同名的種類。');
    }
  }
  final entries = <LedgerEntry>[];
  for (final row in groups['個人帳目']!) {
    final category = categories[row['種類識別碼']];
    if (category == null) row.fail('找不到對應種類。');
    final type = switch (row['收支類型']) {
      '支出' => EntryType.expense,
      '收入' => EntryType.income,
      _ => null,
    };
    if (type == null) row.fail('收支類型須為「支出」或「收入」。');
    if (row['種類'] != category.label ||
        (type == EntryType.expense && row['用途'] != category.purpose.label)) {
      row.fail('種類名稱或用途與種類定義不符。');
    }
    final entry = LedgerEntry(
      type: type,
      amountMinor: row.amount(),
      category: category,
      occurredAt: row.date(),
      title: row['名稱'],
      note: row['備註'],
      accountId: row.requiredText('帳戶'),
    );
    final error = ledgerEntryValidationError(entry);
    if (error != null) row.fail(error);
    entries.add(entry);
  }
  final tripRows = <int, _CsvRow>{};
  for (final row in groups['旅程']!) {
    final id = row.id('識別碼');
    if (tripRows.containsKey(id)) row.fail('旅程識別碼重複。');
    tripRows[id] = row;
  }
  final members = <int, Map<int, TripMember>>{};
  final currencies = <int, Map<int, TripCurrency>>{};
  for (final row in groups['同行成員']!) {
    final tripId = row.id('旅程識別碼');
    if (!tripRows.containsKey(tripId)) row.fail('找不到成員所屬旅程。');
    final id = row.id('成員識別碼');
    final map = members.putIfAbsent(tripId, () => {});
    if (map.containsKey(id)) row.fail('同行成員識別碼重複。');
    final icon = row.values['動物圖示'];
    map[id] = TripMember(
      id: id,
      name: row.requiredText('成員姓名'),
      animalIcon: TripMember.animalIcons.containsKey(icon) ? icon : null,
    );
  }
  for (final row in groups['旅程貨幣']!) {
    final tripId = row.id('旅程識別碼');
    if (!tripRows.containsKey(tripId)) row.fail('找不到貨幣所屬旅程。');
    final id = row.id('貨幣識別碼', allowZero: true);
    final map = currencies.putIfAbsent(tripId, () => {});
    if (map.containsKey(id)) row.fail('旅程貨幣識別碼重複。');
    final symbol = (row.values['貨幣符號'] ?? '').trim();
    final currency = TripCurrency.fromJson({
      'id': id,
      'label': row.requiredText('貨幣'),
      'rate': row.rate(),
      if (row['備註'].trim().isNotEmpty) 'remark': row['備註'].trim(),
      if (symbol.isNotEmpty) 'symbol': symbol,
    });
    if (id == baseCurrencyId &&
        (currency.label != tripRows[tripId]!['主貨幣'] || currency.rate != 1)) {
      row.fail('主貨幣定義不符。');
    }
    map[id] = currency;
  }
  final trips = <int, Trip>{};
  for (final item in tripRows.entries) {
    final row = item.value;
    final tripMembers = members[item.key]?.values.toList() ?? [];
    final extras =
        currencies[item.key]?.values
            .where((currency) => currency.id != baseCurrencyId)
            .toList() ??
        [];
    final base = row.requiredText('主貨幣');
    final baseSymbol = (row.values['貨幣符號'] ?? '').trim();
    final trip = Trip(
      id: item.key,
      name: row.requiredText('名稱'),
      baseCurrency: base,
      baseSymbol: baseSymbol.isEmpty ? null : baseSymbol,
      members: tripMembers,
      currencies: extras,
      createdAt: row.date(),
    );
    final error = tripValidationError(trip);
    if (error != null) row.fail(error);
    trips[item.key] = trip;
  }
  final entryRows = <int, _CsvRow>{};
  for (final row in groups['旅程帳目']!) {
    final id = row.id('識別碼');
    if (entryRows.containsKey(id)) row.fail('旅程帳目識別碼重複。');
    entryRows[id] = row;
  }
  final shares = <int, Map<int, int?>>{};
  for (final row in groups['分擔']!) {
    final entryId = row.id('記錄識別碼');
    final entry = entryRows[entryId];
    if (entry == null || row.id('旅程識別碼') != entry.id('旅程識別碼')) {
      row.fail('找不到分擔明細所屬帳目。');
    }
    final id = row.id('成員識別碼');
    final map = shares.putIfAbsent(entryId, () => {});
    if (map.containsKey(id)) row.fail('同一筆帳目有重複的分擔成員。');
    map[id] = row['金額'].trim().isEmpty ? null : row.amount(allowZero: true);
  }
  final tripEntries = <TripEntry>[];
  for (final item in entryRows.entries) {
    final row = item.value;
    final trip = trips[row.id('旅程識別碼')];
    if (trip == null) row.fail('找不到帳目所屬旅程。');
    final payer = row.id('付款人識別碼');
    final currencyId = row.id('貨幣識別碼', allowZero: true);
    final kind = switch (row['收支類型']) {
      '支出' => TripEntryKind.expense,
      '還款' => TripEntryKind.repayment,
      _ => null,
    };
    if (kind == null) row.fail('旅程帳目類型須為「支出」或「還款」。');
    final settled = switch (row['已結清']) {
      '是' => true,
      '否' => false,
      _ => null,
    };
    if (settled == null) row.fail('已結清欄位須為「是」或「否」。');
    final split = shares[item.key] ?? <int, int?>{};
    final amount = row.amount();
    final rate = row.rate();
    final entry = TripEntry(
      id: item.key,
      tripId: trip.id!,
      kind: kind,
      title: row.requiredText('名稱'),
      payerId: payer,
      currencyId: currencyId,
      exchangeRate: rate,
      amountMinor: amount,
      date: row.date(),
      shares: split,
      settled: settled,
    );
    final error = tripEntryValidationError(trip, entry);
    if (error != null) row.fail(error);
    tripEntries.add(entry);
  }
  return CsvBackup(
    categories: categories.values.toList(),
    entries: entries,
    trips: trips.values.toList(),
    tripEntries: tripEntries,
  );
}
