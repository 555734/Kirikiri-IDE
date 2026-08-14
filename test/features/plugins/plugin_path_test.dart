import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/features/plugins/plugin_service.dart';

void main() {
  final target = Directory('/data/app/kirikiri_plugins/demo');

  group('safeJoin', () {
    test('通常のエントリは配下に解決される', () {
      expect(
        PluginService.safeJoin(target, 'plugin.json'),
        '/data/app/kirikiri_plugins/demo/plugin.json',
      );
      expect(
        PluginService.safeJoin(target, 'server_tools/run.sh'),
        '/data/app/kirikiri_plugins/demo/server_tools/run.sh',
      );
    });

    test('内部の .. は配下に収まる限り許容する', () {
      expect(
        PluginService.safeJoin(target, 'a/../plugin.json'),
        '/data/app/kirikiri_plugins/demo/plugin.json',
      );
    });

    test('親ディレクトリへ抜けるエントリは拒否する', () {
      expect(
        () => PluginService.safeJoin(target, '../evil.json'),
        throwsException,
      );
      expect(
        () => PluginService.safeJoin(target, 'a/../../evil.json'),
        throwsException,
      );
      expect(
        () => PluginService.safeJoin(target, '../../../../etc/passwd'),
        throwsException,
      );
    });

    test('接頭辞が一致するだけの兄弟ディレクトリも拒否する', () {
      expect(
        () => PluginService.safeJoin(target, '../demo-evil/plugin.json'),
        throwsException,
      );
    });
  });
}
