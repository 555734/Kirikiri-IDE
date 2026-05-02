import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// フォアグラウンドサービスのコールバック（トップレベル関数必須）
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

// SSH 接続中はプロセスを生かし続けるだけのハンドラ
class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// SSH セッション用フォアグラウンドサービス（Android のみ）
///
/// 仕組み:
///   - SSH 接続確立時に startService() → 常駐通知が表示される
///   - OS がプロセスを強制終了しなくなる
///   - WiFi/CPU ロックで通信が維持される
///   - SSH 切断時に stop() → 通知が消える
///
/// iOS: バックグラウンド実行の制限が厳しく非対応
///   短時間の切れ目が発生する可能性あり
abstract final class SshForegroundService {
  static bool _initialized = false;

  static void init() {
    if (kIsWeb || !Platform.isAndroid) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kirikiri_ssh_session',
        channelName: 'SSH セッション',
        channelDescription: 'SSH接続をバックグラウンドで維持します',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,  // CPU スリープを防ぐ
        allowWifiLock: true,  // WiFi スリープを防ぐ（SSH 維持に重要）
      ),
    );
    _initialized = true;
  }

  static Future<void> start({
    required String label,
    required String hostInfo,
  }) async {
    if (kIsWeb || !Platform.isAndroid || !_initialized) return;
    if (await FlutterForegroundTask.isRunningService) {
      // 既に起動中なら通知だけ更新
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SSH: $label',
        notificationText: hostInfo,
      );
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'SSH: $label',
      notificationText: hostInfo,
      callback: _foregroundTaskCallback,
    );
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid || !_initialized) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
