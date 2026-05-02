import 'dart:io';
import 'plugin_manifest.dart';

/// インストール済みプラグインの実行時ラッパー
class LoadedPlugin {
  const LoadedPlugin({
    required this.manifest,
    required this.directory,
    required this.isEnabled,
  });

  final PluginManifest manifest;
  final Directory directory;
  final bool isEnabled;

  bool get hasJs =>
      File('${directory.path}/main.js').existsSync();

  bool get hasTui =>
      Directory('${directory.path}/server_tools').existsSync();

  Future<String?> readJsSource() async {
    final f = File('${directory.path}/main.js');
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  Future<List<FileSystemEntity>> listServerTools() async {
    final dir = Directory('${directory.path}/server_tools');
    if (!await dir.exists()) return [];
    return dir.list().toList();
  }

  LoadedPlugin copyWith({bool? isEnabled}) => LoadedPlugin(
        manifest: manifest,
        directory: directory,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}
