import 'package:flutter/material.dart';
import '../../app/activity_log.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key, required this.log, required this.onAdd});
  final ActivityLog log;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: log.recent,
    builder:
        (context, events, _) => GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                '最近活動',
                action: events.isEmpty ? null : '查看全部',
                onAction:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ActivityHistoryPage(log: log),
                      ),
                    ),
              ),
              if (events.isEmpty)
                EmptyNotice('尚無活動，記一筆開始。', action: '記一筆', onAction: onAdd)
              else
                for (final event in events) _ActivityTile(event),
            ],
          ),
        ),
  );
}

class _ActivityHistoryPage extends StatefulWidget {
  const _ActivityHistoryPage({required this.log});
  final ActivityLog log;

  @override
  State<_ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<_ActivityHistoryPage> {
  late final _events = widget.log.readAll();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('活動記錄')),
    body: FutureBuilder(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('無法讀取活動記錄，請返回後再試。'));
        }
        final events = snapshot.data;
        if (events == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: events.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) => _ActivityTile(events[index]),
        );
      },
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.event);
  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.action) {
      ActivityAction.added || ActivityAction.restored => Palette.income,
      ActivityAction.edited => Palette.balance,
      ActivityAction.deleted || ActivityAction.undone => Palette.expense,
    };
    final icon = switch ((event.action, event.kind)) {
      (ActivityAction.added, _) => 'activity-added',
      (
        ActivityAction.edited,
        ActivityKind.trip || ActivityKind.tripExpense || ActivityKind.repayment,
      ) =>
        'activity-trip-edit',
      (ActivityAction.edited, _) => 'activity-edit',
      (ActivityAction.deleted || ActivityAction.undone, _) => 'activity-delete',
      (ActivityAction.restored, _) => 'save-check',
    };
    final date = event.occurredAt;
    final operation = '${event.action.label}${event.kind.label}';
    final details =
        event.tripName == null ? operation : '$operation · ${event.tripName}';
    final timestamp = '${date.year}/${shortDate(date)} ${clockText(date)}';
    const detailStyle = TextStyle(color: Palette.secondary, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, color: color, iconColor: color, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trailing = BoxConstraints(
                  maxWidth: constraints.maxWidth * .55,
                );
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (event.amount case final amount?) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: trailing,
                            child: Text(amount, textAlign: TextAlign.end),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(details, style: detailStyle)),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: trailing,
                          child: Text(
                            timestamp,
                            style: detailStyle,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
