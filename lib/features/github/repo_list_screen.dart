import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/screenshot_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_box.dart';
import '../cloudshell/cloud_shell_service.dart';
import 'github_service.dart';
import 'github_setup_screen.dart';
import 'repo_detail_screen.dart';

class RepoListScreen extends StatefulWidget {
  const RepoListScreen({super.key, required this.onSwitchToShell});
  final VoidCallback onSwitchToShell;

  @override
  State<RepoListScreen> createState() => _RepoListScreenState();
}

class _RepoListScreenState extends State<RepoListScreen> {
  List<GitHubRepo>? _repos;
  String _query = '';
  bool _loading = false;
  String? _error;

  static final _demoRepos = [
    GitHubRepo(
        name: 'flutter-todo-app',
        owner: 'username',
        description: 'A cross-platform to-do app built with Flutter',
        cloneUrl: '',
        isPrivate: false,
        defaultBranch: 'main',
        updatedAt: DateTime(2026, 4, 20)),
    GitHubRepo(
        name: 'cloud-functions-api',
        owner: 'username',
        description: 'REST API on Google Cloud Functions',
        cloneUrl: '',
        isPrivate: true,
        defaultBranch: 'main',
        updatedAt: DateTime(2026, 4, 15)),
    GitHubRepo(
        name: 'kirikiri',
        owner: 'username',
        description: 'Mobile SSH & Cloud Shell client',
        cloneUrl: '',
        isPrivate: false,
        defaultBranch: 'main',
        updatedAt: DateTime(2026, 4, 10)),
    GitHubRepo(
        name: 'dotfiles',
        owner: 'username',
        description: null,
        cloneUrl: '',
        isPrivate: true,
        defaultBranch: 'main',
        updatedAt: DateTime(2026, 3, 28)),
    GitHubRepo(
        name: 'blog',
        owner: 'username',
        description: 'Personal blog built with Next.js',
        cloneUrl: '',
        isPrivate: false,
        defaultBranch: 'main',
        updatedAt: DateTime(2026, 3, 1)),
  ];

  @override
  void initState() {
    super.initState();
    if (kDemoMode) {
      _repos = _demoRepos;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRepos());
  }

  Future<void> _loadRepos() async {
    final github = context.read<GitHubService>();
    if (!github.isAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = await github.listRepos();
      setState(() => _repos = repos);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<GitHubRepo> get _filtered {
    final repos = _repos ?? [];
    if (_query.isEmpty) return repos;
    final q = _query.toLowerCase();
    return repos
        .where((r) =>
            r.fullName.toLowerCase().contains(q) ||
            (r.description?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (kDemoMode) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('@username', style: TextStyle(fontSize: 15)),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }
    return Consumer<GitHubService>(
      builder: (context, github, _) {
        if (!github.isAuthenticated) {
          return const GitHubSetupScreen();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: Text('@${github.username ?? ''}',
                style: const TextStyle(fontSize: 15)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadRepos,
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => github.signOut(),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.repoSearch,
          prefixIcon: Icon(Icons.search_rounded, size: 18),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 初回ロード（データなし）のみスケルトンを表示。
    // キャッシュヒット時は _loading が false のままデータが入るので見えない。
    if (_loading && _repos == null) {
      return _buildSkeleton();
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadRepos,
                child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      );
    }
    final repos = _filtered;
    if (repos.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.repoNotFound,
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRepos,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: repos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _RepoCard(
          repo: repos[i],
          onSwitchToShell: widget.onSwitchToShell,
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const _RepoCardSkeleton(),
    );
  }
}

class _RepoCardSkeleton extends StatelessWidget {
  const _RepoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 130, height: 14),
                const Spacer(),
                SkeletonBox(width: 36, height: 12),
              ],
            ),
            const SizedBox(height: 10),
            SkeletonBox(width: double.infinity, height: 11),
            const SizedBox(height: 5),
            SkeletonBox(width: 180, height: 11),
            const SizedBox(height: 10),
            SkeletonBox(width: 80, height: 10),
          ],
        ),
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({required this.repo, required this.onSwitchToShell});
  final GitHubRepo repo;
  final VoidCallback onSwitchToShell;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // ナビゲーションアニメーション中にフェッチを先行開始する
          final treeFuture = context
              .read<GitHubService>()
              .getFileTree(repo.owner, repo.name, repo.defaultBranch);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RepoDetailScreen(
              repo: repo,
              treeFuture: treeFuture,
              onOpenInShell: () => _openInShell(context),
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    repo.isPrivate
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      repo.fullName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _CloudShellButton(
                    repo: repo,
                    onSwitchToShell: onSwitchToShell,
                  ),
                ],
              ),
              if (repo.description != null && repo.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  repo.description!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '更新: ${_formatDate(context, repo.updatedAt)}  ・  ${repo.defaultBranch}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInShell(BuildContext context) {
    final github = context.read<GitHubService>();
    final shell = context.read<CloudShellService>();
    shell.setPendingRepo(repo.fullName, github.buildShellCommand(repo));
    onSwitchToShell();
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final l = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return l.relativeTimeToday;
    if (diff.inDays == 1) return l.relativeTimeYesterday;
    if (diff.inDays < 30) return l.relativeTimeDaysAgo(diff.inDays);
    if (diff.inDays < 365) return l.relativeTimeMonthsAgo((diff.inDays / 30).floor());
    return l.relativeTimeYearsAgo((diff.inDays / 365).floor());
  }
}

class _CloudShellButton extends StatelessWidget {
  const _CloudShellButton(
      {required this.repo, required this.onSwitchToShell});
  final GitHubRepo repo;
  final VoidCallback onSwitchToShell;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final github = context.read<GitHubService>();
        final shell = context.read<CloudShellService>();
        shell.setPendingRepo(repo.name, github.buildShellCommand(repo));
        onSwitchToShell();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terminal_rounded,
                size: 12, color: AppColors.primaryLight),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context)!.openInShell,
                style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
