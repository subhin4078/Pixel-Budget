import 'dart:async';
import 'package:flutter/material.dart';
import '../features/entry/entry_sheet.dart';
import '../features/home/home_page.dart';
import '../features/records/records_page.dart';
import '../features/statistics/statistics_page.dart';
import '../features/travel/travel_page.dart';
import '../ledger/ledger_controller.dart';
import '../ledger/models.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/budget_widgets.dart';
import '../travel/travel_controller.dart';
import 'notification_shortcuts.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.ledger, required this.travel});
  final LedgerController ledger;
  final TravelController travel;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(NotificationShortcuts.listen(_handleShortcut));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationShortcuts.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  void _select(int tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = tab);
  }

  void _add() => showEntrySheet(context, widget.ledger);

  void _handleShortcut(String action) {
    if (!mounted) return;
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var reachedHome = false;
      Navigator.of(context).popUntil((route) {
        reachedHome = route.isFirst;
        return reachedHome ||
            route.popDisposition == RoutePopDisposition.doNotPop;
      });
      if (!reachedHome) return;
      if (action == 'income' || action == 'expense') {
        unawaited(
          showEntrySheet(
            context,
            widget.ledger,
            initialType:
                action == 'income' ? EntryType.income : EntryType.expense,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _tab == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _select(0);
    },
    child: Scaffold(
      extendBody: true,
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.ledger, widget.travel]),
        builder:
            (context, _) => IndexedStack(
              index: _tab,
              children: [
                HomePage(
                  controller: widget.ledger,
                  travel: widget.travel,
                  activityLog: widget.ledger.repository.database.activityLog,
                  onOpenTrip: (trip) => openTrip(context, widget.travel, trip),
                  onAdd: _add,
                ),
                RecordsPage(controller: widget.ledger, onAdd: _add),
                StatisticsPage(controller: widget.ledger),
                TravelPage(travel: widget.travel),
              ],
            ),
      ),
      bottomNavigationBar: _BottomNavigation(
        selected: _tab,
        onSelected: _select,
        onAdd: _add,
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  static const _tabs = [
    ('home', '首頁'),
    ('records', '詳細'),
    ('stats', '統計'),
    ('travel', '旅遊'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tab(int index) {
      final (icon, label) = _tabs[index];
      final active = selected == index;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: label,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Material(
              color:
                  active
                      ? const Color(0xFF75465F).withValues(alpha: .55)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CuteIcon(icon, active: active, size: 26),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? Palette.expense : Palette.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF252139),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Palette.expense.withValues(alpha: .2),
          width: .8,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height:
              70 +
              (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 50),
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: Tooltip(
                      message: '記一筆',
                      child: Semantics(
                        button: true,
                        label: '記一筆',
                        child: Material(
                          color: Palette.expense,
                          elevation: 4,
                          shadowColor: const Color(0x995D2545),
                          shape: const CircleBorder(
                            side: BorderSide(
                              color: Color(0xFF252139),
                              width: 4,
                            ),
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAdd,
                            child: const SizedBox.square(
                              dimension: 62,
                              child: Center(child: CuteIcon('plus', size: 30)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}
