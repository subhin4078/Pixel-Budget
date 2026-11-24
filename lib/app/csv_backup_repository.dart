import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../ledger/models.dart';
import '../ledger/ledger_validation.dart';
import '../ledger/ledger_repository.dart';
import '../travel/travel_models.dart';
import '../travel/travel_validation.dart';
import 'app_database.dart';
import 'csv_backup.dart';

class CsvImportPlan {
  const CsvImportPlan({
    required this.categories,
    required this.categoryTargets,
    required this.entries,
    required this.trips,
    required this.tripEntries,
    required this.skippedEntries,
    required this.skippedTrips,
  });
  final List<LedgerCategory> categories;
  final Map<String, LedgerCategory> categoryTargets;
  final List<LedgerEntry> entries;
  final List<Trip> trips;
  final List<TripEntry> tripEntries;
  final int skippedEntries;
  final int skippedTrips;
  bool get isEmpty => categories.isEmpty && entries.isEmpty && trips.isEmpty;
}

String _categoryKey(LedgerCategory category) => jsonEncode([
  category.type.name,
  categoryLabelKey(category.label),
  category.icon,
  category.colorValue,
  category.purpose.name,
]);

String _entryKey(LedgerEntry entry) => jsonEncode([
  entry.type.name,
  entry.amountMinor,
  _categoryKey(entry.category),
  entry.accountId,
  entry.occurredAt.toIso8601String(),
  entry.title,
  entry.note,
]);

Map<int, List<TripEntry>> _groupEntries(List<TripEntry> entries) {
  final groups = <int, List<TripEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.tripId, () => []).add(entry);
  }
  return groups;
}

String _tripKey(Trip trip, Map<int, List<TripEntry>> entries) => jsonEncode([
  trip.createdAt.toIso8601String(),
  trip.encode(),
  [
    for (final entry in entries[trip.id] ?? <TripEntry>[])
      (entry.currencyId == baseCurrencyId
              ? entry
              : entry.copyWith(exchangeRate: trip.rateFor(entry)))
          .encode(),
  ]..sort(),
]);

// Retain legitimate identical records while making repeated imports idempotent.
List<T> _newRecords<T>(
  Iterable<String> existingKeys,
  List<T> incoming,
  String Function(T) key,
) {
  final counts = <String, int>{};
  final seen = <String, int>{};
  for (final value in existingKeys) {
    counts.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
  return incoming.where((record) {
    final value = key(record);
    final occurrence = seen.update(
      value,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return occurrence > (counts[value] ?? 0);
  }).toList();
}

CsvImportPlan planCsvImport(CsvBackup existing, CsvBackup incoming) {
  for (final entry in incoming.entries) {
    final error = ledgerEntryValidationError(entry);
    if (error != null) throw FormatException(error);
  }
  final incomingTrips = <int, Trip>{};
  for (final trip in incoming.trips) {
    if (trip.id == null ||
        trip.id! <= 0 ||
        incomingTrips.containsKey(trip.id)) {
      throw const FormatException('旅程識別碼不正確或重複');
    }
    final error = tripValidationError(trip);
    if (error != null) throw FormatException(error);
    incomingTrips[trip.id!] = trip;
  }
  for (final entry in incoming.tripEntries) {
    final trip = incomingTrips[entry.tripId];
    if (trip == null) throw const FormatException('找不到帳目所屬旅程');
    final error = tripEntryValidationError(trip, entry);
    if (error != null) throw FormatException(error);
  }
  final targets = <String, LedgerCategory>{};
  final newCategories = <LedgerCategory>[];
  for (final category in incoming.categories) {
    if (category.customId == null) {
      final sameId =
          existing.categories
              .where((item) => item.name == category.name)
              .firstOrNull;
      if (sameId != null && _categoryKey(sameId) == _categoryKey(category)) {
        targets[category.name] = sameId;
        continue;
      }
    }
    final match =
        existing.categories
            .where(
              (item) =>
                  item.type == category.type &&
                  categoryLabelKey(item.label) ==
                      categoryLabelKey(category.label),
            )
            .firstOrNull;
    if (match != null && _categoryKey(match) != _categoryKey(category)) {
      throw FormatException('種類「${category.label}」與現有種類的用途或圖示設定不同，無法合併。');
    }
    targets[category.name] = match ?? category;
    if (match == null) newCategories.add(category);
  }
  final entries = _newRecords(
    existing.entries.map(_entryKey),
    incoming.entries,
    _entryKey,
  );
  final existingTripEntries = _groupEntries(existing.tripEntries);
  final incomingTripEntries = _groupEntries(incoming.tripEntries);
  final trips = _newRecords(
    existing.trips.map((trip) => _tripKey(trip, existingTripEntries)),
    incoming.trips,
    (trip) => _tripKey(trip, incomingTripEntries),
  );
  final tripIds = {for (final trip in trips) trip.id};
  return CsvImportPlan(
    categories: newCategories,
    categoryTargets: targets,
    entries: entries,
    trips: trips,
    tripEntries:
        incoming.tripEntries
            .where((entry) => tripIds.contains(entry.tripId))
            .toList(),
    skippedEntries: incoming.entries.length - entries.length,
    skippedTrips: incoming.trips.length - trips.length,
  );
}

class CsvBackupRepository {
  CsvBackupRepository(this._database);
  final AppDatabase _database;

  Future<CsvBackup> read() async {
    final db = await _database.open();
    return db.transaction(_read);
  }

  Future<CsvBackup> _read(DatabaseExecutor db) async {
    final categories = await LedgerRepository.readCategories(db);
    final entryRows = await db.query(
      'entries',
      orderBy: 'occurred_at DESC, id DESC',
    );
    final tripRows = await db.query(
      'trips',
      orderBy: 'created_at DESC, id DESC',
    );
    final tripEntryRows = await db.query(
      'trip_entries',
      orderBy: 'occurred_on DESC, id DESC',
    );
    return CsvBackup(
      categories: categories,
      entries: [
        for (final row in entryRows)
          LedgerEntry.fromMap(row, categories: categories),
      ],
      trips: [
        for (final row in tripRows)
          Trip.decode(
            row['id'] as int,
            row['created_at'] as String,
            row['data'] as String,
          ),
      ],
      tripEntries: [
        for (final row in tripEntryRows)
          TripEntry.decode(
            row['id'] as int,
            row['trip_id'] as int,
            row['data'] as String,
          ),
      ],
    );
  }

  Future<CsvImportPlan> preview(CsvBackup incoming) async =>
      planCsvImport(await read(), incoming);

  Future<CsvImportPlan> importData(CsvBackup incoming) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      final plan = planCsvImport(await _read(txn), incoming);
      final targets = Map<String, LedgerCategory>.of(plan.categoryTargets);
      for (final category in plan.categories) {
        targets[category.name] = await LedgerRepository.insertCategory(
          txn,
          category,
        );
      }
      for (final entry in plan.entries) {
        await txn.insert('entries', {
          ...entry.toMap(),
          'category': targets[entry.category.name]!.name,
        });
      }
      final tripIds = <int, int>{};
      for (final trip in plan.trips) {
        tripIds[trip.id!] = await txn.insert('trips', {
          'created_at': trip.createdAt.toIso8601String(),
          'data': trip.encode(),
        });
      }
      for (final entry in plan.tripEntries) {
        final sourceTrip = incoming.trips.firstWhere(
          (trip) => trip.id == entry.tripId,
        );
        final resolved =
            entry.currencyId == baseCurrencyId
                ? entry
                : entry.copyWith(exchangeRate: sourceTrip.rateFor(entry));
        await txn.insert('trip_entries', {
          'trip_id': tripIds[entry.tripId]!,
          'occurred_on': dateKey(entry.date),
          'data': resolved.encode(),
        });
      }
      return plan;
    });
  }
}
