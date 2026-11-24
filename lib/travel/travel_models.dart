import 'dart:convert';
import '../ledger/models.dart';

class TripMember {
  const TripMember({required this.id, required this.name, this.animalIcon});
  static const animalIcons = {
    'category-cat': '貓',
    'category-dog': '狗',
    'category-rabbit': '兔子',
    'trip-animal-fox': '狐狸',
    'trip-animal-panda': '熊貓',
    'trip-animal-frog': '青蛙',
    'trip-animal-bear': '熊',
    'trip-animal-pig': '豬',
    'trip-animal-penguin': '企鵝',
    'trip-animal-koala': '無尾熊',
    'trip-animal-lion': '獅子',
    'trip-animal-owl': '貓頭鷹',
    'trip-animal-mouse': '老鼠',
    'trip-animal-tiger': '老虎',
    'trip-animal-elephant': '大象',
  };
  final String? animalIcon;
  final int id;
  final String name;

  String get initial {
    final text = name.trim();
    return text.isEmpty
        ? '?'
        : String.fromCharCode(text.runes.first).toUpperCase();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (animalIcon != null) 'animalIcon': animalIcon,
  };
  factory TripMember.fromJson(Map<String, Object?> json) => TripMember(
    id: json['id'] as int,
    name: json['name'] as String,
    animalIcon: json['animalIcon'] as String?,
  );
}

class TripCurrency {
  const TripCurrency({
    required this.id,
    required this.label,
    this.rate,
    String? symbol,
  }) : _symbol = symbol;
  final int id;
  final String label;
  final String? _symbol;

  /// Default base-currency value of one unit. Entries can override this rate.
  final double? rate;

  String get code => label.trim().split(RegExp(r'[\s(（]')).first.toUpperCase();
  String get symbol => _symbol ?? currencySymbol(code);
  bool get isCustom => _symbol != null || !commonCurrencies.contains(label);

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'rate': rate,
    if (isCustom) 'symbol': symbol,
  };
  factory TripCurrency.fromJson(Map<String, Object?> json) {
    final label = (json['label'] as String).trim();
    final remark = (json['remark'] as String? ?? '').trim();
    return TripCurrency(
      id: json['id'] as int,
      label: remark.isEmpty ? label : '$label（$remark）',
      rate: (json['rate'] as num?)?.toDouble(),
      symbol: json['symbol'] as String?,
    );
  }
}

const baseCurrencyId = 0;

const commonCurrencies = ['HKD', 'JPY', 'EUR', 'CNY', 'TWD', 'USD'];

String currencySymbol(String code) => switch (code) {
  'HKD' => r'$',
  'JPY' => '¥',
  'CNY' || 'RMB' => '¥',
  'TWD' || 'NTD' => r'NT$',
  'USD' => r'US$',
  'KRW' => '₩',
  'THB' => '฿',
  'EUR' => '€',
  'GBP' => '£',
  'SGD' => r'S$',
  'MOP' => r'MOP$',
  _ => '$code ',
};

class Trip {
  const Trip({
    this.id,
    required this.name,
    required this.baseCurrency,
    this.baseSymbol,
    required this.members,
    required this.currencies,
    required this.createdAt,
  });
  final int? id;
  final String name;
  final String baseCurrency;
  final String? baseSymbol;
  final List<TripMember> members;

  /// Extra currencies; the base currency is implicit with [baseCurrencyId].
  final List<TripCurrency> currencies;
  final DateTime createdAt;

  TripCurrency get base => TripCurrency(
    id: baseCurrencyId,
    label: baseCurrency,
    rate: 1,
    symbol: baseSymbol,
  );
  List<TripCurrency> get allCurrencies => [base, ...currencies];

  TripCurrency currency(int id) => allCurrencies.firstWhere(
    (currency) => currency.id == id,
    orElse: () => base,
  );

  double rateFor(TripEntry entry) =>
      entry.currencyId == baseCurrencyId
          ? 1
          : entry.exchangeRate ?? currency(entry.currencyId).rate ?? 1;

  TripMember? member(int id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  String memberName(int id) => member(id)?.name ?? '已移除';
  int memberIndex(int id) => members.indexWhere((member) => member.id == id);

  String baseMoney(int minor, {bool signed = false}) =>
      money(minor, signed: signed, symbol: base.symbol);

  Trip withId(int id) => Trip(
    id: id,
    name: name,
    baseCurrency: baseCurrency,
    baseSymbol: baseSymbol,
    members: members,
    currencies: currencies,
    createdAt: createdAt,
  );

  String encode() => jsonEncode({
    'name': name,
    'base': baseCurrency,
    if (baseSymbol != null) 'baseSymbol': baseSymbol,
    'members': [for (final member in members) member.toJson()],
    'currencies': [for (final currency in currencies) currency.toJson()],
  });

  factory Trip.decode(int id, String createdAt, String data) {
    final json = jsonDecode(data) as Map<String, Object?>;
    return Trip(
      id: id,
      name: json['name'] as String,
      baseCurrency: json['base'] as String,
      baseSymbol: json['baseSymbol'] as String?,
      members: [
        for (final item in json['members'] as List)
          TripMember.fromJson((item as Map).cast<String, Object?>()),
      ],
      currencies: [
        for (final item in json['currencies'] as List)
          TripCurrency.fromJson((item as Map).cast<String, Object?>()),
      ],
      createdAt: DateTime.parse(createdAt),
    );
  }
}

enum TripEntryKind { expense, repayment }

class TripEntry {
  const TripEntry({
    this.id,
    required this.tripId,
    this.kind = TripEntryKind.expense,
    required this.title,
    required this.payerId,
    required this.currencyId,
    required this.amountMinor,
    required this.date,
    required this.shares,
    this.settled = false,
    this.exchangeRate,
  });
  final int? id;
  final int tripId;
  final TripEntryKind kind;
  final String title;

  /// For a repayment, the member who handed over the money.
  final int payerId;
  final int currencyId;
  final double? exchangeRate;
  final int amountMinor;
  final DateTime date;

  /// Members sharing the cost. A fixed amount (minor units of the entry's
  /// currency) or `null` to split whatever is left evenly.
  final Map<int, int?> shares;

  /// Paid back on the spot; excluded from the trip settlement.
  final bool settled;

  bool get isRepayment => kind == TripEntryKind.repayment;

  TripEntry copyWith({int? id, double? exchangeRate}) => TripEntry(
    id: id ?? this.id,
    tripId: tripId,
    kind: kind,
    title: title,
    payerId: payerId,
    currencyId: currencyId,
    exchangeRate: exchangeRate ?? this.exchangeRate,
    amountMinor: amountMinor,
    date: date,
    shares: shares,
    settled: settled,
  );

  String encode() => jsonEncode({
    'kind': kind.name,
    'title': title,
    'payer': payerId,
    'currency': currencyId,
    if (exchangeRate != null) 'rate': exchangeRate,
    'amount': amountMinor,
    'date': dateKey(date),
    'shares': [
      for (final share in shares.entries) [share.key, share.value],
    ],
    'settled': settled,
  });

  factory TripEntry.decode(int id, int tripId, String data) {
    final json = jsonDecode(data) as Map<String, Object?>;
    return TripEntry(
      id: id,
      tripId: tripId,
      kind: TripEntryKind.values.byName(json['kind'] as String),
      title: json['title'] as String,
      payerId: json['payer'] as int,
      currencyId: json['currency'] as int,
      exchangeRate: (json['rate'] as num?)?.toDouble(),
      amountMinor: json['amount'] as int,
      date: DateTime.parse(json['date'] as String),
      shares: {
        for (final share in json['shares'] as List)
          (share as List)[0] as int: share[1] as int?,
      },
      settled: json['settled'] as bool? ?? false,
    );
  }
}
