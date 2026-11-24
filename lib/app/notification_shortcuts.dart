import 'package:flutter/services.dart';

typedef NotificationShortcutStatus = ({bool enabled, bool allowed});

abstract final class NotificationShortcuts {
  static const _channel = MethodChannel(
    'dev.pixelbudget.app/notification_shortcuts',
  );

  static Future<NotificationShortcutStatus> getStatus() => _status('getStatus');

  static Future<NotificationShortcutStatus> setEnabled(bool enabled) =>
      _status('setEnabled', {'enabled': enabled});

  static Future<NotificationShortcutStatus> _status(
    String method, [
    Map<String, Object>? arguments,
  ]) async {
    final status =
        (await _channel.invokeMapMethod<String, bool>(method, arguments))!;
    return (enabled: status['enabled']!, allowed: status['allowed']!);
  }

  static Future<void> openSystemSettings() =>
      _channel.invokeMethod<void>('openSettings');

  static Future<void> listen(void Function(String) onAction) async {
    Future<void> dispatch() async {
      final action = await _channel.invokeMethod<String>('takeAction');
      if (action != null) onAction(action);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'actionAvailable') await dispatch();
    });
    try {
      await dispatch();
    } on MissingPluginException {
      // Shortcuts are optional when the native platform is unavailable.
    }
  }

  static void stopListening() => _channel.setMethodCallHandler(null);
}
