import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../ledger/models.dart';
import '../theme/app_theme.dart';
import 'card_backdrop.dart';

class CuteIcon extends StatelessWidget {
  const CuteIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.active = false,
    this.label,
    this.color,
  });
  static const _functionalIcons = {
    'expense-today': Icons.today_rounded,
    'expense-average': Icons.calculate_rounded,
    'net-worth': Icons.savings_rounded,
    'expense-total': Icons.receipt_long_rounded,
    'journey-shortcut': Icons.place_rounded,
    'activity-added': Icons.description_rounded,
    'activity-edit': Icons.edit_rounded,
    'activity-trip-edit': Icons.edit_location_alt_rounded,
    'activity-delete': Icons.delete_outline_rounded,
    'shared-expense': Icons.post_add_rounded,
    'auto-settlement': Icons.fact_check_rounded,
  };
  final String name;
  final double size;
  final bool active;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = _functionalIcons[name];
    if (icon != null) {
      return Icon(
        icon,
        size: size,
        color: color ?? (active ? Palette.expense : Palette.secondary),
        semanticLabel: label,
      );
    }
    return SvgPicture.asset(
      'assets/icons/$name${active ? '-active' : ''}.svg',
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: label,
      excludeFromSemantics: label == null,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = Palette.card,
    this.opacity = .8,
    this.radius = 18,
    this.borderColor,
    this.boxShadow,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double opacity;
  final double radius;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? const Color(0xFFB18DBB).withValues(alpha: .34),
        width: .8,
      ),
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: const Color(0xFF100D25).withValues(alpha: .2),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
    );
    final content = Material(
      type: MaterialType.transparency,
      child: Padding(padding: padding, child: child),
    );
    final host = CardBackdropScope.maybeOf(context);
    if (host == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return CardSlot(host: host, decoration: decoration, child: content);
  }
}

class MoneyLabel extends StatelessWidget {
  const MoneyLabel(
    this.amount, {
    super.key,
    this.size = 18,
    this.color = Palette.text,
    this.signed = false,
    this.align = TextAlign.start,
    this.symbol = r'$',
  });
  final int amount;
  final double size;
  final Color color;
  final bool signed;
  final TextAlign align;
  final String symbol;
  @override
  Widget build(BuildContext context) => Text(
    money(amount, signed: signed, symbol: symbol),
    textAlign: align,
    softWrap: true,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.2,
    ),
  );
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.size = 28});
  final LedgerCategory category;
  final double size;
  @override
  Widget build(BuildContext context) =>
      IconBadge(category.icon, color: Color(category.colorValue), size: size);
}

class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    required this.color,
    this.iconColor,
    this.size = 28,
  });
  final String icon;
  final Color color;
  final Color? iconColor;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .18),
    ),
    child: CuteIcon(icon, size: size * .66, color: iconColor),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 10, right: 2),
            minimumSize: const Size(48, 36),
            foregroundColor: Palette.expense,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action!, style: const TextStyle(fontSize: 13)),
              const CuteIcon('chevron-right', size: 16),
            ],
          ),
        ),
    ],
  );
}

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onShift,
    this.onTapMonth,
  });
  final DateTime month;
  final ValueChanged<int> onShift;
  final VoidCallback? onTapMonth;
  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 16,
    padding: EdgeInsets.zero,
    child: Row(
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          tooltip: '上一個月',
          icon: const CuteIcon('chevron-left', size: 22),
        ),
        Expanded(
          child: InkWell(
            onTap: onTapMonth,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '${month.year}年${month.month}月',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => onShift(1),
          tooltip: '下一個月',
          icon: const CuteIcon('chevron-right', size: 22),
        ),
      ],
    ),
  );
}

class EntryTile extends StatelessWidget {
  const EntryTile(this.entry, {super.key, this.onTap, this.showDate = false});
  final LedgerEntry entry;
  final VoidCallback? onTap;
  final bool showDate;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    final title =
        entry.title.trim().isEmpty ? entry.category.label : entry.title;
    final detail = [
      if (showDate) shortDate(entry.occurredAt),
      if (entry.note.isNotEmpty) entry.note else clockText(entry.occurredAt),
    ].join(' · ');
    return Semantics(
      button: onTap != null,
      label:
          '${income ? '收入' : '支出'}，$title，${money(entry.amountMinor)}，${entry.note}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              children: [
                CategoryBadge(entry.category, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
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
                const SizedBox(width: 10),
                MoneyLabel(
                  income ? entry.amountMinor : -entry.amountMinor,
                  size: 16,
                  signed: income,
                  color: income ? Palette.income : Palette.text,
                  align: TextAlign.right,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyNotice extends StatelessWidget {
  const EmptyNotice(
    this.message, {
    super.key,
    this.icon,
    this.action,
    this.onAction,
  });
  final String message;
  final String? icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          CuteIcon(icon!, size: 44),
          const SizedBox(height: 12),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Palette.secondary,
            height: 1.5,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(minimumSize: const Size(140, 50)),
            child: Text(action!),
          ),
        ],
      ],
    ),
  );
}

String saveErrorMessage(Object error) =>
    error is FormatException ? error.message : '儲存失敗，內容已保留。請重試。';

class BudgetSnackBar extends SnackBar {
  const BudgetSnackBar({super.key, required super.content, super.action})
    : super(duration: const Duration(seconds: 5), persist: false);
}

void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message,
  Future<void> Function() undo,
) {
  if (!messenger.mounted) return;
  messenger.showSnackBar(
    BudgetSnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: '復原',
        textColor: Palette.expense,
        onPressed: () async {
          try {
            await undo();
          } on FormatException catch (error) {
            if (!messenger.mounted) return;
            messenger.showSnackBar(
              BudgetSnackBar(content: Text(error.message)),
            );
          } catch (_) {
            showUndoSnackBar(messenger, '未能復原，請再試一次。', undo);
          }
        },
      ),
    ),
  );
}

Future<bool> deleteWithUndo(
  ScaffoldMessengerState messenger, {
  required Future<void> Function() delete,
  required Future<void> Function() undo,
  required String message,
}) async {
  try {
    await delete();
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        const BudgetSnackBar(content: Text('未能刪除，請再試一次。')),
      );
    }
    return false;
  }
  showUndoSnackBar(messenger, message, undo);
  return true;
}

class FormSaveBar extends StatelessWidget {
  const FormSaveBar({
    super.key,
    required this.label,
    required this.saving,
    required this.onSave,
  });
  final String label;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: FilledButton(
        onPressed: saving ? null : onSave,
        child: Text(saving ? '儲存中…' : label),
      ),
    ),
  );
}

class TypeSwitch extends StatelessWidget {
  const TypeSwitch({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool dense;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF211D36).withValues(alpha: .82),
      borderRadius: BorderRadius.circular(dense ? 14 : 16),
      border: Border.all(color: Palette.line.withValues(alpha: .6), width: .8),
    ),
    child: Row(
      mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var i = 0; i < labels.length; i++)
          _segment(
            Semantics(
              selected: selected == i,
              button: true,
              enabled: onSelected != null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color:
                      selected == i
                          ? const Color(0xFFFFC6DE)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(dense ? 11 : 13),
                ),
                child: InkWell(
                  onTap: onSelected == null ? null : () => onSelected!(i),
                  borderRadius: BorderRadius.circular(dense ? 11 : 13),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: dense ? 7 : 10,
                      horizontal: dense ? 16 : 4,
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: dense ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color:
                            selected == i
                                ? const Color(0xFF46304D)
                                : Palette.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _segment(Widget child) => dense ? child : Expanded(child: child);
}

class StatLine extends StatelessWidget {
  const StatLine({
    super.key,
    required this.label,
    required this.value,
    this.color = Palette.text,
    this.align = CrossAxisAlignment.start,
  });
  final String label;
  final String value;
  final Color color;
  final CrossAxisAlignment align;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Palette.secondary),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirm,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.card,
            title: Text(title, style: const TextStyle(fontSize: 18)),
            content: message == null ? null : Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style:
                    destructive
                        ? FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB8456F),
                        )
                        : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
            ],
          ),
    ) ??
    false;
