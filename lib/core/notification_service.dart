import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// リモートのコマンドが完了したことを端末の通知で知らせる。
///
/// 数分かかる処理を投げてアプリを離れられるようにするためのもので、
/// 通知が来なくてもターミナル自体の動作には影響させない
/// （権限拒否やプラットフォーム側の失敗は握りつぶす）。
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'kirikiri_remote';
  static const String _channelName = 'Remote commands';
  static const String _channelDescription =
      'Notifications sent by commands running on the remote host';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 0;

  /// 通知の初期化と権限要求。複数回呼んでも初回だけ実行される。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _plugin.initialize(
        const InitializationSettings(
          // AndroidManifest が参照しているアイコンに合わせる
          android: AndroidInitializationSettings('@drawable/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // 通知が必要になった時点で許可を求める
            requestAlertPermission: true,
            requestSoundPermission: true,
            requestBadgePermission: false,
          ),
        ),
      );

      if (Platform.isAndroid) {
        // Android 13 以降は実行時の許可が必要
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('通知の初期化に失敗しました（非致命的）: $e');
    }
  }

  /// 通知を表示する。失敗しても例外は投げない。
  Future<void> show({String? title, required String body}) async {
    await init();
    try {
      await _plugin.show(
        _nextId++,
        title ?? 'kirikiri',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('通知の表示に失敗しました（非致命的）: $e');
    }
  }
}
