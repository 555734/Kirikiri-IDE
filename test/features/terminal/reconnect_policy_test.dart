import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/features/terminal/reconnect_policy.dart';
import 'package:kirikiri/features/terminal/ssh_service.dart';

void main() {
  late ReconnectPolicy policy;

  setUp(() => policy = ReconnectPolicy(maxAttempts: 3));

  test('初期状態では自動再接続してよい', () {
    expect(policy.isAllowed, isTrue);
  });

  group('再接続してはいけない失敗', () {
    // ホスト鍵の警告を無視して繰り返し接続を試みると、利用者が「接続しない」と
    // 判断した意味が失われ、ダイアログを連打させることになる。
    for (final kind in [
      SshFailureKind.hostkeyChanged,
      SshFailureKind.hostkeyRejected,
      SshFailureKind.hostkeyUnconfirmed,
      SshFailureKind.hostkeyInvalid,
    ]) {
      test('$kind のあとは自動再接続しない', () {
        policy.onFailure(kind);
        expect(policy.isAllowed, isFalse);
      });
    }

    // 資格情報が変わらない限り何度試しても失敗する
    for (final kind in [
      SshFailureKind.authFailed,
      SshFailureKind.authRejected,
    ]) {
      test('$kind のあとは自動再接続しない', () {
        policy.onFailure(kind);
        expect(policy.isAllowed, isFalse);
      });
    }
  });

  test('通信断は再試行の余地を残す', () {
    policy.onFailure(SshFailureKind.connectionFailed);
    expect(policy.isAllowed, isTrue);
  });

  test('利用者による切断のあとは自動再接続しない', () {
    policy.onUserDisconnect();
    expect(policy.isAllowed, isFalse);
  });

  test('利用者が接続し直せば再び有効になる', () {
    policy.onFailure(SshFailureKind.hostkeyChanged);
    expect(policy.isAllowed, isFalse);

    policy.onUserConnect();
    expect(policy.isAllowed, isTrue);
  });

  group('試行回数の上限', () {
    test('上限に達したら止まる', () {
      for (var i = 0; i < 3; i++) {
        expect(policy.isAllowed, isTrue);
        policy.onAttempt();
      }
      expect(policy.isAllowed, isFalse);
    });

    test('接続に成功したらリセットされる', () {
      policy.onAttempt();
      policy.onAttempt();
      policy.onConnected();
      expect(policy.attempts, 0);
      expect(policy.isAllowed, isTrue);
    });

    test('利用者の操作でもリセットされる', () {
      policy.onAttempt();
      policy.onAttempt();
      policy.onAttempt();
      expect(policy.isAllowed, isFalse);

      policy.onUserConnect();
      expect(policy.isAllowed, isTrue);
    });
  });
}
