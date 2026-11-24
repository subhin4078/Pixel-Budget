import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../travel/travel_controller.dart';
import '../../travel/travel_models.dart';
import '../../travel/travel_split.dart';
import 'travel_widgets.dart';

final _amountFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      newValue.text.isEmpty || parseAmountMinor(newValue.text) != null
          ? newValue
          : oldValue,
);

class TripEntryPage extends StatefulWidget {
  const TripEntryPage({
    super.key,
    required this.travel,
    required this.trip,
    this.entry,
  });
  final TravelController travel;
  final Trip trip;
  final TripEntry? entry;
  @override
  State<TripEntryPage> createState() => _TripEntryPageState();
}

class _TripEntryPageState extends State<TripEntryPage> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _rate = TextEditingController();
  final Map<int, TextEditingController> _fixed = {};
  final Set<int> _included = {};
  late int _currencyId;
  late int _payerId;
  late DateTime _date;
  bool _settled = false;
  bool _saving = false;

  Trip get _trip => widget.trip;
  bool get _repayment => widget.entry?.isRepayment ?? false;
  TripCurrency get _currency => _trip.currency(_currencyId);

  @override
  void initState() {
    super.initState();
    for (final member in _trip.members) {
      _fixed[member.id] = TextEditingController();
    }
    final entry = widget.entry;
    if (entry != null) {
      _amount.text = amountInputText(entry.amountMinor);
      _title.text = entry.title;
      _currencyId = entry.isRepayment ? baseCurrencyId : entry.currencyId;
      if (_currencyId != baseCurrencyId) {
        _rate.text = '${_trip.rateFor(entry)}';
      }
      _payerId = entry.payerId;
      _date = entry.date;
      _settled = entry.isRepayment ? false : entry.settled;
      for (final share in entry.shares.entries) {
        if (entry.isRepayment &&
            (share.key == entry.payerId || _included.isNotEmpty)) {
          continue;
        }
        _included.add(share.key);
        _fixed.putIfAbsent(share.key, TextEditingController.new);
        if (!entry.isRepayment && share.value != null) {
          _fixed[share.key]!.text = amountInputText(share.value!);
        }
      }
    } else {
      final previous =
          widget.travel
              .entriesFor(_trip.id!)
              .where((entry) => !entry.isRepayment)
              .firstOrNull;
      final now = widget.travel.now;
      _currencyId = previous?.currencyId ?? baseCurrencyId;
      _payerId = previous?.payerId ?? _trip.members.first.id;
      _date = DateTime(now.year, now.month, now.day);
      _included.addAll(_trip.members.map((member) => member.id));
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _rate.dispose();
    for (final controller in _fixed.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _amountMinor => parseAmountMinor(_amount.text) ?? 0;

  double? get _exchangeRate {
    if (_currencyId == baseCurrencyId) return 1;
    if (_rate.text.trim().isEmpty) return _currency.rate;
    return double.tryParse(_rate.text.trim());
  }

  void _setCurrency(int id) {
    setState(() {
      _currencyId = id;
      final original = widget.entry;
      _rate.text =
          original != null && original.currencyId == id && id != baseCurrencyId
              ? '${_trip.rateFor(original)}'
              : '';
    });
  }

  Map<int, int?> get _shares => {
    for (final id in _fixed.keys)
      if (_included.contains(id))
        id:
            _repayment
                ? _amountMinor
                : _fixed[id]!.text.trim().isEmpty
                ? null
                : parseAmountMinor(_fixed[id]!.text) ?? 0,
  };

  TripEntry get _draft => TripEntry(
    id: widget.entry?.id,
    tripId: _trip.id!,
    kind: widget.entry?.kind ?? TripEntryKind.expense,
    title: _title.text.trim(),
    payerId: _payerId,
    currencyId: _repayment ? baseCurrencyId : _currencyId,
    exchangeRate:
        _repayment || _currencyId == baseCurrencyId ? null : _exchangeRate,
    amountMinor: _amountMinor,
    date: _date,
    shares: _shares,
    settled: _repayment ? false : _settled,
  );

  String _money(int minor) => money(minor, symbol: _currency.symbol);

  // Live split guidance is presentation; _blocker applies the shared write rules.
  (String, bool) _status(SplitResult split) {
    if (_amountMinor <= 0) return ('先輸入金額', false);
    if (_included.isEmpty) {
      return (_repayment ? '選擇收款的人' : '至少選一位要分擔的人', false);
    }
    if (split.unassigned > 0) {
      return ('尚有 ${_money(split.unassigned)} 未分配。留空金額可平分餘額。', false);
    }
    if (split.unassigned < 0) {
      return ('分擔金額超出總額 ${_money(-split.unassigned)}', false);
    }
    final auto = _shares.values.where((value) => value == null).length;
    final fixedTotal = _shares.values.fold<int>(0, (sum, v) => sum + (v ?? 0));
    if (auto == 0) return ('金額已全部分配', true);
    if (fixedTotal == 0) {
      return (
        auto == 1
            ? '全數由 1 人負責'
            : '$auto 人平分，每人約 ${_money(_amountMinor ~/ auto)}',
        true,
      );
    }
    return ('其餘 ${_money(_amountMinor - fixedTotal)} 由 $auto 人平分', true);
  }

  String? get _blocker {
    final rateText = _rate.text.trim();
    if (_currencyId != baseCurrencyId &&
        rateText.isNotEmpty &&
        double.tryParse(rateText) == null) {
      return '匯率格式不正確';
    }
    for (final id in _included) {
      final text = _fixed[id]!.text.trim();
      if (text.isNotEmpty && parseAmountMinor(text) == null) {
        return '請輸入有效的分擔金額';
      }
    }
    return widget.travel.entryError(_draft);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '選擇日期',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving || _blocker != null) return;
    final entry = _draft;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.entry == null) {
        await widget.travel.addEntry(entry);
        messenger.showSnackBar(
          BudgetSnackBar(
            content: Text('已記下 ${entry.title} ${_money(entry.amountMinor)}'),
          ),
        );
      } else {
        await widget.travel.updateEntry(entry);
        messenger.showSnackBar(const BudgetSnackBar(content: Text('已更新帳目')));
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
    final ok = await confirmAction(
      context,
      title: '刪除「${entry.title}」？',
      confirm: '刪除',
      destructive: true,
    );
    if (!ok || !mounted || _saving) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final travel = widget.travel;
    setState(() => _saving = true);
    final deleted = await deleteWithUndo(
      messenger,
      delete: () => travel.deleteEntry(entry),
      undo: () => travel.addEntry(entry, restored: true),
      message: '已刪除 ${entry.title}',
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
    final split = splitAmount(_amountMinor, _shares);
    final (status, ok) = _status(split);
    final blocker = _blocker;
    final foreign = _currencyId != baseCurrencyId;
    final exchangeRate = _exchangeRate;
    final convertedAmount =
        exchangeRate != null && exchangeRate.isFinite && exchangeRate > 0
            ? _amountMinor * exchangeRate
            : null;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '關閉',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const CuteIcon('close'),
          ),
          title: Text(
            widget.entry == null
                ? '記一筆'
                : _repayment
                ? '還款記錄'
                : '修改帳目',
          ),
          actions: [
            if (widget.entry != null)
              IconButton(
                tooltip: '刪除',
                onPressed: _saving ? null : _delete,
                icon: const CuteIcon('delete'),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              GlassCard(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amount,
                      enabled: !_saving,
                      autofocus: widget.entry == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_amountFormatter],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        prefixText: '${_currency.symbol} ',
                        prefixStyle: const TextStyle(
                          fontSize: 24,
                          color: Palette.secondary,
                        ),
                        hintText: '0',
                      ),
                    ),
                    if (!_repayment && _trip.allCurrencies.length > 1)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final currency in _trip.allCurrencies)
                            _Pill(
                              label: currency.label,
                              selected: currency.id == _currencyId,
                              onTap:
                                  _saving
                                      ? null
                                      : () => _setCurrency(currency.id),
                            ),
                        ],
                      ),
                    if (foreign) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _rate,
                        enabled: !_saving,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: fieldDecoration(
                          _currency.rate == null
                              ? '實際匯率'
                              : '留空使用預設 ${_currency.rate}',
                          prefix: '1 ${_currency.label} = ',
                          suffix: _trip.baseCurrency,
                        ),
                      ),
                      if (convertedAmount != null &&
                          convertedAmount.isFinite &&
                          convertedAmount <= maxAmountMinor)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '≈ ${_trip.baseMoney(convertedAmount.round())} ${_trip.baseCurrency}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      enabled: !_saving,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.done,
                      decoration: fieldDecoration('項目名稱，例如：午餐'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Palette.field.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _saving ? null : _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const CuteIcon('calendar', size: 18),
                            const SizedBox(width: 6),
                            Text('${_date.month}/${_date.day}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _label(_repayment ? '還款人' : '付款人'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final member in _trip.members)
                    _MemberPill(
                      trip: _trip,
                      member: member,
                      selected: member.id == _payerId,
                      onTap:
                          _saving
                              ? null
                              : () => setState(() {
                                _payerId = member.id;
                                if (_repayment) _included.remove(member.id);
                              }),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _label(_repayment ? '收款人' : '分擔成員')),
                  if (!_repayment)
                    TextButton(
                      onPressed:
                          _saving
                              ? null
                              : () => setState(() {
                                if (_included.length == _trip.members.length) {
                                  _included.clear();
                                } else {
                                  _included.addAll(
                                    _trip.members.map((m) => m.id),
                                  );
                                }
                              }),
                      child: Text(
                        _included.length == _trip.members.length
                            ? '全部取消'
                            : '全選',
                      ),
                    ),
                ],
              ),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                child: Column(
                  children: [
                    for (final member in _trip.members)
                      _ShareRow(
                        trip: _trip,
                        member: member,
                        included: _included.contains(member.id),
                        enabled:
                            !_saving &&
                            (!_repayment || member.id != _payerId),
                        showFixedInput: !_repayment,
                        controller: _fixed[member.id]!,
                        autoShare:
                            split.valid
                                ? _money(split.shares[member.id] ?? 0)
                                : null,
                        onToggle:
                            () => setState(() {
                              if (_repayment) {
                                if (member.id == _payerId) return;
                                _included
                                  ..clear()
                                  ..add(member.id);
                              } else if (!_included.remove(member.id)) {
                                _included.add(member.id);
                              } else {
                                _fixed[member.id]!.clear();
                              }
                            }),
                        onChanged: () => setState(() {}),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 6),
                      child: CuteIcon(
                        ok ? 'save-check' : 'balance-star',
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          color: ok ? Palette.income : Palette.expense,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (!_repayment)
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SwitchListTile(
                    value: _settled,
                    onChanged:
                        _saving
                            ? null
                            : (value) => setState(() => _settled = value),
                    title: const Text('已即場找數', style: TextStyle(fontSize: 15)),
                    subtitle: const Text(
                      '只作記錄，不計入結算',
                      style: TextStyle(fontSize: 12, color: Palette.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: FormSaveBar(
          label: ok ? blocker ?? '儲存' : '儲存',
          saving: _saving,
          onSave: blocker == null ? _save : null,
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Palette.secondary,
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    enabled: onTap != null,
    child: Material(
      color:
          selected
              ? Palette.expense.withValues(alpha: .24)
              : Palette.field.withValues(alpha: .8),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Palette.expense : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading == null ? 14 : 5, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 7)],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? Palette.text : Palette.secondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MemberPill extends StatelessWidget {
  const _MemberPill({
    required this.trip,
    required this.member,
    required this.selected,
    required this.onTap,
  });
  final Trip trip;
  final TripMember member;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _Pill(
    label: member.name,
    selected: selected,
    onTap: onTap,
    leading: MemberAvatar(trip: trip, memberId: member.id, size: 26),
  );
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.trip,
    required this.member,
    required this.included,
    required this.enabled,
    this.showFixedInput = true,
    required this.controller,
    required this.autoShare,
    required this.onToggle,
    required this.onChanged,
  });
  final Trip trip;
  final TripMember member;
  final bool included;
  final bool enabled;
  final bool showFixedInput;
  final TextEditingController controller;
  final String? autoShare;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          checked: included,
          enabled: enabled,
          button: true,
          label: member.name,
          excludeSemantics: true,
          child: InkWell(
            onTap: enabled ? onToggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: included ? Palette.accent : Colors.transparent,
                      border: Border.all(
                        color: included ? Palette.accent : Palette.line,
                        width: 1.6,
                      ),
                    ),
                    child:
                        included
                            ? const CuteIcon('save-check', size: 18)
                            : null,
                  ),
                  const SizedBox(width: 10),
                  Opacity(
                    opacity: included ? 1 : .45,
                    child: MemberAvatar(
                      trip: trip,
                      memberId: member.id,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: included ? Palette.text : Palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (showFixedInput)
        SizedBox(
          width: 118,
          child: TextField(
            controller: controller,
            enabled: enabled && included,
            onChanged: (_) => onChanged(),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_amountFormatter],
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: fieldDecoration(
              !included
                  ? '不分擔'
                  : autoShare == null
                  ? '平分'
                  : '平分 $autoShare',
            ).copyWith(
              hintStyle: TextStyle(
                fontSize: 13,
                color: included ? Palette.secondary : Palette.muted,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
          ),
        ),
    ],
  );
}
