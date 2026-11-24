import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ledger/models.dart';
import '../theme/app_theme.dart';
import 'budget_widgets.dart';

/// Formats raw keypad input with thousands separators, keeping a trailing
/// decimal point while the user is typing.
String amountDisplay(String raw, {String symbol = r'$'}) {
  if (raw.isEmpty) return '${symbol}0';
  final parts = raw.split('.');
  final major = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return parts.length == 1 ? '$symbol$major' : '$symbol$major.${parts[1]}';
}

String applyKey(String value, String key) {
  switch (key) {
    case 'del':
      return value.isEmpty ? value : value.substring(0, value.length - 1);
    case '.':
      if (value.contains('.')) return value;
      return value.isEmpty ? '0.' : '$value.';
    default:
      final next = value == '0' ? key : value + key;
      return parseAmountMinor(next) == null ? value : next;
  }
}

class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onDone,
    this.doneLabel = '完成',
  });
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onDone;
  final String doneLabel;

  void _press(String key) {
    final next = applyKey(value, key);
    if (next == value) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final keyHeight = ((height - 430) / 4.8).clamp(42.0, 58.0);
    const gap = 7.0;
    Widget key(String label, {String? id}) => _Key(
      height: keyHeight,
      onTap: () => _press(id ?? label),
      child:
          id == 'del'
              ? const CuteIcon('backspace', size: 26, label: '刪除一位')
              : Text(
                label,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
    );
    final rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', 'del'],
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              for (final row in rows) ...[
                Row(
                  children: [
                    for (final label in row) ...[
                      Expanded(
                        child: label == 'del' ? key('', id: 'del') : key(label),
                      ),
                      if (label != row.last) const SizedBox(width: gap),
                    ],
                  ],
                ),
                if (row != rows.last) const SizedBox(height: gap),
              ],
            ],
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: SizedBox(
            height: keyHeight * 4 + gap * 3,
            child: Material(
              color:
                  onDone == null
                      ? Palette.line.withValues(alpha: .35)
                      : Palette.accent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onDone,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CuteIcon(
                        'save-check',
                        size: math.min(34, keyHeight * .7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doneLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color:
                              onDone == null ? Palette.secondary : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.height, required this.onTap, required this.child});
  final double height;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Material(
      color: Palette.field.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(child: child),
      ),
    ),
  );
}
