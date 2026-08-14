import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/features/files/remote_file_service.dart';

void main() {
  group('joinPath', () {
    test('通常のディレクトリに連結する', () {
      expect(RemoteFileService.joinPath('/home/user', 'a.txt'),
          '/home/user/a.txt');
    });

    test('末尾のスラッシュを重複させない', () {
      expect(RemoteFileService.joinPath('/', 'a.txt'), '/a.txt');
      expect(RemoteFileService.joinPath('/home/', 'a.txt'), '/home/a.txt');
    });
  });

  group('parentOf', () {
    test('親ディレクトリを返す', () {
      expect(RemoteFileService.parentOf('/home/user/app'), '/home/user');
    });

    test('末尾にスラッシュがあっても正しく遡る', () {
      expect(RemoteFileService.parentOf('/home/user/'), '/home');
    });

    test('第一階層の親はルート', () {
      expect(RemoteFileService.parentOf('/home'), '/');
    });

    test('ルートの親はルート（無限に遡らない）', () {
      expect(RemoteFileService.parentOf('/'), '/');
      expect(RemoteFileService.parentOf(''), '/');
    });
  });

  group('RemoteEntry', () {
    test('ドットで始まる名前は隠しファイル', () {
      const entry = RemoteEntry(
          name: '.gitignore', path: '/x/.gitignore', isDirectory: false);
      expect(entry.isHidden, isTrue);
    });

    test('通常のファイルは隠しファイルではない', () {
      const entry =
          RemoteEntry(name: 'main.dart', path: '/x/main.dart', isDirectory: false);
      expect(entry.isHidden, isFalse);
    });
  });
}
