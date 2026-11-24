import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../travel/travel_controller.dart';
import '../../travel/travel_models.dart';
import 'travel_widgets.dart';

const _customCurrencyOption = '\u0000custom';

class TripFormPage extends StatefulWidget {
  const TripFormPage({super.key, required this.travel, this.trip});
  final TravelController travel;
  final Trip? trip;
  @override
  State<TripFormPage> createState() => _TripFormPageState();
}

class _TripFormPageState extends State<TripFormPage> {
  late final _name = TextEditingController(text: widget.trip?.name ?? '');
  final _newMember = TextEditingController();
  late List<TripMember> _members = [...?widget.trip?.members];
  late String _base = widget.trip?.baseCurrency ?? 'HKD';
  late String? _baseSymbol = widget.trip?.baseSymbol;
  late List<TripCurrency> _currencies = [...?widget.trip?.currencies];
  late final Map<int, String> _rates = {
    for (final currency in _currencies)
      currency.id: currency.rate?.toString() ?? '',
  };
  bool _saving = false;

  bool get _editing => widget.trip != null;
  bool get _hasEntries =>
      _editing && widget.travel.entriesFor(widget.trip!.id!).isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _newMember.dispose();
    super.dispose();
  }

  Trip get _shape => Trip(
    id: widget.trip?.id,
    name: _name.text.trim(),
    baseCurrency: _base,
    baseSymbol: _baseSymbol,
    members: _members,
    currencies: [
      for (final currency in _currencies)
        TripCurrency(
          id: currency.id,
          label: currency.label,
          rate: double.tryParse(_rates[currency.id] ?? ''),
          symbol: currency.isCustom ? currency.symbol : null,
        ),
    ],
    createdAt: widget.trip?.createdAt ?? widget.travel.now,
  );

  int get _nextMemberId =>
      _members.fold<int>(0, (max, m) => m.id > max ? m.id : max) + 1;

  int get _nextCurrencyId =>
      [
        ...?widget.trip?.currencies.map((c) => c.id),
        ..._currencies.map((c) => c.id),
      ].fold<int>(0, (max, id) => id > max ? id : max) +
      1;

  void _addMember() {
    final names = _newMember.text
        .split(RegExp(r'[,，、\s]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty);
    final skipped = <String>[];
    setState(() {
      for (final name in names) {
        if (_members.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
          skipped.add(name);
          continue;
        }
        _members = [..._members, TripMember(id: _nextMemberId, name: name)];
      }
      _newMember.clear();
    });
    if (skipped.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        BudgetSnackBar(content: Text('已略過重複成員：${skipped.join('、')}')),
      );
    }
  }

  Future<void> _memberOptions(TripMember member) async {
    final inUse =
        _editing && widget.travel.memberInUse(widget.trip!.id!, member.id);
    final controller = TextEditingController(text: member.name);
    final form = GlobalKey<FormState>();
    var animalIcon = member.animalIcon;
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => _DialogTextController(
            controller: controller,
            child: StatefulBuilder(
              builder:
                  (context, updateDialog) => AlertDialog(
                    title: const Text('成員', style: TextStyle(fontSize: 18)),
                    scrollable: true,
                    insetPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 24,
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                    content: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: controller,
                            decoration: fieldDecoration('名字'),
                            validator: (value) {
                              final trimmed = (value ?? '').trim();
                              if (trimmed.isEmpty) return '請輸入成員名字';
                              if (_members.any(
                                (m) =>
                                    m.id != member.id &&
                                    m.name.toLowerCase() ==
                                        trimmed.toLowerCase(),
                              )) {
                                return '成員名稱不能重複';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text('動物圖示'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 360,
                            height: 210,
                            child: GridView.count(
                              crossAxisCount: 5,
                              mainAxisExtent: 66,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                for (final option
                                    in TripMember.animalIcons.entries)
                                  Semantics(
                                    selected: animalIcon == option.key,
                                    button: true,
                                    child: Material(
                                      color: Palette.field,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color:
                                              animalIcon == option.key
                                                  ? Palette.accent
                                                  : Palette.line,
                                          width:
                                              animalIcon == option.key ? 2 : 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap:
                                            () => updateDialog(
                                              () => animalIcon = option.key,
                                            ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            MemberAnimalIcon(
                                              option.key,
                                              size: 36,
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  option.value,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed:
                            inUse
                                ? null
                                : () => Navigator.pop(context, '\u0000remove'),
                        child: Text(
                          inUse ? '已有帳目，不能移除' : '移除',
                          style: TextStyle(
                            color:
                                inUse ? Palette.muted : const Color(0xFFFF8FB0),
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(context, controller.text);
                          }
                        },
                        child: const Text('確定'),
                      ),
                    ],
                  ),
            ),
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result == '\u0000remove') {
        if (!inUse) _members = _members.where((m) => m != member).toList();
      } else if (result.trim().isNotEmpty) {
        _members = [
          for (final m in _members)
            m.id == member.id
                ? TripMember(
                  id: m.id,
                  name: result.trim(),
                  animalIcon: animalIcon,
                )
                : m,
        ];
      }
    });
  }

  List<String> get _currencyLabels => [
    _base,
    ..._currencies.map((currency) => currency.label),
  ];

  void _setBase(String code) {
    if (code == _base || _hasEntries) return;
    final previous = _shape.allCurrencies;
    final selected = previous.where((item) => item.label == code).firstOrNull;
    final conversion = selected?.rate;
    final id = _nextCurrencyId;
    setState(() {
      _base = code;
      _baseSymbol = selected?.isCustom == true ? selected!.symbol : null;
      _currencies = [
        for (final item in previous)
          if (item.label != code)
            TripCurrency(
              id: item.id == baseCurrencyId ? id : item.id,
              label: item.label,
              symbol: item.isCustom ? item.symbol : null,
            ),
      ];
      _rates.clear();
      for (final currency in _currencies) {
        final old = previous.firstWhere(
          (item) =>
              item.id == (currency.id == id ? baseCurrencyId : currency.id),
        );
        _rates[currency.id] =
            conversion != null && old.rate != null
                ? '${old.rate! / conversion}'
                : '';
      }
    });
  }

  void _addCurrency() {
    final code =
        commonCurrencies
            .where((item) => !_currencyLabels.contains(item))
            .firstOrNull ??
        commonCurrencies.firstWhere((item) => item != _base);
    final currency = TripCurrency(id: _nextCurrencyId, label: code);
    setState(() {
      _currencies.add(currency);
      _rates[currency.id] = '';
    });
  }

  void _changeCurrency(TripCurrency currency, String code) {
    if (!currency.isCustom && currency.label == code) return;
    setState(() {
      _currencies = [
        for (final item in _currencies)
          item.id == currency.id
              ? TripCurrency(id: item.id, label: code)
              : item,
      ];
      _rates[currency.id] = '';
    });
  }

  Future<void> _editCustomCurrency(TripCurrency currency) async {
    var name = currency.label;
    var symbol = currency.symbol;
    final form = GlobalKey<FormState>();
    final result = await showDialog<({String label, String symbol})>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('自訂貨幣'),
            scrollable: true,
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    onSaved: (value) => name = value!.trim(),
                    autofocus: true,
                    decoration: fieldDecoration('名稱，例如：JPY（信用卡）'),
                    validator: (value) {
                      final label = value!.trim().toUpperCase();
                      if (label.isEmpty) return '請輸入貨幣名稱';
                      if (label == _base.toUpperCase() ||
                          _currencies.any(
                            (item) =>
                                item.id != currency.id &&
                                item.label.toUpperCase() == label,
                          )) {
                        return '貨幣名稱不能重複';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: symbol,
                    onSaved: (value) => symbol = value!.trim(),
                    decoration: fieldDecoration('金額符號，例如：¥'),
                    validator:
                        (value) => value!.trim().isEmpty ? '請輸入貨幣符號' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    form.currentState!.save();
                    Navigator.pop(context, (label: name, symbol: symbol));
                  }
                },
                child: const Text('確定'),
              ),
            ],
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _currencies = [
        for (final item in _currencies)
          item.id == currency.id
              ? TripCurrency(
                id: item.id,
                label: result.label,
                symbol: result.symbol,
              )
              : item,
      ];
    });
  }

  void _removeCurrency(TripCurrency currency) {
    if (_editing &&
        widget.travel.currencyInUse(widget.trip!.id!, currency.id)) {
      return;
    }
    setState(() {
      _currencies.remove(currency);
      _rates.remove(currency.id);
    });
  }

  String? get _problem {
    for (final currency in _currencies) {
      final rate = double.tryParse(_rates[currency.id] ?? '');
      if (rate == null || !rate.isFinite || rate <= 0) {
        return '請填寫 ${currency.label} 的有效預設匯率';
      }
    }
    return widget.travel.tripError(_shape);
  }

  Future<void> _save() async {
    if (_problem != null || _saving) return;
    final trip = _shape;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.travel.updateTrip(trip);
        if (mounted) Navigator.pop(context, trip);
      } else {
        final saved = await widget.travel.createTrip(trip);
        if (mounted) Navigator.pop(context, saved);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(BudgetSnackBar(content: Text(saveErrorMessage(error))));
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final trip = widget.trip!;
    final ok = await confirmAction(
      context,
      title: '刪除「${trip.name}」？',
      message: '此旅程及所有帳目將被刪除，無法復原。',
      confirm: '刪除旅程',
      destructive: true,
    );
    if (!ok || !mounted || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.travel.deleteTrip(trip);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const BudgetSnackBar(content: Text('未能刪除旅程，請再試一次。')));
      return;
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final shape = _shape;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '關閉',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const CuteIcon('close'),
          ),
          title: Text(_editing ? '旅程設定' : '新旅程'),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _label('旅程名稱'),
              TextField(
                controller: _name,
                enabled: !_saving,
                autofocus: !_editing,
                onChanged: (_) => setState(() {}),
                decoration: fieldDecoration('例如：日本自駕遊'),
              ),
              _label('同行成員'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final member in _members)
                    ActionChip(
                      avatar: MemberAvatar(
                        trip: shape,
                        memberId: member.id,
                        size: 26,
                      ),
                      label: Text(member.name),
                      onPressed: _saving ? null : () => _memberOptions(member),
                      backgroundColor: Palette.field,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
              if (_members.isNotEmpty) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newMember,
                      enabled: !_saving,
                      onSubmitted: (_) => _addMember(),
                      textInputAction: TextInputAction.done,
                      decoration: fieldDecoration('多位成員以逗號分隔'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _addMember,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 46),
                    ),
                    child: const Text('加入'),
                  ),
                ],
              ),
              if (_members.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '點成員可更換圖示、改名或移除',
                    style: TextStyle(fontSize: 12, color: Palette.muted),
                  ),
                ),
              _label('主貨幣'),
              DropdownButtonFormField<String>(
                key: ValueKey(_base),
                initialValue: _base,
                isExpanded: true,
                decoration: fieldDecoration('主貨幣'),
                dropdownColor: Palette.field,
                items: [
                  for (final code in {...commonCurrencies, ..._currencyLabels})
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged:
                    _hasEntries || _saving
                        ? null
                        : (code) {
                          if (code != null) _setBase(code);
                        },
              ),
              _label('預設匯率'),
              for (final currency in _currencies)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _currencyRow(currency),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _addCurrency,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('加入貨幣'),
                ),
              ),
              const Text(
                '填寫 1 單位外幣可換多少主貨幣。記帳時匯率留空便採用此預設值。',
                style: TextStyle(fontSize: 12, color: Palette.muted),
              ),
              if (_hasEntries)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '已有帳目，主貨幣不能更改。',
                    style: TextStyle(fontSize: 12, color: Palette.muted),
                  ),
                ),
              if (_editing) ...[
                const SizedBox(height: 28),
                TextButton(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8FB0),
                  ),
                  child: const Text('刪除這個旅程'),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: FormSaveBar(
          label: problem ?? (_editing ? '儲存' : '新增旅程'),
          saving: _saving,
          onSave: problem == null ? _save : null,
        ),
      ),
    );
  }

  Widget _currencyRow(TripCurrency currency) {
    final inUse =
        _editing && widget.travel.currencyInUse(widget.trip!.id!, currency.id);
    return Row(
      key: ValueKey(currency.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: InputDecorator(
            decoration: fieldDecoration('貨幣').copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    currency.isCustom ? _customCurrencyOption : currency.label,
                isExpanded: true,
                isDense: true,
                style: const TextStyle(fontSize: 14, color: Palette.text),
                dropdownColor: Palette.field,
                selectedItemBuilder:
                    (context) => [
                      for (final code in commonCurrencies) Text(code),
                      Text(currency.label, overflow: TextOverflow.ellipsis),
                    ],
                items: [
                  for (final code in commonCurrencies)
                    DropdownMenuItem(value: code, child: Text(code)),
                  const DropdownMenuItem(
                    value: _customCurrencyOption,
                    child: Text('自訂…'),
                  ),
                ],
                onChanged:
                    _saving || inUse
                        ? null
                        : (code) {
                          if (code == _customCurrencyOption) {
                            _editCustomCurrency(currency);
                          } else if (code != null) {
                            _changeCurrency(currency, code);
                          }
                        },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextFormField(
            key: ValueKey(('rate', currency.id, currency.label, _base)),
            initialValue: _rates[currency.id],
            enabled: !_saving,
            style: const TextStyle(fontSize: 14),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: fieldDecoration('匯率').copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
            ),
            onChanged:
                (text) => setState(() => _rates[currency.id] = text.trim()),
          ),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 36, height: 48),
          padding: EdgeInsets.zero,
          tooltip: inUse ? '已有帳目使用此貨幣' : '移除貨幣',
          onPressed: _saving || inUse ? null : () => _removeCurrency(currency),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
      ],
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

class _DialogTextController extends StatefulWidget {
  const _DialogTextController({required this.controller, required this.child});

  final TextEditingController controller;
  final Widget child;

  @override
  State<_DialogTextController> createState() => _DialogTextControllerState();
}

class _DialogTextControllerState extends State<_DialogTextController> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
