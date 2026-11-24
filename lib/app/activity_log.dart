import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

enum ActivityAction {
  added('新增'),
  edited('編輯'),
  deleted('刪除'),
  restored('復原'),
  undone('撤銷新增');

  const ActivityAction(this.label);
  final String label;
}

enum ActivityKind {
  income('收入'),
  expense('支出'),
  trip('旅程'),
  tripExpense('旅遊支出'),
  repayment('旅遊還款');

  const ActivityKind(this.label);
  final String label;
}

class ActivityEvent {
  ActivityEvent({
    required this.action,
    required this.kind,
    required this.title,
    this.tripName,
    this.amount,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  final ActivityAction action;
  final ActivityKind kind;
  final String title;
  final String? tripName;
  final String? amount;
  final DateTime occurredAt;

  Map<String, Object?> toRow() => {
    'action': action.name,
    'kind': kind.name,
    'title': title,
    'trip_name': tripName,
    'amount': amount,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };

  factory ActivityEvent.fromRow(Map<String, Object?> row) => ActivityEvent(
    action: ActivityAction.values.byName(row['action'] as String),
    kind: ActivityKind.values.byName(row['kind'] as String),
    title: row['title'] as String,
    tripName: row['trip_name'] as String?,
    amount: row['amount'] as String?,
    occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
  );

  static ActivityEvent? tryFromRow(Map<String, Object?> row) {
    try {
      return ActivityEvent.fromRow(row);
    } catch (_) {
      return null;
    }
  }
}

class ActivityLog {
  ActivityLog(this._open);

  final Future<Database> Function() _open;
  final _recent = ValueNotifier<List<ActivityEvent>>(const []);
  ValueListenable<List<ActivityEvent>> get recent => _recent;

  Future<void> load(Database db) async {
    _recent.value = await _read(db, limit: 5);
  }

  Future<List<ActivityEvent>> readAll() async => _read(await _open());

  /// Save the operation and its snapshot together, then publish the new list.
  Future<int> write(
    Future<int> Function(Transaction txn) change,
    FutureOr<ActivityEvent?> Function(Transaction txn) describe,
  ) async {
    final db = await _open();
    final (result, recent) = await db.transaction((txn) async {
      final event = await describe(txn);
      final result = await change(txn);
      if (result == 0 || event == null) return (result, null);
      await txn.insert('activity_log', event.toRow());
      return (result, await _read(txn, limit: 5));
    });
    if (recent != null) _recent.value = recent;
    return result;
  }

  Future<List<ActivityEvent>> _read(DatabaseExecutor db, {int? limit}) async {
    final rows = await db.query(
      'activity_log',
      orderBy: 'id DESC',
      limit: limit,
    );
    return List.unmodifiable(rows.map(ActivityEvent.tryFromRow).nonNulls);
  }
}
