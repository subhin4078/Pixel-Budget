import 'package:sqflite/sqflite.dart';
import '../app/activity_log.dart';
import '../app/app_database.dart';
import '../ledger/models.dart';
import 'travel_models.dart';

class TravelRepository {
  TravelRepository(this._database);
  final AppDatabase _database;

  Future<void> open() => _database.open();

  Future<List<Trip>> readTrips() async {
    final db = await _database.open();
    final rows = await db.query('trips', orderBy: 'created_at DESC, id DESC');
    return [
      for (final row in rows)
        Trip.decode(
          row['id'] as int,
          row['created_at'] as String,
          row['data'] as String,
        ),
    ];
  }

  Future<List<TripEntry>> readEntries() async {
    final db = await _database.open();
    final rows = await db.query(
      'trip_entries',
      orderBy: 'occurred_on DESC, id DESC',
    );
    return [
      for (final row in rows)
        TripEntry.decode(
          row['id'] as int,
          row['trip_id'] as int,
          row['data'] as String,
        ),
    ];
  }

  Future<Trip> insertTrip(Trip trip) async {
    final id = await _database.activityLog.write(
      (txn) => txn.insert('trips', {
        'created_at': trip.createdAt.toIso8601String(),
        'data': trip.encode(),
      }),
      (_) => _tripEvent(ActivityAction.added, trip),
    );
    return trip.withId(id);
  }

  Future<void> updateTrip(Trip trip) async {
    await _database.activityLog.write((txn) async {
      final original = await _findTrip(txn, trip.id!);
      final rows = await txn.query(
        'trip_entries',
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      for (final row in rows) {
        final entry = TripEntry.decode(
          row['id'] as int,
          trip.id!,
          row['data'] as String,
        );
        if (original != null &&
            entry.currencyId != baseCurrencyId &&
            entry.exchangeRate == null) {
          final frozen = entry.copyWith(exchangeRate: original.rateFor(entry));
          await txn.update(
            'trip_entries',
            _row(frozen),
            where: 'id = ?',
            whereArgs: [entry.id],
          );
        }
      }
      return txn.update(
        'trips',
        {'data': trip.encode()},
        where: 'id = ?',
        whereArgs: [trip.id],
      );
    }, (_) => _tripEvent(ActivityAction.edited, trip));
  }

  Future<void> deleteTrip(int id) async {
    await _database.activityLog.write(
      (txn) async {
        await txn.delete('trip_entries', where: 'trip_id = ?', whereArgs: [id]);
        return txn.delete('trips', where: 'id = ?', whereArgs: [id]);
      },
      (txn) async {
        final trip = await _findTrip(txn, id);
        return trip == null ? null : _tripEvent(ActivityAction.deleted, trip);
      },
    );
  }

  Future<TripEntry> insertEntry(
    TripEntry entry, {
    bool restored = false,
  }) async {
    final id = await _database.activityLog.write(
      (txn) => txn.insert('trip_entries', _row(entry)),
      (txn) => _entryEvent(
        txn,
        restored ? ActivityAction.restored : ActivityAction.added,
        entry,
      ),
    );
    return entry.copyWith(id: id);
  }

  Future<void> updateEntry(TripEntry entry) async {
    await _database.activityLog.write(
      (txn) => txn.update(
        'trip_entries',
        _row(entry),
        where: 'id = ?',
        whereArgs: [entry.id],
      ),
      (txn) => _entryEvent(txn, ActivityAction.edited, entry),
    );
  }

  Future<void> deleteEntry(int id, {bool undoAdded = false}) async {
    await _database.activityLog.write(
      (txn) => txn.delete('trip_entries', where: 'id = ?', whereArgs: [id]),
      (txn) async {
        final rows = await txn.query(
          'trip_entries',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return null;
        final row = rows.single;
        final entry = TripEntry.decode(
          id,
          row['trip_id'] as int,
          row['data'] as String,
        );
        return _entryEvent(
          txn,
          undoAdded ? ActivityAction.undone : ActivityAction.deleted,
          entry,
        );
      },
    );
  }

  Future<Trip?> _findTrip(Transaction txn, int id) async {
    final rows = await txn.query('trips', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return Trip.decode(id, row['created_at'] as String, row['data'] as String);
  }

  ActivityEvent _tripEvent(ActivityAction action, Trip trip) =>
      ActivityEvent(action: action, kind: ActivityKind.trip, title: trip.name);

  Future<ActivityEvent> _entryEvent(
    Transaction txn,
    ActivityAction action,
    TripEntry entry,
  ) async {
    final trip = await _findTrip(txn, entry.tripId);
    if (trip == null) throw const FormatException('找不到這個旅程。');
    return ActivityEvent(
      action: action,
      kind:
          entry.isRepayment ? ActivityKind.repayment : ActivityKind.tripExpense,
      title: entry.title,
      tripName: trip.name,
      amount: money(
        entry.amountMinor,
        symbol: trip.currency(entry.currencyId).symbol,
      ),
    );
  }

  Map<String, Object?> _row(TripEntry entry) => {
    'trip_id': entry.tripId,
    'occurred_on': dateKey(entry.date),
    'data': entry.encode(),
  };
}
