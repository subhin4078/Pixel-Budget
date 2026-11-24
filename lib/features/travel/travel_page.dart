import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/scene_page.dart';
import '../../travel/travel_controller.dart';
import '../../travel/travel_models.dart';
import 'travel_widgets.dart';
import 'trip_form_page.dart';
import 'trip_page.dart';

Future<void> openTrip(
  BuildContext context,
  TravelController travel,
  Trip trip,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => TripPage(travel: travel, tripId: trip.id!),
  ),
);

Future<void> createTrip(BuildContext context, TravelController travel) async {
  final trip = await Navigator.of(context).push<Trip>(
    MaterialPageRoute(builder: (context) => TripFormPage(travel: travel)),
  );
  if (trip != null && context.mounted) await openTrip(context, travel, trip);
}

class TravelPage extends StatelessWidget {
  const TravelPage({super.key, required this.travel});
  final TravelController travel;

  @override
  Widget build(BuildContext context) => ScenePage(
    kind: SceneKind.travel,
    title: '旅遊分帳',
    subtitle: '開心出遊，告別繁瑣對帳',
    contentTop: 262,
    body:
        (context, s) => [
          if (travel.loading)
            const GlassCard(child: EmptyNotice('正在載入旅程…'))
          else if (travel.error != null)
            GlassCard(
              child: EmptyNotice(
                travel.error!,
                action: '重試',
                onAction: travel.initialize,
              ),
            )
          else if (travel.trips.isEmpty)
            const _Onboarding()
          else
            for (final trip in travel.trips) ...[
              _TripCard(
                trip: trip,
                travel: travel,
                onTap: () => openTrip(context, travel, trip),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 4),
          FilledButton(
            onPressed:
                travel.loading || travel.error != null
                    ? null
                    : () => createTrip(context, travel),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CuteIcon('plus', size: 24),
                SizedBox(width: 6),
                Text('新增旅程'),
              ],
            ),
          ),
        ],
  );
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();
  static const _steps = [
    ('members', '新增成員', '例如 Simon、Tom&Jerry、小明'),
    ('shared-expense', '記下支出', '支援平分或自訂金額'),
    ('auto-settlement', '自動結算', '清楚列出應收與應付'),
  ];
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '三步完成分帳',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final (icon, title, detail) in _steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                IconBadge(icon, color: Palette.balance, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _TripCard extends StatelessWidget {
  const _TripCard({
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
    final entries = travel.entriesFor(trip.id!);
    final pending = summary.transfers.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tripDateRange(entries)} · ${summary.expenseCount} 筆',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AvatarStack(trip: trip),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: StatLine(
                      label: '總花費',
                      value: trip.baseMoney(summary.totalSpent),
                    ),
                  ),
                  Expanded(
                    child: StatLine(
                      label: '結算狀態',
                      value: pending == 0 ? '已結清' : '$pending 筆待付款',
                      color: pending == 0 ? Palette.income : Palette.expense,
                      align: CrossAxisAlignment.end,
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
