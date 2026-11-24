import 'package:flutter/material.dart';
import '../../app/activity_log.dart';
import '../../ledger/ledger_calculations.dart';
import '../../ledger/ledger_controller.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/scene_page.dart';
import '../../travel/travel_controller.dart';
import '../../travel/travel_models.dart';
import '../settings/settings_page.dart';
import 'activity_list.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.travel,
    required this.activityLog,
    required this.onOpenTrip,
    required this.onAdd,
  });
  final LedgerController controller;
  final TravelController travel;
  final ActivityLog activityLog;
  final ValueChanged<Trip> onOpenTrip;
  final VoidCallback onAdd;

  String _greeting(int hour) =>
      hour < 5
          ? '夜深了，早點休息'
          : hour < 11
          ? '早晨'
          : hour < 14
          ? '午安'
          : hour < 18
          ? '下午好'
          : '晚上好';

  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    final month = controller.currentMonthSummary;
    final today = controller.todaySummary;
    final allTime = controller.allTimeSummary;
    final trip =
        travel.loading || travel.error != null || travel.trips.isEmpty
            ? null
            : travel.trips.first;
    return ScenePage(
      kind: SceneKind.home,
      title: '像素記帳',
      actions: [
        SceneIconButton(
          tooltip: '設定',
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (context) =>
                          SettingsPage(ledger: controller, travel: travel),
                ),
              ),
          icon: const CuteIcon('settings', size: 24),
        ),
      ],
      subtitle:
          '${now.month}月${now.day}日 週${weekdayLabels[now.weekday - 1]} · ${_greeting(now.hour)}',
      contentTop: 190,
      body:
          (context, s) => [
            _BalanceHero(summary: month, month: now),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MiniTile(
                      icon: 'expense-today',
                      color: Palette.expense,
                      label: '今日支出',
                      amount: today.expense,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniTile(
                      icon: 'expense-average',
                      color: Palette.balance,
                      label: '本月日均',
                      amount: month.expense ~/ now.day,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MiniTile(
                      icon: 'net-worth',
                      color: Palette.income,
                      label: '目前身家',
                      amount: allTime.balance,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniTile(
                      icon: 'expense-total',
                      color: Palette.expense,
                      label: '總支出',
                      amount: allTime.expense,
                    ),
                  ),
                ],
              ),
            ),
            if (trip != null) ...[
              const SizedBox(height: 10),
              _TripShortcut(
                trip: trip,
                travel: travel,
                onTap: () => onOpenTrip(trip),
              ),
            ],
            const SizedBox(height: 10),
            RecentActivityCard(log: activityLog, onAdd: onAdd),
          ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summary, required this.month});
  final LedgerSummary summary;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final ratio =
        summary.income == 0
            ? (summary.expense > 0 ? 1.0 : 0.0)
            : (summary.expense / summary.income).clamp(0.0, 1.0);
    return GlassCard(
      color: const Color(0xFF473A68),
      opacity: .9,
      radius: 22,
      borderColor: const Color(0xFF8D72AF).withValues(alpha: .7),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '本月結餘',
                style: TextStyle(fontSize: 14, color: Palette.secondary),
              ),
              const Spacer(),
              Text(
                '${month.month}月',
                style: const TextStyle(fontSize: 13, color: Palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          MoneyLabel(
            summary.balance,
            size: 34,
            color: summary.balance < 0 ? Palette.expense : Palette.balance,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color:
                        summary.income == 0
                            ? Palette.line
                            : Palette.income.withValues(alpha: .35),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: const ColoredBox(color: Palette.expense),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatLine(
                  label: '支出',
                  value: money(summary.expense),
                  color: Palette.expense,
                ),
              ),
              Expanded(
                child: StatLine(
                  label: '收入',
                  value: money(summary.income),
                  color: Palette.income,
                  align: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
  });
  final String icon;
  final Color color;
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Row(
      children: [
        IconBadge(icon, color: color, size: 36),
        const SizedBox(width: 10),
        Expanded(child: StatLine(label: label, value: money(amount))),
      ],
    ),
  );
}

class _TripShortcut extends StatelessWidget {
  const _TripShortcut({
    required this.trip,
    required this.travel,
    required this.onTap,
  });
  final Trip trip;
  final TravelController travel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final summary = travel.summary(trip);
    final pending = summary.transfers.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassCard(
          color: const Color(0xFFF3BDD9),
          opacity: .95,
          borderColor: const Color(0xFFFFE7F3).withValues(alpha: .85),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF100D25).withValues(alpha: .13),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF5F9).withValues(alpha: .65),
                ),
                child: const CuteIcon(
                  'journey-shortcut',
                  size: 26.4,
                  color: Color(0xFF79556E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF443343),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pending == 0
                          ? '${trip.members.length} 人 · 已全部結清'
                          : '${trip.members.length} 人 · $pending 筆待付款',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF685061),
                      ),
                    ),
                  ],
                ),
              ),
              const CuteIcon(
                'chevron-right',
                size: 22,
                color: Color(0xFF79556E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
