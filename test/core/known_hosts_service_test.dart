import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/core/known_hosts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const host = 'ssh.example.com';
  const port = 6000;
  const keyType = 'ssh-ed25519';

  late KnownHostsService knownHosts;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    knownHosts = KnownHostsService.instance;
    await knownHosts.clear();
  });

  group('formatFingerprint', () {
    test('MD5 ダイジェストを OpenSSH 形式に整形する', () {
      final digest = Uint8List.fromList([0x00, 0x0f, 0xa1, 0xff]);
      expect(
        KnownHostsService.formatFingerprint(digest),
        'MD5:00:0f:a1:ff',
      );
    });

    test('1バイト値をゼロ埋めする', () {
      final digest = Uint8List.fromList([1, 2, 3]);
      expect(KnownHostsService.formatFingerprint(digest), 'MD5:01:02:03');
    });
  });

  group('verify', () {
    test('未登録のホストは unknown', () async {
      expect(
        await knownHosts.verify(host, port, keyType, 'MD5:aa:bb'),
        HostkeyVerdict.unknown,
      );
    });

    test('保存済みの指紋と一致すれば trusted', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      expect(
        await knownHosts.verify(host, port, keyType, 'MD5:aa:bb'),
        HostkeyVerdict.trusted,
      );
    });

    test('指紋が異なれば changed', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      expect(
        await knownHosts.verify(host, port, keyType, 'MD5:cc:dd'),
        HostkeyVerdict.changed,
      );
    });

    test('ポートが違えば別ホストとして扱う', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      expect(
        await knownHosts.verify(host, 22, keyType, 'MD5:aa:bb'),
        HostkeyVerdict.unknown,
      );
    });

    test('鍵種別が違えば changed ではなく unknown', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      expect(
        await knownHosts.verify(host, port, 'ssh-rsa', 'MD5:cc:dd'),
        HostkeyVerdict.unknown,
      );
    });
  });

  group('trust / forget', () {
    test('trust は既存エントリを上書きする', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      await knownHosts.trust(host, port, keyType, 'MD5:cc:dd');
      expect(
        await knownHosts.fingerprintOf(host, port, keyType),
        'MD5:cc:dd',
      );
    });

    test('forget は同一ホストの全鍵種別を削除する', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      await knownHosts.trust(host, port, 'ssh-rsa', 'MD5:cc:dd');
      await knownHosts.trust('other.example.com', port, keyType, 'MD5:ee:ff');

      await knownHosts.forget(host, port);

      expect(await knownHosts.fingerprintOf(host, port, keyType), isNull);
      expect(await knownHosts.fingerprintOf(host, port, 'ssh-rsa'), isNull);
      expect(
        await knownHosts.fingerprintOf('other.example.com', port, keyType),
        'MD5:ee:ff',
      );
    });

    test('保存内容はストレージ経由で復元できる', () async {
      await knownHosts.trust(host, port, keyType, 'MD5:aa:bb');
      final entries = await knownHosts.all();
      expect(entries['$host:$port $keyType'], 'MD5:aa:bb');
    });
  });
}
