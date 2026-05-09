import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/feature_flag_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_box.dart';
import 'branches_pr_screen.dart';
import 'ci_cd_screen.dart';
import 'file_editor_screen.dart';
import 'github_service.dart';

class RepoDetailScreen extends StatefulWidget {
  const RepoDetailScreen({
    super.key,
    required this.repo,
    required this.onOpenInShell,
    this.treeFuture,
  });
  final GitHubRepo repo;
  final VoidCallback onOpenInShell;
  /// Prefetch された Future。渡すと遷移アニメーション中にフェッチが並走する。
  final Future<List<GitHubFile>>? treeFuture;

  @override
  State<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends State<RepoDetailScreen> {
  List<GitHubFile>? _tree;
  bool _loading = false;
  String? _error;
  String _currentDir = '';

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final github = context.read<GitHubService>();
      // prefetch済みの Future があればそれを使い、なければ新規フェッチ
      final tree = await (widget.treeFuture ??
          github.getFileTree(
              widget.repo.owner, widget.repo.name, widget.repo.defaultBranch));
      if (mounted) setState(() => _tree = tree);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 現在のディレクトリ配下のアイテムを返す
  List<GitHubFile> get _visibleItems {
    final tree = _tree ?? [];
    return tree.where((f) {
      if (_currentDir.isEmpty) {
        // ルート直下のみ
        return !f.path.contains('/');
      }
      // 現在のディレクトリ直下のみ
      if (!f.path.startsWith('$_currentDir/')) return false;
      final rel = f.path.substring(_currentDir.length + 1);
      return !rel.contains('/');
    }).toList()
      ..sort((a, b) {
        // ディレクトリを先に
        if (a.isDir && !b.isDir) return -1;
        if (!a.isDir && b.isDir) return 1;
        return a.name.compareTo(b.name);
      });
  }

  List<String> get _breadcrumbs =>
      _currentDir.isEmpty ? [] : _currentDir.split('/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.repo.fullName,
            style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_merge_rounded, size: 20),
            tooltip: AppLocalizations.of(context)!.branchesTitle,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BranchesPrScreen(
                repo: widget.repo,
                onSwitchToShell: widget.onOpenInShell,
              ),
            )),
          ),
          if (context.watch<FeatureFlagService>().cicd)
            IconButton(
              icon: const Icon(Icons.rocket_launch_rounded, size: 20),
              tooltip: AppLocalizations.of(context)!.cicdTitle,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CiCdScreen(repo: widget.repo),
              )),
            ),
          ElevatedButton.icon(
            onPressed: widget.onOpenInShell,
            icon: const Icon(Icons.terminal_rounded, size: 16),
            label: Text(AppLocalizations.of(context)!.openInShell,
                style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_breadcrumbs.isNotEmpty) _buildBreadcrumb(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _currentDir = ''),
            child: const Text('/',
                style: TextStyle(
                    color: AppColors.primary, fontSize: 13)),
          ),
          ..._breadcrumbs.asMap().entries.map((e) {
            final path = _breadcrumbs.sublist(0, e.key + 1).join('/');
            final isLast = e.key == _breadcrumbs.length - 1;
            return Row(
              children: [
                const Text(' / ',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                GestureDetector(
                  onTap: isLast
                      ? null
                      : () => setState(() => _currentDir = path),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: isLast
                          ? AppColors.textPrimary
                          : AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _tree == null) {
      return _buildSkeleton();
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadTree,
                child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      );
    }
    final items = _visibleItems;
    if (items.isEmpty) {
      return Center(
          child: Text(AppLocalizations.of(context)!.noFiles,
              style: const TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (_, i) => _FileRow(
        file: items[i],
        repo: widget.repo,
        onTapDir: (path) => setState(() => _currentDir = path),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 10,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SkeletonBox(width: 18, height: 18),
            const SizedBox(width: 12),
            SkeletonBox(width: 80.0 + (i % 4) * 35, height: 13),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow(
      {required this.file,
      required this.repo,
      required this.onTapDir});
  final GitHubFile file;
  final GitHubRepo repo;
  final ValueChanged<String> onTapDir;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (file.isDir) {
          onTapDir(file.path);
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FileEditorScreen(
              repo: repo,
              filePath: file.path,
            ),
          ));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(
              file.isDir
                  ? Icons.folder_rounded
                  : _fileIcon(file.name),
              size: 18,
              color: file.isDir
                  ? AppColors.warning
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file.name,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
            if (file.isFile && file.size != null)
              Text(
                _formatSize(file.size!),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            if (file.isDir)
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' => Icons.code_rounded,
      'js' || 'ts' || 'jsx' || 'tsx' => Icons.javascript_rounded,
      'py' => Icons.code_rounded,
      'md' => Icons.description_rounded,
      'json' || 'yaml' || 'yml' => Icons.data_object_rounded,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => Icons.image_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}
