import '../ledger/models.dart';
import 'travel_models.dart';
import 'travel_split.dart';

String? tripValidationError(Trip trip) {
  if (trip.name.trim().isEmpty) return '請輸入旅程名稱';
  if (trip.members.length < 2) return '至少加入兩位成員';
  final memberIds = <int>{};
  final memberNames = <String>{};
  for (final member in trip.members) {
    if (member.id <= 0 || !memberIds.add(member.id)) return '同行成員識別碼不正確或重複';
    final name = member.name.trim().toLowerCase();
    if (name.isEmpty) return '請輸入成員名字';
    if (!memberNames.add(name)) return '成員名稱不能重複';
  }
  final base = trip.baseCurrency.trim().toUpperCase();
  if (base.isEmpty) return '請選擇主貨幣';
  if (trip.base.symbol.trim().isEmpty) return '請輸入主貨幣符號';
  final currencyIds = {baseCurrencyId};
  final labels = {base};
  for (final currency in trip.currencies) {
    if (currency.id <= 0 || !currencyIds.add(currency.id)) {
      return '貨幣識別碼不正確或重複';
    }
    final label = currency.label.trim().toUpperCase();
    if (label.isEmpty) return '請輸入貨幣名稱';
    if (!labels.add(label)) return '貨幣名稱不能重複';
    if (currency.symbol.trim().isEmpty) return '請輸入貨幣符號';
    if (currency.rate != null &&
        (!currency.rate!.isFinite || currency.rate! <= 0)) {
      return '匯率須為大於零的有效數字';
    }
  }
  return null;
}

String? tripEntryValidationError(Trip trip, TripEntry entry) {
  if (entry.tripId != trip.id) return '帳目不屬於這個旅程';
  if (!isValidAmountMinor(entry.amountMinor)) {
    return entry.amountMinor <= 0 ? '金額須大於 0' : '金額超出上限';
  }
  if (entry.title.trim().isEmpty) return '請輸入項目名稱';
  if (trip.member(entry.payerId) == null) return '付款人不在同行成員之內';
  if (!trip.allCurrencies.any((currency) => currency.id == entry.currencyId)) {
    return '找不到帳目使用的貨幣';
  }
  if (entry.shares.isEmpty) return '至少選一位分擔成員';
  if (entry.isRepayment) {
    if (entry.currencyId != baseCurrencyId) return '還款須使用主貨幣';
    if (entry.settled) return '還款記錄不可標記為已即場找數';
    if (entry.shares.length != 1) return '還款只能選擇一位收款人';
    if (entry.shares.containsKey(entry.payerId)) return '還款人與收款人不能相同';
  }
  for (final share in entry.shares.entries) {
    if (trip.member(share.key) == null) return '分擔成員不在旅程之內';
    if (share.value != null &&
        !isValidAmountMinor(share.value!, allowZero: true)) {
      return '分擔金額須為有效的非負數';
    }
  }
  if (!splitAmount(entry.amountMinor, entry.shares).valid) {
    return '分擔金額與帳目總額不符';
  }
  final foreign = entry.currencyId != baseCurrencyId;
  final rate =
      entry.exchangeRate ??
      (foreign ? trip.currency(entry.currencyId).rate : null);
  if (foreign && rate == null) return '請輸入匯率，或先設定此貨幣的預設匯率';
  if (rate != null && !rate.isFinite) return '匯率格式不正確';
  if (rate != null && rate <= 0) return '匯率須大於 0';
  if (!foreign && rate != null && rate != 1) return '主貨幣匯率須為 1';
  final converted = entry.amountMinor * (foreign ? rate! : 1);
  if (!converted.isFinite || converted > maxAmountMinor) return '換算後的金額過大';
  return null;
}
