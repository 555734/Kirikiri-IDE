import '../terminal/ssh_service.dart';
import 'loaded_plugin.dart';
import 'sftp_service.dart';

/// Type 3 TUIプラグインを起動するオーケストレーター。
///
/// 処理フロー:
///   1. plugin の server_tools/ を SFTP で Cloud Shell に転送
///   2. エントリースクリプトに chmod +x を付与
///   3. SSH経由でそのスクリプトを起動（現在のターミナルセッション上）
class TuiLauncher {
  TuiLauncher({required this.sshService});

  final SshService sshService;
  SftpService? _sftp;

  Future<void> launch({
    required LoadedPlugin plugin,
    required String entryScript,
    void Function(double progress)? onUploadProgress,
  }) async {
    if (!plugin.hasTui) {
      throw Exception(
          'このプラグインにはserver_tools/がありません');
    }

    _sftp ??= SftpService(sshService: sshService);

    final localToolsPath = '${plugin.directory.path}/server_tools';
    final remotePath =
        '.kirikiri/plugins/${plugin.manifest.id}';

    // アップロード
    await _sftp!.uploadDirectory(
      localPath: localToolsPath,
      remotePath: remotePath,
      onProgress: onUploadProgress,
    );

    // 起動
    sshService.write(
      'chmod +x ~/$remotePath/$entryScript && '
      '~/$remotePath/$entryScript\n',
    );
  }

  void dispose() {
    _sftp?.dispose();
  }
}
