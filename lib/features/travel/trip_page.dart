import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/scene_page.dart';
import '../../travel/travel_controller.dart';
import '../../travel/travel_models.dart';
import '../../travel/travel_split.dart';
import 'travel_widgets.dart';
import 'trip_entry_page.dart';
import 'trip_form_page.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key, required this.travel, required this.tripId});
  final TravelController travel;
  final int tripId;
  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  int _tab = 0;

  TravelController get _travel => widget.travel;

  Future<void> _openEntry(Trip trip, [TripEntry? entry]) => Navigator.of(
    context,
  ).push(
    MaterialPageRoute<void>(
      builder:
          (context) => TripEntryPage(travel: _travel, trip: trip, entry: entry),
    ),
  );

  Future<void> _edit(Trip trip) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => TripFormPage(travel: _travel, trip: trip),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _travel,
    builder: (context, _) {
      final trip = _travel.trip(widget.tripId);
      if (trip == null) return const Scaffold();
      final entries = _travel.entriesFor(trip.id!);
      final summary = _travel.summary(trip);
      final perHead =
          trip.members.isEmpty ? 0 : summary.totalSpent / trip.members.length;
      return Scaffold(
        body: Stack(
          children: [
            ScenePage(
              kind: SceneKind.trip,
              title: trip.name,
              subtitle: '${trip.members.length} 人 · ${tripDateRange(entries)}',
              leading: SceneIconButton(
                tooltip: '返回',
                showBackground: false,
                onPressed: () => Navigator.pop(context),
                icon: const CuteIcon('chevron-left', size: 24),
              ),
              actions: [
                SceneIconButton(
                  tooltip: '旅程設定',
                  onPressed: () => _edit(trip),
                  icon: Transform.scale(
                    scale: 1.35,
                    child: const CuteIcon('edit', size: 22),
                  ),
                ),
              ],
              contentTop: 150,
              bottomInset: _tab == 0 ? 96 : 24,
              body:
                  (context, s) => [
                    GlassCard(
                      color: const Color(0xFF473A68),
                      opacity: .9,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatLine(
                              label: '總花費',
                              value: trip.baseMoney(summary.totalSpent),
                            ),
                          ),
                          Expanded(
                            child: StatLine(
                              label: '每人平均',
                              value: trip.baseMoney(perHead.round()),
                              align: CrossAxisAlignment.center,
                            ),
                          ),
                          Expanded(
                            child: StatLine(
                              label: '結算貨幣',
                              value: trip.baseCurrency,
                              color: Palette.balance,
                              align: CrossAxisAlignment.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TypeSwitch(
                      labels: [
                        '帳目 ${summary.expenseCount}',
                        summary.transfers.isEmpty
                            ? '結算'
                            : '結算 ${summary.transfers.length}',
                      ],
                      selected: _tab,
                      onSelected: (index) => setState(() => _tab = index),
                    ),
                    const SizedBox(height: 10),
                    if (_tab == 0)
                      ..._entryList(trip, entries)
                    else
                      ..._settlement(trip, summary),
                  ],
            ),
            if (_tab == 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14 + MediaQuery.paddingOf(context).bottom,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    elevation: 4,
                    shadowColor: const Color(0x995D2545),
                  ),
                  onPressed: () => _openEntry(trip),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CuteIcon('plus', size: 24),
                      SizedBox(width: 6),
                      Text('記一筆'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  List<Widget> _entryList(Trip trip, List<TripEntry> entries) {
    if (entries.isEmpty) {
      return [
        const GlassCard(child: EmptyNotice('尚無帳目，點「記一筆」新增。', icon: 'records')),
      ];
    }
    final groups = <DateTime, List<TripEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.date, () => []).add(entry);
    }
    return [
      for (final group in groups.entries) ...[
        GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: Text(
                  '${group.key.month}月${group.key.day}日 週${weekdayLabels[group.key.weekday - 1]}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Palette.secondary,
                  ),
                ),
              ),
              for (final entry in group.value)
                _TripEntryTile(
                  trip: trip,
                  entry: entry,
                  onTap: () => _openEntry(trip, entry),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Future<void> _markPaid(Trip trip, Transfer transfer) async {
    final from = trip.memberName(transfer.fromId);
    final to = trip.memberName(transfer.toId);
    final amount = trip.baseMoney(transfer.amountMinor);
    final ok = await confirmAction(
      context,
      title: '$from 已還 $to $amount？',
      message: '會加入一筆還款記錄，之後可以在帳目中刪除。',
      confirm: '已還款',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final travel = _travel;
    try {
      final saved = await travel.recordRepayment(trip, transfer);
      showUndoSnackBar(
        messenger,
        '已記下 $from 還 $to $amount',
        () => travel.deleteEntry(saved, undoAdded: true),
      );
    } catch (_) {
      messenger.showSnackBar(
        const BudgetSnackBar(content: Text('未能儲存，請再試一次。')),
      );
    }
  }

  void _copy(Trip trip, TripSummary summary) {
    final lines = [
      '${trip.name} 結算（${trip.baseCurrency}）',
      if (summary.transfers.isEmpty) '全部已結清！',
      for (final t in summary.transfers)
        '${trip.memberName(t.fromId)} 給 ${trip.memberName(t.toId)}：${trip.baseMoney(t.amountMinor)}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const BudgetSnackBar(content: Text('已複製結算結果')));
  }

  List<Widget> _settlement(Trip trip, TripSummary summary) {
    final balances =
        trip.members.map((member) => summary.balances[member.id]!).toList()
          ..sort((a, b) => b.net.compareTo(a.net));
    return [
      GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 6, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              '結算清單',
              action: '複製結果',
              onAction: () => _copy(trip, summary),
            ),
            if (summary.transfers.isEmpty)
              const EmptyNotice('所有款項已結清', icon: 'settled')
            else
              for (final transfer in summary.transfers)
                _TransferRow(
                  trip: trip,
                  transfer: transfer,
                  onPaid: () => _markPaid(trip, transfer),
                ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '每人結餘',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final balance in balances)
              _BalanceRow(trip: trip, balance: balance),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(6, 10, 6, 0),
        child: Text(
          '標記「已結清」的帳目不計入結算；其他貨幣按各筆帳目的實際匯率換算。',
          style: TextStyle(fontSize: 12, color: Palette.muted),
        ),
      ),
    ];
  }
}

class _TripEntryTile extends StatelessWidget {
  const _TripEntryTile({
    required this.trip,
    required this.entry,
    required this.onTap,
  });
  final Trip trip;
  final TripEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = trip.currency(entry.currencyId);
    final foreign = currency.id != baseCurrencyId;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: entry.settled ? .55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            children: [
              if (entry.isRepayment)
                IconBadge('transfer', color: Palette.income, size: 38)
              else
                MemberAvatar(trip: trip, memberId: entry.payerId, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (entry.settled) ...[
                          const SizedBox(width: 6),
                          const CuteIcon('settled', size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.settled
                          ? '已結清 · ${shareSummary(trip, entry)}'
                          : shareSummary(trip, entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyLabel(
                    entry.amountMinor,
                    symbol: currency.symbol,
                    size: 15,
                    color: entry.isRepayment ? Palette.income : Palette.text,
                  ),
                  if (foreign)
                    Text(
                      '≈ ${trip.baseMoney((entry.amountMinor * trip.rateFor(entry)).round())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.trip,
    required this.transfer,
    required this.onPaid,
  });
  final Trip trip;
  final Transfer transfer;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 58,
          height: 36,
          child: Stack(
            children: [
              MemberAvatar(trip: trip, memberId: transfer.fromId, size: 36),
              Positioned(
                left: 24,
                child: MemberAvatar(
                  trip: trip,
                  memberId: transfer.toId,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: trip.memberName(transfer.fromId)),
                    const TextSpan(
                      text: ' 給 ',
                      style: TextStyle(color: Palette.muted),
                    ),
                    TextSpan(text: trip.memberName(transfer.toId)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              MoneyLabel(
                transfer.amountMinor,
                symbol: trip.base.symbol,
                size: 18,
                color: Palette.expense,
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onPaid,
          style: OutlinedButton.styleFrom(
            foregroundColor: Palette.income,
            side: BorderSide(color: Palette.income.withValues(alpha: .6)),
            minimumSize: const Size(64, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('已還款', style: TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.trip, required this.balance});
  final Trip trip;
  final MemberBalance balance;

  @override
  Widget build(BuildContext context) {
    final net = balance.net;
    final even = net == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          MemberAvatar(trip: trip, memberId: balance.memberId, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.memberName(balance.memberId),
                  style: const TextStyle(fontSize: 14),
                ),
                for (final line in [
                  [
                    '付了 ${trip.baseMoney(balance.paid)}',
                    '應分 ${trip.baseMoney(balance.share)}',
                  ],
                  [
                    if (balance.sent > 0) '已還 ${trip.baseMoney(balance.sent)}',
                    if (balance.received > 0)
                      '已收 ${trip.baseMoney(balance.received)}',
                  ],
                ])
                  if (line.isNotEmpty)
                    Text(
                      line.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                even ? '已平' : (net > 0 ? '應收' : '應付'),
                style: const TextStyle(fontSize: 11, color: Palette.muted),
              ),
              MoneyLabel(
                net.abs(),
                symbol: trip.base.symbol,
                size: 15,
                color:
                    even
                        ? Palette.secondary
                        : net > 0
                        ? Palette.income
                        : Palette.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
