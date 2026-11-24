import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'app/app_database.dart';
import 'ledger/ledger_controller.dart';
import 'ledger/ledger_repository.dart';
import 'travel/travel_controller.dart';
import 'travel/travel_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF252139),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final database = AppDatabase();
  final ledger = LedgerController(LedgerRepository(database));
  final travel = TravelController(TravelRepository(database));
  runApp(PixelBudgetApp(ledger: ledger, travel: travel));
  unawaited(ledger.initialize());
  unawaited(travel.initialize());
}
