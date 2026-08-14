import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirikiri/features/github/github_service.dart';

GitHubRepo _repo({bool isPrivate = false}) => GitHubRepo(
      name: 'my-app',
      owner: 'octocat',
      cloneUrl: 'https://github.com/octocat/my-app.git',
      isPrivate: isPrivate,
      defaultBranch: 'main',
      updatedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GitHubService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = GitHubService();
    service.setPatForTesting('ghp_exampletokenvalue1234567890');
  });

  test('PAT を保持していても clone URL に埋め込まない', () {
    expect(service.isAuthenticated, isTrue);
    expect(service.cloneUrl(_repo(isPrivate: true)),
        'https://github.com/octocat/my-app.git');
  });

  test('private リポジトリのコマンドに PAT が含まれない', () {
    final cmd = service.buildShellCommand(_repo(isPrivate: true));
    expect(cmd, isNot(contains('ghp_')));
    expect(cmd, isNot(contains('@github.com')));
    expect(cmd, contains('git clone "https://github.com/octocat/my-app.git"'));
  });

  test('既存の clone は pull 前に remote URL を資格情報なしへ戻す', () {
    final cmd = service.buildShellCommand(_repo(isPrivate: true));
    expect(
      cmd,
      contains(
          'git remote set-url origin "https://github.com/octocat/my-app.git"'),
    );
  });

  test('デフォルト以外のブランチは switch する', () {
    final cmd = service.buildShellCommand(_repo(), branch: 'develop');
    expect(cmd, contains('git switch "develop"'));
  });

  test('デフォルトブランチでは switch しない', () {
    final cmd = service.buildShellCommand(_repo(), branch: 'main');
    expect(cmd, isNot(contains('git switch')));
  });
}
