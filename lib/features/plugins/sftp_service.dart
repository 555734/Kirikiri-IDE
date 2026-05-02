import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../terminal/ssh_service.dart';

/// dartssh2 の SftpClient を使ったファイル転送サービス。
/// Type 3 TUIプラグインのサーバーツールをCloud Shellにアップロードする。
class SftpService {
  SftpService({required this.sshService});

  final SshService sshService;
  SftpClient? _sftp;

  // ── SFTPクライアント取得 ──────────────────────────────

  Future<SftpClient> _getOrOpen() async {
    if (_sftp != null) return _sftp!;
    final client = sshService.rawClient;
    if (client == null) throw Exception('SSH未接続です');
    _sftp = await client.sftp();
    return _sftp!;
  }

  // ── ディレクトリ再帰アップロード ──────────────────────

  Future<void> uploadDirectory({
    required String localPath,
    required String remotePath,
    void Function(double progress)? onProgress,
  }) async {
    final localDir = Directory(localPath);
    if (!await localDir.exists()) {
      throw Exception('ローカルディレクトリが見つかりません: $localPath');
    }

    final files = await localDir
        .list(recursive: true)
        .where((e) => e is File)
        .cast<File>()
        .toList();

    if (files.isEmpty) return;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final relative = file.path
          .substring(localPath.length)
          .replaceAll(r'\', '/');
      final remote = '$remotePath$relative';
      await uploadFile(localPath: file.path, remotePath: remote);
      onProgress?.call((i + 1) / files.length);
    }
  }

  // ── 単一ファイルアップロード ──────────────────────────

  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    final sftp = await _getOrOpen();
    await ensureRemoteDir(remotePath.substring(
        0, remotePath.lastIndexOf('/')));

    final localFile = File(localPath);
    final bytes = await localFile.readAsBytes();

    final remoteFile = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await remoteFile.write(Stream.value(bytes));
    await remoteFile.close();
  }

  // ── リモートディレクトリ作成（mkdir -p相当）──────────

  Future<void> ensureRemoteDir(String remotePath) async {
    final sftp = await _getOrOpen();
    final parts = remotePath.split('/').where((s) => s.isNotEmpty);
    var current = '';
    for (final part in parts) {
      current = '$current/$part';
      try {
        await sftp.mkdir(current);
      } catch (_) {
        // 既に存在する場合は無視
      }
    }
  }

  void dispose() {
    _sftp?.close();
    _sftp = null;
  }
}
