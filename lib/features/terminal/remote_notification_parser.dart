/// リモート側のコマンドが送ってきた通知。
class RemoteNotification {
  const RemoteNotification({this.title, required this.body});

  final String? title;
  final String body;

  @override
  String toString() => 'RemoteNotification(${title ?? ''}: $body)';
}

/// ターミナル出力に含まれる通知用エスケープシーケンスを拾い出す。
///
/// スマホでの AI エージェント利用では、数分かかる処理を投げてアプリを
/// 離れることになる。終わったことを知る手段が無いと画面を見張るしかない。
/// 一般的なターミナルが実装している以下のシーケンスを検出して、
/// ローカル通知に変換する。
///
///   OSC 9   : `ESC ] 9 ; 本文 BEL`
///   OSC 777 : `ESC ] 777 ; notify ; タイトル ; 本文 BEL`
///
/// リモート側では特別なツールを入れなくても printf だけで送れる:
///
///   printf '\033]777;notify;build;done\a'
///
/// 出力は加工しない（xterm は未知の OSC を無視するため、そのまま流してよい）。
class RemoteNotificationParser {
  /// 途中で切れたシーケンスを保持する上限。これを超えたら通知ではないと
  /// 判断して捨てる（画像の転送など、長い OSC を延々と溜め込まないため）。
  static const int maxPendingLength = 2048;

  static const String _esc = '\x1b';
  static const String _oscStart = '\x1b]';
  static const String _bel = '\x07';
  static const String _st = '\x1b\\';

  /// 未完のシーケンス（チャンクの境界をまたいだ分）。
  String _pending = '';

  /// 出力チャンクを与え、その中で完成した通知を返す。
  ///
  /// SSH の読み出し単位は任意なので、1つのシーケンスが複数チャンクに
  /// またがることがある。その場合は次の [feed] で完成する。
  List<RemoteNotification> feed(String chunk) {
    var buffer = _pending + chunk;
    _pending = '';
    final found = <RemoteNotification>[];

    while (true) {
      final start = buffer.indexOf(_oscStart);
      if (start < 0) break;

      // OSC の手前は通常の出力なので捨てる
      buffer = buffer.substring(start);

      final end = _findTerminator(buffer);
      if (end == null) {
        // 未完。長すぎるものは通知ではないとみなす
        if (buffer.length <= maxPendingLength) _pending = buffer;
        return found;
      }

      final payload = buffer.substring(_oscStart.length, end.start);
      final notification = _parse(payload);
      if (notification != null) found.add(notification);

      buffer = buffer.substring(end.end);
    }

    // ESC 単体で終わっている場合、次のチャンクで ']' が続く可能性がある
    if (buffer.endsWith(_esc)) _pending = _esc;
    return found;
  }

  /// 保持中の未完データを捨てる（再接続時など）。
  void reset() => _pending = '';

  static _Terminator? _findTerminator(String buffer) {
    final bel = buffer.indexOf(_bel);
    // ST は ESC \ の2文字。OSC 開始の ESC 自体を拾わないよう2文字目以降を探す
    final st = buffer.indexOf(_st, _oscStart.length);

    if (bel < 0 && st < 0) return null;
    if (st < 0 || (bel >= 0 && bel < st)) {
      return _Terminator(bel, bel + _bel.length);
    }
    return _Terminator(st, st + _st.length);
  }

  static RemoteNotification? _parse(String payload) {
    final parts = payload.split(';');
    if (parts.isEmpty) return null;

    switch (parts.first) {
      case '9':
        final body = parts.skip(1).join(';');
        return body.isEmpty ? null : RemoteNotification(body: body);
      case '777':
        // 777;notify;title;body — body にセミコロンが含まれ得るので結合する
        if (parts.length < 3 || parts[1] != 'notify') return null;
        final title = parts[2];
        final body = parts.length > 3 ? parts.skip(3).join(';') : '';
        if (title.isEmpty && body.isEmpty) return null;
        return RemoteNotification(
          title: title.isEmpty ? null : title,
          body: body.isEmpty ? title : body,
        );
      default:
        return null;
    }
  }
}

class _Terminator {
  const _Terminator(this.start, this.end);

  /// 終端子の開始位置（ペイロードの終わり）。
  final int start;

  /// 終端子の直後（次の走査開始位置）。
  final int end;
}
