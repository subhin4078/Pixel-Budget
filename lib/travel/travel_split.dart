import 'dart:math';
import '../ledger/models.dart';
import 'travel_models.dart';

class SplitResult {
  const SplitResult(this.shares, {this.unassigned = 0});

  /// Each member's share in minor units of the entry's currency.
  final Map<int, int> shares;

  /// Positive: left over with nobody to absorb it. Negative: fixed amounts
  /// exceed the total.
  final int unassigned;

  bool get valid => unassigned == 0 && shares.isNotEmpty;
}

/// Fixed shares are taken first; the remainder is divided evenly among the
/// members without a fixed amount. Odd cents go to the earliest members.
SplitResult splitAmount(int amountMinor, Map<int, int?> shares) {
  final fixedTotal = shares.values.fold<int>(0, (sum, v) => sum + (v ?? 0));
  final auto = [
    for (final share in shares.entries)
      if (share.value == null) share.key,
  ];
  final remainder = amountMinor - fixedTotal;
  if (remainder < 0 || (auto.isEmpty && remainder != 0)) {
    return SplitResult({
      for (final share in shares.entries) share.key: share.value ?? 0,
    }, unassigned: remainder);
  }
  final each = auto.isEmpty ? 0 : remainder ~/ auto.length;
  final extra = auto.isEmpty ? 0 : remainder % auto.length;
  return SplitResult({
    for (final share in shares.entries)
      share.key:
          share.value ?? each + (auto.indexOf(share.key) < extra ? 1 : 0),
  });
}

class MemberBalance {
  MemberBalance(this.memberId);
  final int memberId;

  /// Amounts in base-currency minor units.
  int paid = 0;
  int share = 0;
  int sent = 0;
  int received = 0;

  int get net => paid + sent - share - received;
}

class Transfer {
  const Transfer(this.fromId, this.toId, this.amountMinor);
  final int fromId;
  final int toId;
  final int amountMinor;
}

class TripSummary {
  TripSummary(Trip trip, Iterable<TripEntry> entries)
    : balances = {
        for (final member in trip.members) member.id: MemberBalance(member.id),
      } {
    final memberOrder = {
      for (var i = 0; i < trip.members.length; i++) trip.members[i].id: i,
    };
    for (final entry in entries) {
      final converted = (entry.amountMinor * trip.rateFor(entry)).round();
      if (!entry.isRepayment) {
        totalSpent += converted;
        expenseCount++;
      }
      if (entry.settled) continue;
      final split = splitAmount(entry.amountMinor, entry.shares);
      if (!split.valid) continue;
      final payer = _balance(entry.payerId);
      final shares = _convertedShares(
        split.shares,
        entry.amountMinor,
        converted,
        memberOrder,
      );
      for (final share in shares.entries) {
        final value = share.value;
        if (entry.isRepayment) {
          payer.sent += value;
          _balance(share.key).received += value;
        } else {
          payer.paid += value;
          _balance(share.key).share += value;
        }
      }
    }
    transfers = settle(balances.values);
  }

  final Map<int, MemberBalance> balances;
  int totalSpent = 0;
  int expenseCount = 0;
  late final List<Transfer> transfers;

  MemberBalance _balance(int id) =>
      balances.putIfAbsent(id, () => MemberBalance(id));
}

/// Apportion the rounded entry total without losing or creating any cents.
Map<int, int> _convertedShares(
  Map<int, int> shares,
  int original,
  int converted,
  Map<int, int> memberOrder,
) {
  if (original == converted) return shares;
  final result = <int, int>{};
  final remainders = <({int id, BigInt value})>[];
  final total = BigInt.from(converted);
  final divisor = BigInt.from(original);
  var remaining = converted;
  for (final share in shares.entries) {
    final weighted = BigInt.from(share.value) * total;
    final whole = (weighted ~/ divisor).toInt();
    result[share.key] = whole;
    remaining -= whole;
    remainders.add((id: share.key, value: weighted % divisor));
  }
  remainders.sort((a, b) {
    final byRemainder = b.value.compareTo(a.value);
    if (byRemainder != 0) return byRemainder;
    final byMember = (memberOrder[a.id] ?? memberOrder.length).compareTo(
      memberOrder[b.id] ?? memberOrder.length,
    );
    return byMember == 0 ? a.id.compareTo(b.id) : byMember;
  });
  for (final share in remainders.take(remaining)) {
    result[share.id] = result[share.id]! + 1;
  }
  return result;
}

class _Open {
  _Open(this.memberId, this.amount);
  final int memberId;
  int amount;
}

/// Greedy largest-first matching, with each repayment within the entry limit.
List<Transfer> settle(Iterable<MemberBalance> balances) {
  List<_Open> sorted(Iterable<_Open> items) =>
      items.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  final debtors = sorted([
    for (final balance in balances)
      if (balance.net < 0) _Open(balance.memberId, -balance.net),
  ]);
  final creditors = sorted([
    for (final balance in balances)
      if (balance.net > 0) _Open(balance.memberId, balance.net),
  ]);
  final transfers = <Transfer>[];
  var d = 0;
  var c = 0;
  while (d < debtors.length && c < creditors.length) {
    final debtor = debtors[d];
    final creditor = creditors[c];
    final amount = min(maxAmountMinor, min(debtor.amount, creditor.amount));
    transfers.add(Transfer(debtor.memberId, creditor.memberId, amount));
    debtor.amount -= amount;
    creditor.amount -= amount;
    if (debtor.amount == 0) d++;
    if (creditor.amount == 0) c++;
  }
  return transfers;
}
