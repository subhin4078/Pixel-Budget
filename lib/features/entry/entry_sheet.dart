import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ledger/ledger_controller.dart';
import '../../ledger/models.dart';
import '../../ledger/ledger_validation.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/amount_keypad.dart';
import 'category_creator.dart';

Future<void> showEntrySheet(
  BuildContext context,
  LedgerController controller, {
  LedgerEntry? entry,
  EntryType initialType = EntryType.expense,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  showDragHandle: false,
  builder:
      (context) => _EntrySheet(
        controller: controller,
        entry: entry,
        initialType: initialType,
      ),
);

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({
    required this.controller,
    this.entry,
    required this.initialType,
  });
  final LedgerController controller;
  final LedgerEntry? entry;
  final EntryType initialType;
  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late EntryType _type = widget.entry?.type ?? widget.initialType;
  late LedgerCategory? _category = widget.entry?.category ?? _defaultFor(_type);
  late String _amount =
      widget.entry == null ? '' : amountInputText(widget.entry!.amountMinor);
  late DateTime _date = widget.entry?.occurredAt ?? widget.controller.now;
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  bool _saving = false;
  bool _reordering = false;
  EdgeDraggingAutoScroller? _categoryAutoScroller;

  bool get _editing => widget.entry != null;
  int get _amountMinor => parseAmountMinor(_amount) ?? 0;

  LedgerEntry get _draft => LedgerEntry(
    id: widget.entry?.id,
    type: _type,
    amountMinor: _amountMinor,
    category: _category!,
    occurredAt: _date,
    title:
        widget.entry != null && widget.entry!.category == _category
            ? widget.entry!.title
            : _category!.label,
    note: _note.text.trim(),
    accountId: widget.entry?.accountId ?? 'cash',
  );

  LedgerCategory? _defaultFor(EntryType type) =>
      widget.controller.lastCategory(type) ??
      widget.controller.pickerCategories(type).firstOrNull;

  bool get _canSave =>
      _category != null && ledgerEntryValidationError(_draft) == null;

  Future<void> _createCategory() async {
    FocusScope.of(context).unfocus();
    final category = await manageCategories(context, widget.controller, _type);
    if (category != null && mounted) {
      setState(() {
        if (category.visible) {
          _type = category.type;
          _category = category;
        } else {
          _category =
              widget.entry?.category == category
                  ? category
                  : _defaultFor(_type);
        }
      });
      if (category.visible) await _rememberCategory(category);
    }
  }

  Future<void> _rememberCategory(LedgerCategory category) async {
    try {
      await widget.controller.rememberCategory(category);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const BudgetSnackBar(content: Text('未能記住上次種類，請再試一次。')));
    }
  }

  Widget _manageCategoriesButton() => Center(
    child: TextButton(
      onPressed: _saving ? null : _createCategory,
      child: const Column(
        children: [
          CuteIcon('edit', size: 36),
          SizedBox(height: 4),
          Text('修改種類', style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );

  Future<void> _reorderCategory(
    LedgerCategory source,
    LedgerCategory target,
  ) async {
    if (_reordering) return;
    setState(() => _reordering = true);
    try {
      await widget.controller.reorderExpenseCategory(source, target);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const BudgetSnackBar(content: Text('未能儲存排列，請再試一次。')));
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  void _scrollCategoryDrag(
    BuildContext gridContext,
    DragUpdateDetails details,
  ) {
    if (!mounted) return;
    final scrollable = Scrollable.of(gridContext);
    _categoryAutoScroller ??= EdgeDraggingAutoScroller(
      scrollable,
      velocityScalar: 12,
    );
    final box = scrollable.context.findRenderObject()! as RenderBox;
    _categoryAutoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(
        center: box.globalToLocal(details.globalPosition),
        width: 40,
        height: 40,
      ),
    );
  }

  Widget _categoryCell(
    BuildContext gridContext,
    LedgerCategory category,
    double width,
  ) {
    final cell = _CategoryCell(
      category: category,
      selected: category == _category,
      onTap: () async {
        HapticFeedback.selectionClick();
        setState(() => _category = category);
        await _rememberCategory(category);
      },
    );
    if (_type == EntryType.income) return cell;
    return DragTarget<LedgerCategory>(
      onWillAcceptWithDetails:
          (details) =>
              !_saving &&
              !_reordering &&
              details.data != category &&
              details.data.type == EntryType.expense &&
              details.data.purpose == category.purpose,
      onAcceptWithDetails:
          (details) => _reorderCategory(details.data, category),
      builder:
          (context, candidates, rejected) => AnimatedScale(
            scale: candidates.isEmpty ? 1 : 1.06,
            duration: const Duration(milliseconds: 120),
            child: LongPressDraggable<LedgerCategory>(
              data: category,
              maxSimultaneousDrags: _saving || _reordering ? 0 : 1,
              onDragUpdate:
                  (details) => _scrollCategoryDrag(gridContext, details),
              onDragEnd: (_) => _categoryAutoScroller?.stopAutoScroll(),
              feedback: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: width,
                  child: Transform.scale(scale: 1.12, child: cell),
                ),
              ),
              childWhenDragging: Opacity(opacity: .25, child: cell),
              child: cell,
            ),
          ),
    );
  }

  @override
  void dispose() {
    _categoryAutoScroller?.stopAutoScroll();
    _note.dispose();
    super.dispose();
  }

  void _setType(EntryType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _category = _defaultFor(type);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '選擇日期',
    );
    if (picked != null && mounted) {
      setState(
        () =>
            _date = DateTime(
              picked.year,
              picked.month,
              picked.day,
              _date.hour,
              _date.minute,
              _date.second,
            ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    final original = widget.entry;
    final entry = _draft;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final controller = widget.controller;
    try {
      if (original == null) {
        final saved = await controller.addEntry(entry);
        showUndoSnackBar(
          messenger,
          '已記下 ${entry.title} ${money(entry.amountMinor)}',
          () => controller.deleteEntry(saved, undoAdded: true),
        );
      } else {
        await controller.updateEntry(entry);
        if (!mounted) return;
        messenger.showSnackBar(const BudgetSnackBar(content: Text('已更新記錄')));
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        BudgetSnackBar(content: Text(saveErrorMessage(error))),
      );
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final entry = widget.entry!;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final deleted = await deleteLedgerEntryWithUndo(
      messenger,
      widget.controller,
      entry,
    );
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final categories = widget.controller.pickerCategories(_type);
    final color = _type == EntryType.income ? Palette.income : Palette.expense;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AbsorbPointer(
          absorbing: _saving,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Palette.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 6, 4),
                child: Row(
                  children: [
                    TypeSwitch(
                      dense: true,
                      labels: const ['支出', '收入'],
                      selected: _type == EntryType.expense ? 0 : 1,
                      onSelected:
                          _saving
                              ? null
                              : (index) => _setType(
                                index == 0
                                    ? EntryType.expense
                                    : EntryType.income,
                              ),
                    ),
                    const Spacer(),
                    if (_editing)
                      IconButton(
                        tooltip: '刪除記錄',
                        onPressed: _saving ? null : _delete,
                        icon: const CuteIcon('delete', size: 24),
                      ),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const CuteIcon('close', size: 24),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      Widget grid(Iterable<LedgerCategory> items) => Wrap(
                        children: [
                          for (final category in items)
                            SizedBox(
                              key: ValueKey(category.name),
                              width: constraints.maxWidth / 5,
                              child: _categoryCell(
                                context,
                                category,
                                constraints.maxWidth / 5,
                              ),
                            ),
                        ],
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children:
                            _type == EntryType.income
                                ? [grid(categories), _manageCategoriesButton()]
                                : [
                                  for (final purpose
                                      in ExpensePurpose.values) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        6,
                                      ),
                                      child: Text(
                                        purpose.label,
                                        style: TextStyle(
                                          color: Color(purpose.colorValue),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    grid(
                                      categories.where(
                                        (category) =>
                                            category.purpose == purpose,
                                      ),
                                    ),
                                  ],
                                  _manageCategoriesButton(),
                                ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                decoration: BoxDecoration(
                  color: Palette.field.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_category case final category?)
                          CategoryBadge(category, size: 36),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .3,
                          ),
                          child: Text(
                            _category?.label ?? '請選擇種類',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerRight,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              amountDisplay(_amount),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: _amount.isEmpty ? Palette.muted : color,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      children: [
                        _DateChip(
                          date: _date,
                          now: widget.controller.now,
                          onTap: _saving ? null : _pickDate,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _note,
                            enabled: !_saving,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: '備註（選填）',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!keyboardOpen)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    10,
                    14,
                    10 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: AmountKeypad(
                    value: _amount,
                    onChanged: (value) => setState(() => _amount = value),
                    doneLabel: _saving ? '儲存中…' : (_editing ? '儲存' : '完成'),
                    onDone: _canSave && !_saving ? _save : null,
                  ),
                )
              else
                const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> deleteLedgerEntryWithUndo(
  ScaffoldMessengerState messenger,
  LedgerController controller,
  LedgerEntry entry,
) => deleteWithUndo(
  messenger,
  delete: () => controller.deleteEntry(entry),
  undo: () => controller.addEntry(entry, restored: true),
  message: '已刪除 ${entry.title} ${money(entry.amountMinor)}',
);

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final LedgerCategory category;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      selected
                          ? color.withValues(alpha: .32)
                          : Palette.card.withValues(alpha: .9),
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CuteIcon(category.icon, size: 26),
              ),
              const SizedBox(height: 3),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Palette.text : Palette.secondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.now, this.onTap});
  final DateTime date;
  final DateTime now;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final label =
        sameDay(date, now)
            ? '今天'
            : sameDay(date, yesterday)
            ? '昨天'
            : date.year == now.year
            ? '${date.month}月${date.day}日'
            : '${date.year}/${date.month}/${date.day}';
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CuteIcon('calendar', size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
