/// リモートシェルを tmux セッションに載せるための起動コマンドを組み立てる。
///
/// モバイル回線ではアプリの切り替え・電波状況・ネットワーク遷移で SSH が
/// 頻繁に切れる。tmux の中で作業していれば切断してもリモート側のプロセスは
/// 生き続け、再接続時に同じセッションへ戻れる。このアプリでは切断を
/// 「防ぐ」ことはできないため、「切れても失われない」ようにするのが要。
class TmuxSession {
  TmuxSession._();

  /// 常に同じ名前を使うことで、再接続時に既存セッションへ戻れる。
  static const String sessionName = 'k';

  /// 接続直後に送る起動コマンドを返す。
  ///
  /// [command] を渡すとセッション内でそれを実行する（リポジトリを開く場合など）。
  ///
  /// tmux が入っていないサーバーもあるため、存在を確認してから使う。
  /// 無い場合は通常のシェルのままにし、[command] があればそれだけを実行する。
  static String bootstrap({String? command}) {
    if (command == null) {
      return 'command -v tmux >/dev/null 2>&1 '
          '&& tmux new-session -A -s $sessionName';
    }

    // send-keys に渡すため、シングルクォートをエスケープする
    final escaped = command.replaceAll("'", r"'\''");
    return 'if command -v tmux >/dev/null 2>&1; then '
        'tmux new-session -d -s $sessionName 2>/dev/null || true; '
        "tmux send-keys -t $sessionName '$escaped' Enter; "
        'tmux attach-session -t $sessionName; '
        'else $command; fi';
  }
}
