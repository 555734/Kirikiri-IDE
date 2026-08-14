import 'ssh_service.dart';

/// 自動再接続してよいかを判断する。
///
/// モバイルでは通信の切り替わりやアプリの再開で接続が切れるため、
/// 復帰時に自動で繋ぎ直したい。ただし「繋ぎ直しても直らない失敗」や
/// 「繋ぎ直してはいけない失敗」があるため、無条件に再試行してはならない。
///
/// - ホスト鍵まわりの失敗: 中間者攻撃の可能性を利用者が判断した結果なので、
///   自動で再試行するとダイアログを繰り返し出すことになる。絶対に再接続しない。
/// - 認証の失敗: 資格情報が変わらない限り何度試しても失敗する。
/// - 利用者自身による切断: 意図した操作なので勝手に繋ぎ直さない。
class ReconnectPolicy {
  ReconnectPolicy({this.maxAttempts = 5});

  /// 連続で何回まで自動再接続を試みるか。
  /// これを超えたら利用者の操作を待つ（再接続ボタン）。
  final int maxAttempts;

  bool _allowed = true;
  int _attempts = 0;

  /// 自動再接続してよいか。
  bool get isAllowed => _allowed && _attempts < maxAttempts;

  int get attempts => _attempts;

  /// 利用者が明示的に接続・再接続した。自動再接続を再び有効にする。
  void onUserConnect() {
    _allowed = true;
    _attempts = 0;
  }

  /// 利用者が明示的に切断した。以後は自動で繋ぎ直さない。
  void onUserDisconnect() {
    _allowed = false;
  }

  /// 接続に成功した。試行回数をリセットする。
  void onConnected() {
    _allowed = true;
    _attempts = 0;
  }

  /// 自動再接続を1回試みた。
  void onAttempt() {
    _attempts++;
  }

  /// 接続が失敗した。再試行しても無意味・危険な種別なら以後を禁止する。
  void onFailure(SshFailureKind kind) {
    switch (kind) {
      case SshFailureKind.hostkeyUnconfirmed:
      case SshFailureKind.hostkeyChanged:
      case SshFailureKind.hostkeyRejected:
      case SshFailureKind.hostkeyInvalid:
      case SshFailureKind.authFailed:
      case SshFailureKind.authRejected:
        _allowed = false;
      case SshFailureKind.connectionFailed:
        // 通信断が原因の可能性が高いので再試行の余地を残す
        break;
    }
  }
}
