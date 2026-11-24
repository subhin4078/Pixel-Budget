import 'models.dart';

String? ledgerEntryValidationError(LedgerEntry entry) {
  if (!isValidAmountMinor(entry.amountMinor)) {
    return entry.amountMinor <= 0 ? '金額須大於 0' : '金額超出上限';
  }
  if (entry.type != entry.category.type) return '收支類型與種類不符';
  if (entry.accountId.trim().isEmpty) return '請選擇帳戶';
  return null;
}
