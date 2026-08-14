import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

/// GitHub PAT をリモートホストの git に渡すためのヘルパー。
///
/// PAT を clone URL（`https://token@github.com/...`）に埋め込むと、
///   - clone 先の `.git/config` に平文で永続化される
///   - コマンドとしてターミナルに表示され、スクロールバックに残る
///   - シェル履歴（`~/.bash_history`）に残る
/// という三重の漏洩が起きる。
///
/// ここでは PTY を使わない別の exec チャネルで `git credential approve` に
/// 標準入力経由で資格情報を渡す。ターミナルには一切出力されず、履歴にも
/// 残らず、保存先は期限付きのメモリキャッシュ（git credential-cache）となる。
class GitCredentials {
  GitCredentials._();

  /// 資格情報をキャッシュに保持する時間。
  static const Duration cacheTimeout = Duration(hours: 8);

  static const String _host = 'github.com';

  /// GitHub 用の資格情報をリモートの git credential cache に登録する。
  ///
  /// 失敗した場合は [GitCredentialsException] を投げる。呼び出し側は
  /// 接続自体を中断せず、警告として扱うこと。
  static Future<void> provision(SSHClient client, String pat) async {
    if (pat.isEmpty) return;

    // credential-cache はソケット経由のメモリ内キャッシュ。ディスクには残らない。
    await _run(
      client,
      "git config --global credential.helper "
      "'cache --timeout=${cacheTimeout.inSeconds}'",
    );

    // PAT はコマンドライン引数ではなく標準入力で渡す
    // （リモートの ps 出力にも現れない）
    final session = await client.execute('git credential approve');
    session.stdin.add(utf8.encode(
      'protocol=https\n'
      'host=$_host\n'
      'username=x-access-token\n'
      'password=$pat\n'
      '\n',
    ));
    await session.stdin.close();
    await session.done;

    if (session.exitCode != null && session.exitCode != 0) {
      throw GitCredentialsException(
        'git credential approve が終了コード ${session.exitCode} で失敗しました',
      );
    }
  }

  static Future<void> _run(SSHClient client, String command) async {
    final session = await client.execute(command);
    await session.stdin.close();
    await session.done;
    if (session.exitCode != null && session.exitCode != 0) {
      throw GitCredentialsException(
        'コマンドが終了コード ${session.exitCode} で失敗しました: $command',
      );
    }
  }
}

class GitCredentialsException implements Exception {
  GitCredentialsException(this.message);
  final String message;

  @override
  String toString() => 'GitCredentialsException: $message';
}
