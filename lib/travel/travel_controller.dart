import 'package:flutter/foundation.dart';
import 'travel_models.dart';
import 'travel_repository.dart';
import 'travel_split.dart';
import 'travel_validation.dart';

class TravelController extends ChangeNotifier {
  TravelController(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final TravelRepository repository;
  final DateTime Function() _clock;
  List<Trip> _trips = [];
  List<TripEntry> _entries = [];
  final Map<int, TripSummary> _summaries = {};
  bool loading = true;
  String? error;

  DateTime get now => _clock();
  List<Trip> get trips => List.unmodifiable(_trips);

  Trip? trip(int id) {
    for (final trip in _trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  List<TripEntry> entriesFor(int tripId) =>
      _entries.where((entry) => entry.tripId == tripId).toList(growable: false);

  TripSummary summary(Trip trip) =>
      _summaries[trip.id!] ??= TripSummary(trip, entriesFor(trip.id!));

  bool memberInUse(int tripId, int memberId) => _entries.any(
    (entry) =>
        entry.tripId == tripId &&
        (entry.payerId == memberId || entry.shares.containsKey(memberId)),
  );

  bool currencyInUse(int tripId, int currencyId) => _entries.any(
    (entry) => entry.tripId == tripId && entry.currencyId == currencyId,
  );

  String? tripError(Trip draft) {
    final error = tripValidationError(draft);
    if (error != null || draft.id == null) return error;
    final original = trip(draft.id!);
    if (original == null) return '找不到這個旅程';
    final entries = entriesFor(draft.id!);
    if (entries.isNotEmpty &&
        (draft.baseCurrency != original.baseCurrency ||
            draft.base.symbol != original.base.symbol)) {
      return '已有帳目，主貨幣不能更改';
    }
    for (final entry in entries) {
      final frozen =
          entry.currencyId != baseCurrencyId && entry.exchangeRate == null
              ? entry.copyWith(exchangeRate: original.rateFor(entry))
              : entry;
      final error = tripEntryValidationError(draft, frozen);
      if (error != null) return error;
      if (draft.currency(entry.currencyId).label !=
              original.currency(entry.currencyId).label ||
          draft.currency(entry.currencyId).symbol !=
              original.currency(entry.currencyId).symbol) {
        return '已有帳目使用的貨幣不能更改';
      }
    }
    return null;
  }

  String? entryError(TripEntry draft) {
    final parent = trip(draft.tripId);
    return parent == null
        ? '找不到帳目所屬旅程'
        : tripEntryValidationError(parent, draft);
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await repository.open();
      final trips = await repository.readTrips();
      final entries = await repository.readEntries();
      _trips = trips;
      _entries = entries;
    } catch (_) {
      error = '暫時無法開啟旅程資料。';
    } finally {
      loading = false;
      _changed();
    }
  }

  Future<Trip> createTrip(Trip draft) async {
    final error = tripError(draft);
    if (error != null) throw FormatException(error);
    final saved = await repository.insertTrip(draft);
    _trips = [saved, ..._trips];
    _changed();
    return saved;
  }

  Future<void> updateTrip(Trip trip) async {
    final error = tripError(trip);
    if (error != null) throw FormatException(error);
    final original = this.trip(trip.id!)!;
    await repository.updateTrip(trip);
    _entries = [
      for (final entry in _entries)
        entry.tripId == trip.id &&
                entry.currencyId != baseCurrencyId &&
                entry.exchangeRate == null
            ? entry.copyWith(exchangeRate: original.rateFor(entry))
            : entry,
    ];
    _trips = [for (final item in _trips) item.id == trip.id ? trip : item];
    _changed();
  }

  Future<void> deleteTrip(Trip trip) async {
    await repository.deleteTrip(trip.id!);
    _trips = _trips.where((item) => item.id != trip.id).toList();
    _entries = _entries.where((entry) => entry.tripId != trip.id).toList();
    _changed();
  }

  Future<TripEntry> addEntry(TripEntry draft, {bool restored = false}) async {
    final error = entryError(draft);
    if (error != null) throw FormatException(error);
    final saved = await repository.insertEntry(
      _withRate(draft),
      restored: restored,
    );
    _entries = [..._entries, saved];
    _changed();
    return saved;
  }

  Future<void> updateEntry(TripEntry entry) async {
    final error = entryError(entry);
    if (error != null) throw FormatException(error);
    final resolved = _withRate(entry);
    await repository.updateEntry(resolved);
    _entries = [
      for (final item in _entries) item.id == entry.id ? resolved : item,
    ];
    _changed();
  }

  TripEntry _withRate(TripEntry entry) =>
      entry.currencyId == baseCurrencyId
          ? entry
          : entry.copyWith(exchangeRate: trip(entry.tripId)!.rateFor(entry));

  Future<void> deleteEntry(TripEntry entry, {bool undoAdded = false}) async {
    await repository.deleteEntry(entry.id!, undoAdded: undoAdded);
    _entries = _entries.where((item) => item.id != entry.id).toList();
    _changed();
  }

  Future<TripEntry> recordRepayment(Trip trip, Transfer transfer) {
    final today = now;
    return addEntry(
      TripEntry(
        tripId: trip.id!,
        kind: TripEntryKind.repayment,
        title: '還款',
        payerId: transfer.fromId,
        currencyId: baseCurrencyId,
        amountMinor: transfer.amountMinor,
        date: DateTime(today.year, today.month, today.day),
        shares: {transfer.toId: transfer.amountMinor},
      ),
    );
  }

  void _changed() {
    _entries.sort((a, b) {
      final order = b.date.compareTo(a.date);
      return order == 0 ? b.id!.compareTo(a.id!) : order;
    });
    _summaries.clear();
    notifyListeners();
  }
}
