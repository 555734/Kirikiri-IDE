import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/features/terminal/remote_notification_parser.dart';

void main() {
  late RemoteNotificationParser parser;

  setUp(() => parser = RemoteNotificationParser());

  group('OSC 9', () {
    test('本文を取り出す', () {
      final found = parser.feed('\x1b]9;build finished\x07');
      expect(found, hasLength(1));
      expect(found.single.body, 'build finished');
      expect(found.single.title, isNull);
    });

    test('本文が空なら通知しない', () {
      expect(parser.feed('\x1b]9;\x07'), isEmpty);
    });
  });

  group('OSC 777', () {
    test('タイトルと本文を取り出す', () {
      final found = parser.feed('\x1b]777;notify;deploy;succeeded\x07');
      expect(found.single.title, 'deploy');
      expect(found.single.body, 'succeeded');
    });

    test('本文にセミコロンが含まれても失わない', () {
      final found = parser.feed('\x1b]777;notify;test;3 passed; 1 failed\x07');
      expect(found.single.body, '3 passed; 1 failed');
    });

    test('本文が無ければタイトルを本文として扱う', () {
      final found = parser.feed('\x1b]777;notify;done\x07');
      expect(found.single.body, 'done');
    });

    test('notify 以外のサブコマンドは無視する', () {
      expect(parser.feed('\x1b]777;precmd;x\x07'), isEmpty);
    });
  });

  group('終端子', () {
    test('ST (ESC backslash) でも終端できる', () {
      final found = parser.feed('\x1b]9;done\x1b\\');
      expect(found.single.body, 'done');
    });
  });

  group('チャンク境界', () {
    test('シーケンスが2つに分かれても復元する', () {
      expect(parser.feed('\x1b]9;half'), isEmpty);
      final found = parser.feed(' done\x07');
      expect(found.single.body, 'half done');
    });

    test('ESC だけで切れても次のチャンクで復元する', () {
      expect(parser.feed('output\x1b'), isEmpty);
      final found = parser.feed(']9;ok\x07');
      expect(found.single.body, 'ok');
    });

    test('3つに分かれても復元する', () {
      expect(parser.feed('\x1b]77'), isEmpty);
      expect(parser.feed('7;notify;a'), isEmpty);
      final found = parser.feed(';b\x07');
      expect(found.single.title, 'a');
      expect(found.single.body, 'b');
    });
  });

  group('通常の出力', () {
    test('普通のテキストは何も生まない', () {
      expect(parser.feed('\$ ls -la\r\ntotal 8\r\n'), isEmpty);
    });

    test('色指定などの CSI は無視する', () {
      expect(parser.feed('\x1b[31mred\x1b[0m'), isEmpty);
    });

    test('通知以外の OSC（タイトル設定）は無視する', () {
      expect(parser.feed('\x1b]0;user@host\x07'), isEmpty);
    });

    test('前後に出力が混ざっていても拾える', () {
      final found = parser.feed('done.\r\n\x1b]9;ok\x07\$ ');
      expect(found.single.body, 'ok');
    });

    test('1チャンクに複数あればすべて拾う', () {
      final found = parser.feed('\x1b]9;one\x07mid\x1b]9;two\x07');
      expect(found.map((n) => n.body), ['one', 'two']);
    });
  });

  group('暴走防止', () {
    test('終端しない長い OSC は破棄する', () {
      final huge = '\x1b]9;${'x' * (RemoteNotificationParser.maxPendingLength + 10)}';
      expect(parser.feed(huge), isEmpty);
      // 破棄されているので、後続の終端子では通知が出ない
      expect(parser.feed('\x07'), isEmpty);
    });

    test('reset で未完データを捨てる', () {
      parser.feed('\x1b]9;partial');
      parser.reset();
      expect(parser.feed(' rest\x07'), isEmpty);
    });
  });
}
