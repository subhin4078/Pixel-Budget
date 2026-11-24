import 'package:flutter/material.dart';
import '../../ledger/category_icons.dart';
import '../../ledger/ledger_controller.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';

Future<LedgerCategory?> manageCategories(
  BuildContext context,
  LedgerController controller,
  EntryType initialType,
) => Navigator.of(context).push<LedgerCategory>(
  MaterialPageRoute(
    builder:
        (_) => _CategoryIconsPage(
          controller: controller,
          initialType: initialType,
        ),
  ),
);

class _CategoryIconsPage extends StatefulWidget {
  const _CategoryIconsPage({
    required this.controller,
    required this.initialType,
  });
  final LedgerController controller;
  final EntryType initialType;
  @override
  State<_CategoryIconsPage> createState() => _CategoryIconsPageState();
}

class _CategoryIconsPageState extends State<_CategoryIconsPage> {
  int _groupIndex = 0;
  Future<void> _choose(
    CategoryIcon icon,
    int colorValue, [
    LedgerCategory? category,
  ]) async {
    final matches =
        widget.controller.categories
            .where((item) => item.icon == icon.name)
            .toList();
    if (category == null && matches.length > 1) {
      category = await showDialog<LedgerCategory>(
        context: context,
        builder:
            (context) => SimpleDialog(
              title: const Text('選擇要修改的種類'),
              children: [
                for (final item in matches)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, item),
                    child: Text(
                      '${item.label} · ${item.type == EntryType.income ? '收入' : '支出'}',
                    ),
                  ),
              ],
            ),
      );
      if (category == null || !mounted) return;
    }
    category ??= matches.firstOrNull;
    final saved = await Navigator.of(context).push<LedgerCategory>(
      MaterialPageRoute(
        builder:
            (_) => _CategoryDetailsPage(
              controller: widget.controller,
              icon: icon,
              colorValue: colorValue,
              category: category,
              initialType: widget.initialType,
            ),
      ),
    );
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final group = _groupIndex == 0 ? null : categoryIconGroups[_groupIndex - 1];
    final choices =
        group == null
            ? [
              for (final category in widget.controller.categories)
                (
                  icon: CategoryIcon(category.icon, category.label),
                  color: category.colorValue,
                  category: category,
                ),
            ]
            : [
              for (final icon in group.icons)
                (
                  icon: icon,
                  color: group.colorValue,
                  category: null as LedgerCategory?,
                ),
            ];
    return Scaffold(
      appBar: AppBar(title: const Text('修改種類')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  for (var i = 0; i <= categoryIconGroups.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          i == 0 ? '目前種類' : categoryIconGroups[i - 1].label,
                        ),
                        selected: i == _groupIndex,
                        onSelected: (_) => setState(() => _groupIndex = i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: choices.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 104,
                  mainAxisExtent: 110,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  final checked =
                      choice.category?.visible ??
                      widget.controller.categories.any(
                        (category) =>
                            category.icon == choice.icon.name &&
                            category.visible,
                      );
                  return _IconTile(
                    icon: choice.icon,
                    colorValue: choice.color,
                    checked: checked,
                    onTap:
                        () =>
                            _choose(choice.icon, choice.color, choice.category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.colorValue,
    required this.checked,
    required this.onTap,
  });
  final CategoryIcon icon;
  final int colorValue;
  final bool checked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: icon.label,
    checked: checked,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconBadge(icon.name, color: Color(colorValue), size: 56),
              if (checked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.income,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Palette.card,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            icon.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _CategoryDetailsPage extends StatefulWidget {
  const _CategoryDetailsPage({
    required this.controller,
    required this.icon,
    required this.colorValue,
    required this.initialType,
    this.category,
  });
  final LedgerController controller;
  final CategoryIcon icon;
  final int colorValue;
  final EntryType initialType;
  final LedgerCategory? category;
  @override
  State<_CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<_CategoryDetailsPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.label ?? '');
  late EntryType _type = widget.category?.type ?? widget.initialType;
  late ExpensePurpose _purpose =
      widget.category?.purpose ?? ExpensePurpose.self;
  late bool _visible = widget.category?.visible ?? true;
  late CategoryIcon _icon =
      widget.category == null
          ? widget.icon
          : CategoryIcon(widget.category!.icon, widget.category!.label);
  late int _colorValue = widget.category?.colorValue ?? widget.colorValue;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _changeIcon() async {
    final options = [
      for (final group in categoryIconGroups)
        for (final icon in group.icons) (icon, group.colorValue),
    ];
    final selected = await showDialog<(CategoryIcon, int)>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('更換圖示'),
            content: SizedBox(
              width: 360,
              height: 400,
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  mainAxisExtent: 104,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemBuilder:
                    (_, index) => _IconTile(
                      icon: options[index].$1,
                      colorValue: options[index].$2,
                      checked: options[index].$1.name == _icon.name,
                      onTap: () => Navigator.pop(context, options[index]),
                    ),
              ),
            ),
          ),
    );
    if (selected != null && mounted) {
      setState(() {
        _icon = selected.$1;
        _colorValue = selected.$2;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final category = await widget.controller.saveCategory(
        original: widget.category,
        label: _name.text,
        icon: _icon.name,
        colorValue: _colorValue,
        purpose: _purpose,
        type: _type,
        visible: _visible,
      );
      if (mounted) Navigator.pop(context, category);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(BudgetSnackBar(content: Text(saveErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inUse =
        widget.category != null &&
        widget.controller.categoryInUse(widget.category!);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.category == null ? '新增種類' : '編輯種類'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const CuteIcon('chevron-left'),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: TextButton(
                        onPressed: _changeIcon,
                        child: Column(
                          children: [
                            IconBadge(
                              _icon.name,
                              color: Color(_colorValue),
                              size: 64,
                            ),
                            const SizedBox(height: 6),
                            const Text('更換圖示'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: fieldDecoration(
                        '種類名稱',
                      ).copyWith(labelText: '種類名稱'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入種類名稱';
                        }
                        if (widget.controller.categoryNameExists(
                          value,
                          _type,
                          except: widget.category?.name,
                        )) {
                          return '已有同名的${_type == EntryType.income ? '收入' : '支出'}種類';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    TypeSwitch(
                      labels: const ['支出', '收入'],
                      selected: _type.index,
                      onSelected:
                          _saving || inUse
                              ? null
                              : (index) => setState(
                                () => _type = EntryType.values[index],
                              ),
                    ),
                    if (inUse)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '已有帳目使用此種類，收支類型已固定。',
                          style: TextStyle(
                            color: Palette.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_type == EntryType.expense) ...[
                      const SizedBox(height: 24),
                      const Text('用途'),
                      const SizedBox(height: 10),
                      TypeSwitch(
                        labels: [
                          for (final purpose in ExpensePurpose.values)
                            purpose.label,
                        ],
                        selected: _purpose.index,
                        onSelected:
                            _saving
                                ? null
                                : (index) => setState(
                                  () => _purpose = ExpensePurpose.values[index],
                                ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('在記帳選單顯示'),
                      value: _visible,
                      onChanged:
                          _saving
                              ? null
                              : (value) => setState(() => _visible = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: FormSaveBar(
          label: '儲存',
          saving: _saving,
          onSave: _save,
        ),
      ),
    );
  }
}
