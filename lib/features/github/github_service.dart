import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/github_cache.dart';
import '../../core/secure_storage_service.dart';

// ── モデル ────────────────────────────────────────────────

class GitHubRepo {
  const GitHubRepo({
    required this.name,
    required this.owner,
    this.description,
    required this.cloneUrl,
    required this.isPrivate,
    required this.defaultBranch,
    required this.updatedAt,
  });

  final String name;
  final String owner;
  final String? description;
  final String cloneUrl;
  final bool isPrivate;
  final String defaultBranch;
  final DateTime updatedAt;

  String get fullName => '$owner/$name';

  factory GitHubRepo.fromJson(Map<String, dynamic> j) => GitHubRepo(
        name: j['name'] as String,
        owner: (j['owner'] as Map<String, dynamic>)['login'] as String,
        description: j['description'] as String?,
        cloneUrl: j['clone_url'] as String,
        isPrivate: j['private'] as bool,
        defaultBranch: j['default_branch'] as String? ?? 'main',
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class GitHubFile {
  const GitHubFile({
    required this.path,
    required this.type,
    this.sha,
    this.size,
  });

  final String path;
  final String type; // 'blob' | 'tree'
  final String? sha;
  final int? size;

  String get name => path.split('/').last;
  bool get isFile => type == 'blob';
  bool get isDir => type == 'tree';
  int get depth => path.split('/').length - 1;

  factory GitHubFile.fromJson(Map<String, dynamic> j) => GitHubFile(
        path: j['path'] as String,
        type: j['type'] as String,
        sha: j['sha'] as String?,
        size: j['size'] as int?,
      );
}

class GitHubFileContent {
  const GitHubFileContent({
    required this.path,
    required this.content,
    required this.sha,
  });

  final String path;
  final String content;
  final String sha;

  String get name => path.split('/').last;

  factory GitHubFileContent.fromJson(Map<String, dynamic> j) {
    final encoded = (j['content'] as String).replaceAll('\n', '');
    final decoded = utf8.decode(base64.decode(encoded));
    return GitHubFileContent(
      path: j['path'] as String,
      content: decoded,
      sha: j['sha'] as String,
    );
  }
}

// ── Branch / PR モデル ────────────────────────────────────

class GitHubBranch {
  const GitHubBranch({
    required this.name,
    required this.sha,
    required this.isProtected,
  });

  final String name;
  final String sha;
  final bool isProtected;

  factory GitHubBranch.fromJson(Map<String, dynamic> j) => GitHubBranch(
        name: j['name'] as String,
        sha:
            ((j['commit'] as Map<String, dynamic>)['sha']) as String,
        isProtected: (j['protected'] as bool?) ?? false,
      );
}

class PullRequest {
  const PullRequest({
    required this.number,
    required this.title,
    this.body,
    required this.state,
    required this.user,
    required this.headRef,
    required this.baseRef,
    required this.createdAt,
    this.mergedAt,
    required this.isDraft,
    required this.htmlUrl,
  });

  final int number;
  final String title;
  final String? body;
  final String state;
  final String user;
  final String headRef;
  final String baseRef;
  final DateTime createdAt;
  final DateTime? mergedAt;
  final bool isDraft;
  final String htmlUrl;

  bool get isOpen => state == 'open';
  bool get isMerged => mergedAt != null;

  factory PullRequest.fromJson(Map<String, dynamic> j) => PullRequest(
        number: j['number'] as int,
        title: j['title'] as String,
        body: j['body'] as String?,
        state: j['state'] as String,
        user:
            (j['user'] as Map<String, dynamic>)['login'] as String,
        headRef:
            (j['head'] as Map<String, dynamic>)['ref'] as String,
        baseRef:
            (j['base'] as Map<String, dynamic>)['ref'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        mergedAt: j['merged_at'] != null
            ? DateTime.parse(j['merged_at'] as String)
            : null,
        isDraft: (j['draft'] as bool?) ?? false,
        htmlUrl: j['html_url'] as String,
      );
}

// ── GitHub Actions モデル ─────────────────────────────────

class WorkflowRun {
  const WorkflowRun({
    required this.id,
    required this.name,
    required this.displayTitle,
    required this.status,
    this.conclusion,
    required this.event,
    required this.headBranch,
    required this.headSha,
    required this.runNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
  });

  final int id;
  final String name;
  final String displayTitle;
  final String status;   // queued | in_progress | completed
  final String? conclusion; // success | failure | cancelled | skipped | timed_out
  final String event;    // push | pull_request | workflow_dispatch | ...
  final String headBranch;
  final String headSha;
  final int runNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String htmlUrl;

  bool get isCompleted => status == 'completed';
  bool get isRunning => status == 'in_progress';
  bool get isQueued => status == 'queued';
  bool get isSuccess => conclusion == 'success';
  bool get isFailure => conclusion == 'failure';

  String get shortSha => headSha.length >= 7 ? headSha.substring(0, 7) : headSha;

  factory WorkflowRun.fromJson(Map<String, dynamic> j) => WorkflowRun(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? 'Workflow',
        displayTitle: (j['display_title'] as String?) ??
            (j['head_commit'] as Map<String, dynamic>?)?['message']
                ?.toString()
                .split('\n')
                .first ??
            '',
        status: j['status'] as String,
        conclusion: j['conclusion'] as String?,
        event: j['event'] as String,
        headBranch: (j['head_branch'] as String?) ?? '',
        headSha: (j['head_sha'] as String?) ?? '',
        runNumber: j['run_number'] as int,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        htmlUrl: j['html_url'] as String,
      );
}

class WorkflowJob {
  const WorkflowJob({
    required this.id,
    required this.name,
    required this.status,
    this.conclusion,
    this.startedAt,
    this.completedAt,
    required this.steps,
  });

  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<WorkflowStep> steps;

  bool get isCompleted => status == 'completed';
  bool get isRunning => status == 'in_progress';
  bool get isSuccess => conclusion == 'success';
  bool get isFailure => conclusion == 'failure';

  Duration? get duration => (startedAt != null && completedAt != null)
      ? completedAt!.difference(startedAt!)
      : null;

  factory WorkflowJob.fromJson(Map<String, dynamic> j) => WorkflowJob(
        id: j['id'] as int,
        name: j['name'] as String,
        status: j['status'] as String,
        conclusion: j['conclusion'] as String?,
        startedAt: j['started_at'] != null
            ? DateTime.parse(j['started_at'] as String)
            : null,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        steps: ((j['steps'] as List<dynamic>?) ?? [])
            .map((e) => WorkflowStep.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkflowStep {
  const WorkflowStep({
    required this.number,
    required this.name,
    required this.status,
    this.conclusion,
  });

  final int number;
  final String name;
  final String status;
  final String? conclusion;

  bool get isSuccess => conclusion == 'success';
  bool get isFailure => conclusion == 'failure';
  bool get isSkipped => conclusion == 'skipped';

  factory WorkflowStep.fromJson(Map<String, dynamic> j) => WorkflowStep(
        number: j['number'] as int,
        name: j['name'] as String,
        status: j['status'] as String,
        conclusion: j['conclusion'] as String?,
      );
}

// ── サービス ──────────────────────────────────────────────

class GitHubService extends ChangeNotifier {
  final _storage = SecureStorageService.instance;
  final _cache = GitHubCache();
  final _inFlight = <String, Future<String>>{};

  String? _pat;
  String? _username;
  bool _isLoading = false;
  String? _error;

  static const _ttlRepos     = Duration(minutes: 5);
  static const _ttlTree      = Duration(minutes: 5);
  static const _ttlContents  = Duration(minutes: 2);
  static const _ttlBranches  = Duration(minutes: 5);
  static const _ttlPulls     = Duration(minutes: 2);
  static const _ttlCiRuns    = Duration(seconds: 30);
  static const _ttlCiJobs    = Duration(seconds: 30);
  static const _ttlRef       = Duration(minutes: 1);

  bool get isAuthenticated => _pat != null && _pat!.isNotEmpty;
  String? get username => _username;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pat => _pat;

  Future<void> init() async {
    _pat = await _storage.getGitHubPat();
    if (isAuthenticated) {
      try {
        await _fetchCurrentUser();
      } catch (_) {
        _pat = null;
        await _storage.deleteGitHubPat();
      }
    }
    notifyListeners();
  }

  Future<void> signIn(String pat) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _pat = pat.trim();
      await _fetchCurrentUser();
      await _storage.saveGitHubPat(_pat!);
    } catch (e) {
      _pat = null;
      _error = 'トークンが無効です。repo スコープ付きの PAT を入力してください。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _pat = null;
    _username = null;
    _cache.clear();
    _inFlight.clear();
    await _storage.deleteGitHubPat();
    notifyListeners();
  }

  Future<void> _fetchCurrentUser() async {
    final body = await _get('/user');
    final json = jsonDecode(body) as Map<String, dynamic>;
    _username = json['login'] as String?;
  }

  Future<List<GitHubRepo>> listRepos() async {
    final body = await _get(
        '/user/repos?sort=updated&per_page=100&affiliation=owner,collaborator',
        ttl: _ttlRepos);
    final list = jsonDecode(body) as List<dynamic>;
    return list
        .map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GitHubFile>> getFileTree(
      String owner, String repo, String branch) async {
    final body = await _get(
        '/repos/$owner/$repo/git/trees/$branch?recursive=1',
        ttl: _ttlTree);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tree = json['tree'] as List<dynamic>;
    return tree
        .map((e) => GitHubFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GitHubFileContent> getFileContent(
      String owner, String repo, String path) async {
    final body = await _get('/repos/$owner/$repo/contents/$path',
        ttl: _ttlContents);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return GitHubFileContent.fromJson(json);
  }

  Future<void> updateFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String sha,
    String? commitMessage,
  }) async {
    final message = commitMessage ?? 'Update $path via kirikiri';
    await _put(
      '/repos/$owner/$repo/contents/$path',
      jsonEncode({
        'message': message,
        'content': base64.encode(utf8.encode(content)),
        'sha': sha,
      }),
    );
    _cache.invalidateWhere((k) => k.contains('/contents/$path'));
    _cache.invalidateWhere(
        (k) => k.contains('/repos/$owner/$repo/git/trees/'));
  }

  Future<List<WorkflowRun>> getWorkflowRuns(
      String owner, String repo, {int perPage = 20}) async {
    final body = await _get(
        '/repos/$owner/$repo/actions/runs?per_page=$perPage',
        ttl: _ttlCiRuns);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final runs = (json['workflow_runs'] as List<dynamic>? ?? []);
    return runs
        .map((e) => WorkflowRun.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkflowJob>> getWorkflowJobs(
      String owner, String repo, int runId) async {
    final body = await _get(
        '/repos/$owner/$repo/actions/runs/$runId/jobs',
        ttl: _ttlCiJobs);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final jobs = (json['jobs'] as List<dynamic>? ?? []);
    return jobs
        .map((e) => WorkflowJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // PAT を使った clone URL（private リポジトリ対応）
  String cloneUrl(GitHubRepo repo) {
    if (!repo.isPrivate || _pat == null) return repo.cloneUrl;
    return 'https://oauth2:$_pat@github.com/${repo.owner}/${repo.name}.git';
  }

  // Cloud Shell で実行する clone/pull コマンド
  String buildShellCommand(GitHubRepo repo, {String? branch}) {
    final dir = '\$HOME/${repo.name}';
    final url = cloneUrl(repo);
    final checkoutSuffix = (branch != null && branch != repo.defaultBranch)
        ? ' && git switch "$branch"'
        : '';
    return 'if [ -d "$dir/.git" ]; then '
        'echo "↓ Pulling ${repo.name}..." && cd "$dir" && git pull$checkoutSuffix; '
        'else '
        'echo "⬇ Cloning ${repo.fullName}..." && git clone "$url" "$dir" && cd "$dir"$checkoutSuffix; '
        'fi';
  }

  Future<String> _get(String path, {Duration? ttl}) async {
    if (ttl != null) {
      // ① フレッシュキャッシュ → 即返す
      final fresh = _cache.getFresh(path);
      if (fresh != null) return fresh;

      // ② ステールキャッシュ → 即返す + バックグラウンド更新
      final stale = _cache.getAny(path);
      if (stale != null) {
        _revalidate(path, ttl);
        return stale;
      }
    }

    // ③ キャッシュなし → フェッチ（重複リクエスト排除）
    if (_inFlight.containsKey(path)) return _inFlight[path]!;
    final future = _fetchRaw(path, ttl: ttl);
    _inFlight[path] = future;
    future.whenComplete(() => _inFlight.remove(path));
    return future;
  }

  Future<String> _fetchRaw(String path, {Duration? ttl}) async {
    final response = await http.get(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API ${response.statusCode}');
    }
    if (ttl != null) _cache.put(path, response.body, ttl);
    return response.body;
  }

  void _revalidate(String path, Duration ttl) {
    if (_inFlight.containsKey(path)) return;
    final future = _fetchRaw(path, ttl: ttl);
    _inFlight[path] = future;
    future
      ..then((_) => notifyListeners())
      ..catchError((_) {})
      ..whenComplete(() => _inFlight.remove(path));
  }

  Future<List<GitHubBranch>> getBranches(String owner, String repo) async {
    final body = await _get('/repos/$owner/$repo/branches?per_page=100',
        ttl: _ttlBranches);
    final list = jsonDecode(body) as List<dynamic>;
    return list
        .map((e) => GitHubBranch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> getBranchSha(
      String owner, String repo, String branch) async {
    final body = await _get('/repos/$owner/$repo/git/ref/heads/$branch',
        ttl: _ttlRef);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['object'] as Map<String, dynamic>)['sha'] as String;
  }

  Future<void> createBranch(
      String owner, String repo, String name, String fromSha) async {
    await _post(
      '/repos/$owner/$repo/git/refs',
      jsonEncode({'ref': 'refs/heads/$name', 'sha': fromSha}),
    );
    _cache.invalidateWhere(
        (k) => k.contains('/repos/$owner/$repo/branches'));
  }

  Future<void> deleteBranch(String owner, String repo, String name) async {
    await _delete('/repos/$owner/$repo/git/refs/heads/$name');
    _cache.invalidateWhere(
        (k) => k.contains('/repos/$owner/$repo/branches'));
  }

  Future<List<PullRequest>> getPullRequests(String owner, String repo,
      {String state = 'open'}) async {
    final body = await _get(
        '/repos/$owner/$repo/pulls?state=$state&per_page=50',
        ttl: _ttlPulls);
    final list = jsonDecode(body) as List<dynamic>;
    return list
        .map((e) => PullRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PullRequest> createPullRequest(
    String owner,
    String repo,
    String title,
    String prBody,
    String head,
    String base,
  ) async {
    final resp = await _postWithResponse(
      '/repos/$owner/$repo/pulls',
      jsonEncode(
          {'title': title, 'body': prBody, 'head': head, 'base': base}),
    );
    _cache.invalidateWhere(
        (k) => k.contains('/repos/$owner/$repo/pulls'));
    return PullRequest.fromJson(jsonDecode(resp) as Map<String, dynamic>);
  }

  Future<void> _put(String path, String body) async {
    final response = await http.put(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'GitHub API ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> _post(String path, String body) async {
    final response = await http.post(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'GitHub API ${response.statusCode}: ${response.body}');
    }
  }

  Future<String> _postWithResponse(String path, String body) async {
    final response = await http.post(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'GitHub API ${response.statusCode}: ${response.body}');
    }
    return response.body;
  }

  Future<void> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.gitHubApiBase}$path'),
      headers: _headers,
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(
          'GitHub API ${response.statusCode}: ${response.body}');
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'token $_pat',
        'Accept': 'application/vnd.github.v3+json',
      };
}
