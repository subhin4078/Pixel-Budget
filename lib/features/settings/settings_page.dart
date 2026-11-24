import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/csv_backup.dart';
import '../../app/csv_backup_repository.dart';
import '../../app/csv_documents.dart';
import '../../app/notification_shortcuts.dart';
import '../../ledger/ledger_controller.dart';
import '../../ledger/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/budget_widgets.dart';
import '../../shared/widgets/scene_page.dart';
import '../../travel/travel_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.ledger, required this.travel});
  final LedgerController ledger;
  final TravelController travel;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _enabled = false;
  bool _busy = true;
  bool _permissionNeeded = false;
  String? _error;
  bool _transferring = false;
  static const _fallbackVersion = '1.1.0';
  late final _backup = CsvBackupRepository(widget.ledger.repository.database);
  late final Future<String> _version = _loadVersion();

  Future<String> _loadVersion() async {
    try {
      final version = await const MethodChannel(
        'dev.pixelbudget.app/info',
      ).invokeMethod<String>('getVersion').timeout(const Duration(seconds: 2));
      if (version != null && version.trim().isNotEmpty) return version.trim();
    } catch (_) {}
    return _fallbackVersion;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && !_transferring) _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final status = await NotificationShortcuts.getStatus();
      if (!mounted) return;
      setState(() {
        _enabled = status.enabled;
        _permissionNeeded = status.enabled && !status.allowed;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '未能讀取設定，請再試一次。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _busy = true);
    try {
      final status = await NotificationShortcuts.setEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _enabled = status.enabled;
        _permissionNeeded = enabled && !status.allowed;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const BudgetSnackBar(content: Text('未能更新設定，請再試一次。')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(BudgetSnackBar(content: Text(message)));
  }

  Future<void> _exportCsv() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    try {
      final data = await _backup.read();
      final bytes = await compute(encodeCsvBackup, data);
      if (!mounted) return;
      final now = DateTime.now();
      final name =
          '像素記帳-${dateKey(now)}-${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}.csv';
      if (await CsvDocuments.save(name, bytes) == true) {
        _message(
          'CSV 已匯出：${data.entries.length} 筆個人帳目、${data.trips.length} 個旅程。',
        );
      }
    } catch (_) {
      _message('未能匯出 CSV，請再試一次。');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _importCsv() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    try {
      final bytes = await CsvDocuments.open();
      if (bytes == null || !mounted) return;
      final data = await compute(decodeCsvBackup, bytes);
      final plan = await _backup.preview(data);
      if (!mounted) return;
      if (plan.isEmpty) {
        _message('資料已存在，無需重複匯入。');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('匯入 CSV'),
              content: SingleChildScrollView(
                child: Text(
                  '新增個人帳目：${plan.entries.length} 筆\n'
                  '新增自訂種類：${plan.categories.length} 個\n'
                  '新增旅程：${plan.trips.length} 個\n'
                  '新增旅程帳目：${plan.tripEntries.length} 筆\n\n'
                  '略過已存在資料：${plan.skippedEntries} 筆個人帳目、${plan.skippedTrips} 個旅程。\n\n'
                  '內容不同的旅程會另行新增，現有資料不會被覆蓋。',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('匯入'),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted) return;
      final imported = await _backup.importData(data);
      await Future.wait([
        widget.ledger.initialize(),
        widget.travel.initialize(),
      ]);
      if (widget.ledger.error != null || widget.travel.error != null) {
        _message('資料已匯入，重新整理未完成，請重新開啟 App。');
        return;
      }
      _message(
        '匯入完成：${imported.entries.length} 筆個人帳目、${imported.trips.length} 個旅程。',
      );
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('未能完成匯入，請重新開啟 App 後再檢查。');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_transferring,
    child: Scaffold(
      body: ScenePage(
        kind: SceneKind.settings,
        title: '設定',
        leading: SceneIconButton(
          tooltip: '返回',
          showBackground: false,
          onPressed: () {
            if (!_transferring) Navigator.pop(context);
          },
          icon: const CuteIcon('chevron-left', size: 24),
        ),
        contentTop: 310,
        bottomInset: 24,
        body:
            (context, s) => [
              GlassCard(
                padding: EdgeInsets.zero,
                child:
                    _error != null
                        ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: EmptyNotice(
                            _error!,
                            action: '再試一次',
                            onAction: _load,
                          ),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: const Text(
                                '通知欄快捷記帳',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text('在通知欄直接開啟首頁、新增收入或支出。'),
                              ),
                              value: _enabled,
                              onChanged:
                                  _busy || _transferring ? null : _setEnabled,
                            ),
                            if (_permissionNeeded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '請允許像素記帳的通知，才能顯示快捷列。',
                                      style: TextStyle(
                                        color: Palette.secondary,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          _transferring
                                              ? null
                                              : NotificationShortcuts
                                                  .openSystemSettings,
                                      child: const Text('開啟通知權限設定'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'CSV 匯入／匯出',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '包含個人帳本、種類、旅程與分帳資料。',
                      style: TextStyle(color: Palette.secondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: _transferring ? null : _exportCsv,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Palette.expense,
                            side: const BorderSide(color: Palette.muted),
                          ),
                          child: const Text('匯出 CSV'),
                        ),
                        FilledButton(
                          onPressed: _transferring ? null : _importCsv,
                          child: const Text('匯入 CSV'),
                        ),
                      ],
                    ),
                    if (_transferring)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: LinearProgressIndicator(
                          semanticsLabel: '正在處理 CSV 資料',
                        ),
                      ),
                  ],
                ),
              ),
              FutureBuilder<String>(
                future: _version,
                builder:
                    (context, snapshot) =>
                        snapshot.hasData
                            ? Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                'v${snapshot.data}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Palette.muted,
                                ),
                              ),
                            )
                            : const SizedBox.shrink(),
              ),
            ],
      ),
    ),
  );
}
