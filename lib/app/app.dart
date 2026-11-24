import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../ledger/ledger_controller.dart';
import '../shared/theme/app_theme.dart';
import '../travel/travel_controller.dart';
import 'app_shell.dart';

class PixelBudgetApp extends StatelessWidget {
  const PixelBudgetApp({super.key, required this.ledger, required this.travel});
  final LedgerController ledger;
  final TravelController travel;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '像素記帳',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('zh', 'TW'),
    supportedLocales: const [Locale('zh', 'TW')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        if (ledger.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Palette.expense),
            ),
          );
        }
        if (ledger.error != null) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '無法開啟帳本',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(ledger.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          ledger.initialize();
                          travel.initialize();
                        },
                        child: const Text('再試一次'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return AppShell(ledger: ledger, travel: travel);
      },
    ),
  );
}
