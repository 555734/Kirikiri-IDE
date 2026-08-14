import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/features/terminal/tmux_session.dart';

void main() {
  group('bootstrap（コマンドなし）', () {
    test('既存セッションがあればアタッチ、なければ作成する', () {
      final cmd = TmuxSession.bootstrap();
      expect(cmd, contains('tmux new-session -A -s ${TmuxSession.sessionName}'));
    });

    test('tmux が無いサーバーでは何もしない', () {
      // 存在確認に失敗したら && の右辺は実行されず、通常のシェルのままになる
      expect(TmuxSession.bootstrap(), startsWith('command -v tmux'));
    });
  });

  group('bootstrap（コマンドあり）', () {
    test('セッションを作ってコマンドを送り込む', () {
      final cmd = TmuxSession.bootstrap(command: 'git pull');
      expect(cmd, contains('tmux new-session -d -s ${TmuxSession.sessionName}'));
      expect(cmd, contains("tmux send-keys -t ${TmuxSession.sessionName} 'git pull' Enter"));
      expect(cmd, contains('tmux attach-session -t ${TmuxSession.sessionName}'));
    });

    test('tmux が無い場合はコマンドだけを実行する', () {
      final cmd = TmuxSession.bootstrap(command: 'git pull');
      expect(cmd, contains('else git pull; fi'));
    });

    test('シングルクォートを含むコマンドをエスケープする', () {
      final cmd = TmuxSession.bootstrap(command: "echo 'hi'");
      // send-keys の引数を閉じてしまわないこと
      expect(cmd, contains(r"""send-keys -t k 'echo '\''hi'\''' Enter"""));
    });
  });
}
