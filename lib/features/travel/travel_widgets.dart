import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../travel/travel_models.dart';

const memberColors = [
  Color(0xFFF7B4D4),
  Color(0xFFA8CCF2),
  Color(0xFFA8DDD1),
  Color(0xFFF3CBA0),
  Color(0xFFC6B5EE),
  Color(0xFFF0C272),
  Color(0xFFEF9EA8),
  Color(0xFF97B6EF),
];

Color memberColor(Trip trip, int memberId) {
  final index = trip.memberIndex(memberId);
  return memberColors[(index < 0 ? memberId : index) % memberColors.length];
}

class MemberAnimalIcon extends StatelessWidget {
  const MemberAnimalIcon(this.icon, {super.key, required this.size});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CuteIcon(icon.replaceFirst('category-', 'trip-animal-'), size: size);
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.trip,
    required this.memberId,
    this.size = 32,
  });
  final Trip trip;
  final int memberId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final member = trip.member(memberId);
    final icon = member?.animalIcon;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: memberColor(trip, memberId),
        border: Border.all(color: Palette.card, width: 1.5),
      ),
      child:
          icon != null && TripMember.animalIcons.containsKey(icon)
              ? MemberAnimalIcon(icon, size: size * .88)
              : Text(
                member?.initial ?? '?',
                style: TextStyle(
                  fontSize: size * .44,
                  fontWeight: FontWeight.w700,
                  color: Palette.onPink,
                  height: 1,
                ),
              ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.trip,
    this.size = 26,
    this.max = 6,
  });
  final Trip trip;
  final double size;
  final int max;
  @override
  Widget build(BuildContext context) {
    final shown = trip.members.take(max).toList();
    final extra = trip.members.length - shown.length;
    return SizedBox(
      height: size,
      width: size + (shown.length - 1 + (extra > 0 ? 1 : 0)) * size * .62,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * .62,
              child: MemberAvatar(
                trip: trip,
                memberId: shown[i].id,
                size: size,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * size * .62,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.field,
                  border: Border.all(color: Palette.card, width: 1.5),
                ),
                child: Text(
                  '+$extra',
                  style: TextStyle(fontSize: size * .38, color: Palette.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String tripDateRange(Iterable<TripEntry> entries) {
  if (entries.isEmpty) return '還沒有帳目';
  var first = entries.first.date;
  var last = first;
  for (final entry in entries) {
    if (entry.date.isBefore(first)) first = entry.date;
    if (entry.date.isAfter(last)) last = entry.date;
  }
  final start = '${first.month}/${first.day}';
  return first == last ? start : '$start – ${last.month}/${last.day}';
}

String shareSummary(Trip trip, TripEntry entry) {
  if (entry.isRepayment) {
    return '${trip.memberName(entry.payerId)} → ${entry.shares.keys.map(trip.memberName).join('、')}';
  }
  final names = entry.shares.keys.map(trip.memberName).toList();
  final allFixed = entry.shares.values.every((value) => value != null);
  final allAuto = entry.shares.values.every((value) => value == null);
  final who =
      names.length == trip.members.length && trip.members.length > 1
          ? '全部 ${names.length} 人'
          : names.length <= 2
          ? names.join('、')
          : '${names.length} 人';
  final how =
      names.length == 1
          ? ''
          : allAuto
          ? '平分'
          : allFixed
          ? '各自'
          : '部分自訂';
  return '${trip.memberName(entry.payerId)} 付 · $who$how';
}
