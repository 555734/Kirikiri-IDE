import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../terminal/ssh_service.dart';
import '../terminal/tmux_session.dart';

/// リモートのファイル一覧の1項目。
class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int? size;

  bool get isHidden => name.startsWith('.');
}

/// リモートファイルを開けなかった理由。
enum RemoteFileFailureKind {
  /// SSH が繋がっていない
  notConnected,

  /// テキストとして扱えない（バイナリ）
  notText,

  /// 開くには大きすぎる
  tooLarge,

  /// その他（権限・存在しないなど）
  failed,
}

class RemoteFileException implements Exception {
  const RemoteFileException(this.kind, {this.detail});

  final RemoteFileFailureKind kind;
  final String? detail;

  @override
  String toString() => 'RemoteFileException(${kind.name})';
}

/// SSH の SFTP サブシステム経由でリモートの作業ツリーを読み書きする。
///
/// GitHub API 経由の編集はコミット済みの内容しか触れないため、ターミナルで
/// 作業中のファイルとは別物になる。こちらはターミナルが見ているのと同じ
/// 作業ツリーを直接編集する。
class RemoteFileService {
  RemoteFileService({required this.sshService});

  final SshService sshService;

  /// エディタで開くファイルサイズの上限。これを超えるものはスマホの
  /// テキスト入力で扱える範囲を明らかに超えている。
  static const int maxEditableBytes = 512 * 1024;

  SftpClient? _sftp;

  Future<SftpClient> _open() async {
    final existing = _sftp;
    if (existing != null) return existing;

    final client = sshService.rawClient;
    if (client == null) {
      throw const RemoteFileException(RemoteFileFailureKind.notConnected);
    }
    return _sftp = await client.sftp();
  }

  /// ブラウズを開始するディレクトリ。
  ///
  /// tmux のペインが今いるディレクトリを優先する。ターミナルで `cd` した先を
  /// そのまま開けるほうが、ホームから辿り直すより圧倒的に早い。
  Future<String> startDirectory() async {
    final client = sshService.rawClient;
    if (client == null) {
      throw const RemoteFileException(RemoteFileFailureKind.notConnected);
    }

    try {
      final result = await client.run(
        'tmux display-message -p -t ${TmuxSession.sessionName} '
        "-F '#{pane_current_path}' 2>/dev/null || printf %s \"\$HOME\"",
      );
      final path = utf8.decode(result, allowMalformed: true).trim();
      if (path.startsWith('/')) return path;
    } catch (_) {
      // tmux が無い場合などはホームへフォールバックする
    }

    try {
      final home = await client.run(r'printf %s "$HOME"');
      final path = utf8.decode(home, allowMalformed: true).trim();
      if (path.startsWith('/')) return path;
    } catch (_) {
      // 取得できなければルートから辿ってもらう
    }
    return '/';
  }

  /// ディレクトリの内容を返す。ディレクトリを先、その中で名前順に並べる。
  Future<List<RemoteEntry>> list(String path) async {
    final sftp = await _open();
    final List<SftpName> names;
    try {
      names = await sftp.listdir(path);
    } catch (e) {
      throw RemoteFileException(RemoteFileFailureKind.failed,
          detail: e.toString());
    }

    final entries = <RemoteEntry>[];
    for (final name in names) {
      if (name.filename == '.' || name.filename == '..') continue;
      entries.add(RemoteEntry(
        name: name.filename,
        path: joinPath(path, name.filename),
        isDirectory: name.attr.isDirectory,
        size: name.attr.size,
      ));
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// テキストファイルとして読み込む。
  ///
  /// バイナリや巨大なファイルはエディタで開いても意味がないため弾く。
  Future<String> readText(String path) async {
    final sftp = await _open();

    final SftpFile file;
    try {
      file = await sftp.open(path);
    } catch (e) {
      throw RemoteFileException(RemoteFileFailureKind.failed,
          detail: e.toString());
    }

    try {
      final stat = await file.stat();
      final size = stat.size;
      if (size != null && size > maxEditableBytes) {
        throw const RemoteFileException(RemoteFileFailureKind.tooLarge);
      }

      final bytes = await file.readBytes();
      if (_looksBinary(bytes)) {
        throw const RemoteFileException(RemoteFileFailureKind.notText);
      }
      try {
        return utf8.decode(bytes);
      } on FormatException {
        throw const RemoteFileException(RemoteFileFailureKind.notText);
      }
    } finally {
      await file.close();
    }
  }

  /// テキストファイルとして書き込む（既存の内容は置き換える）。
  Future<void> writeText(String path, String content) async {
    final sftp = await _open();
    try {
      final file = await sftp.open(
        path,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      await file.write(Stream.value(Uint8List.fromList(utf8.encode(content))));
      await file.close();
    } on RemoteFileException {
      rethrow;
    } catch (e) {
      throw RemoteFileException(RemoteFileFailureKind.failed,
          detail: e.toString());
    }
  }

  /// NUL バイトを含むものはテキストとして扱わない（file(1) と同じ判定）。
  static bool _looksBinary(Uint8List bytes) {
    final limit = bytes.length < 8000 ? bytes.length : 8000;
    for (var i = 0; i < limit; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  /// パスを連結する。`/` の重複と末尾の `/` を作らない。
  static String joinPath(String dir, String name) {
    if (dir.endsWith('/')) return '$dir$name';
    return '$dir/$name';
  }

  /// 親ディレクトリ。ルートの親はルート。
  static String parentOf(String path) {
    if (path == '/' || path.isEmpty) return '/';
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final index = trimmed.lastIndexOf('/');
    if (index <= 0) return '/';
    return trimmed.substring(0, index);
  }

  void dispose() {
    _sftp?.close();
    _sftp = null;
  }
}
