import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/skeleton_box.dart';
import '../cloudshell/cloud_shell_service.dart';
import 'github_service.dart';

class BranchesPrScreen extends StatelessWidget {
  const BranchesPrScreen({
    super.key,
    required this.repo,
    this.onSwitchToShell,
  });
  final GitHubRepo repo;
  final VoidCallback? onSwitchToShell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(repo.fullName, style: const TextStyle(fontSize: 14)),
          bottom: TabBar(
            tabs: [
              Tab(text: l.branchesTitle),
              Tab(text: l.pullRequestsTitle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BranchesTab(repo: repo, onSwitchToShell: onSwitchToShell),
            _PullRequestsTab(repo: repo),
          ],
        ),
      ),
    );
  }
}

// ── ブランチタブ ──────────────────────────────────────────

class _BranchesTab extends StatefulWidget {
  const _BranchesTab({required this.repo, this.onSwitchToShell});
  final GitHubRepo repo;
  final VoidCallback? onSwitchToShell;

  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab>
    with AutomaticKeepAliveClientMixin {
  List<GitHubBranch>? _branches;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final github = context.read<GitHubService>();
      final branches = await github.getBranches(
          widget.repo.owner, widget.repo.name);
      if (mounted) setState(() => _branches = branches);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final branches = _branches ?? [];
    String fromBranch = widget.repo.defaultBranch;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l.branchNew),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l.branchName),
              ),
              const SizedBox(height: 16),
              Text(l.branchFrom,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButton<String>(
                value: fromBranch,
                isExpanded: true,
                items: branches
                    .map((b) => DropdownMenuItem(
                        value: b.name, child: Text(b.name)))
                    .toList(),
                onChanged: (v) => setD(() => fromBranch = v ?? fromBranch),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final github = context.read<GitHubService>();
                  final sha = await github.getBranchSha(
                      widget.repo.owner, widget.repo.name, fromBranch);
                  await github.createBranch(
                      widget.repo.owner, widget.repo.name, name, sha);
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: Text(l.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(GitHubBranch branch) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.branchDelete),
        content: Text('${l.branchDeleteConfirm}\n\n${branch.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final github = context.read<GitHubService>();
      await github.deleteBranch(
          widget.repo.owner, widget.repo.name, branch.name);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SkeletonBox(width: 18, height: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 100.0 + (i % 4) * 30, height: 14),
                const SizedBox(height: 5),
                SkeletonBox(width: 60, height: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;

    if (_loading && _branches == null) {
      return _buildSkeleton();
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load, child: Text(l.retry)),
          ],
        ),
      );
    }

    final branches = _branches ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add_rounded),
      ),
      body: branches.isEmpty
          ? Center(
              child: Text(l.branchesEmpty,
                  style: const TextStyle(color: AppColors.textMuted)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: branches.length,
                itemBuilder: (_, i) => _BranchTile(
                  branch: branches[i],
                  isDefault: branches[i].name == widget.repo.defaultBranch,
                  repo: widget.repo,
                  onSwitchToShell: widget.onSwitchToShell,
                  onDelete:
                      branches[i].isProtected ? null : () => _confirmDelete(branches[i]),
                ),
              ),
            ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.branch,
    required this.isDefault,
    required this.repo,
    this.onSwitchToShell,
    this.onDelete,
  });
  final GitHubBranch branch;
  final bool isDefault;
  final GitHubRepo repo;
  final VoidCallback? onSwitchToShell;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(
        Icons.account_tree_rounded,
        size: 18,
        color: isDefault ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(branch.name),
      subtitle: Text(
        branch.sha.substring(0, 7),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (branch.isProtected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(l.branchProtected,
                  style: const TextStyle(
                      color: AppColors.warning, fontSize: 10)),
            ),
          if (isDefault)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('default',
                  style: TextStyle(
                      color: AppColors.primary, fontSize: 10)),
            ),
          if (onSwitchToShell != null)
            IconButton(
              icon: const Icon(Icons.terminal_rounded,
                  size: 18, color: AppColors.primary),
              tooltip: AppLocalizations.of(context)!.openInShell,
              onPressed: () {
                final github = context.read<GitHubService>();
                final shell = context.read<CloudShellService>();
                shell.setPendingRepo(
                  repo.fullName,
                  github.buildShellCommand(repo, branch: branch.name),
                );
                onSwitchToShell!();
              },
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_rounded,
                  size: 18, color: AppColors.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

// ── PRタブ ────────────────────────────────────────────────

class _PullRequestsTab extends StatefulWidget {
  const _PullRequestsTab({required this.repo});
  final GitHubRepo repo;

  @override
  State<_PullRequestsTab> createState() => _PullRequestsTabState();
}

class _PullRequestsTabState extends State<_PullRequestsTab>
    with AutomaticKeepAliveClientMixin {
  List<PullRequest>? _prs;
  bool _loading = false;
  String? _error;
  String _state = 'open';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final github = context.read<GitHubService>();
      final prs = await github.getPullRequests(
          widget.repo.owner, widget.repo.name,
          state: _state);
      if (mounted) setState(() => _prs = prs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final l = AppLocalizations.of(context)!;
    List<GitHubBranch>? branches;
    try {
      branches = await context
          .read<GitHubService>()
          .getBranches(widget.repo.owner, widget.repo.name);
    } catch (_) {}
    if (!mounted) return;

    final branchNames = branches?.map((b) => b.name).toList() ?? [];
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String head = branchNames.isNotEmpty ? branchNames.first : '';
    String base = widget.repo.defaultBranch;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l.prNew),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.prTitleLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l.prBodyLabel),
                ),
                const SizedBox(height: 16),
                Text(l.prHead,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                if (branchNames.isNotEmpty)
                  DropdownButton<String>(
                    value: head,
                    isExpanded: true,
                    items: branchNames
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setD(() => head = v ?? head),
                  )
                else
                  TextField(
                    onChanged: (v) => head = v,
                    decoration:
                        const InputDecoration(hintText: 'feature/my-branch'),
                  ),
                const SizedBox(height: 12),
                Text(l.prBase,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                if (branchNames.isNotEmpty)
                  DropdownButton<String>(
                    value: base,
                    isExpanded: true,
                    items: branchNames
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setD(() => base = v ?? base),
                  )
                else
                  TextField(
                    onChanged: (v) => base = v,
                    decoration:
                        const InputDecoration(hintText: 'main'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty || head.isEmpty || base.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final github = context.read<GitHubService>();
                  await github.createPullRequest(
                    widget.repo.owner,
                    widget.repo.name,
                    title,
                    bodyCtrl.text.trim(),
                    head,
                    base,
                  );
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: Text(l.prCreate),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;

    if (_loading && _prs == null) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 48),
        itemCount: 5,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SkeletonBox(width: 20, height: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140.0 + (i % 3) * 40, height: 14),
                  const SizedBox(height: 5),
                  SkeletonBox(width: 100, height: 11),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load, child: Text(l.retry)),
          ],
        ),
      );
    }

    final prs = _prs ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _StateChip(
                  label: l.prStateOpen,
                  selected: _state == 'open',
                  onTap: () => setState(() {
                    _state = 'open';
                    _load();
                  }),
                ),
                const SizedBox(width: 8),
                _StateChip(
                  label: l.prStateClosed,
                  selected: _state == 'closed',
                  onTap: () => setState(() {
                    _state = 'closed';
                    _load();
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: prs.isEmpty
                ? Center(
                    child: Text(l.prEmpty,
                        style: const TextStyle(
                            color: AppColors.textMuted)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: prs.length,
                      itemBuilder: (_, i) => _PrTile(pr: prs[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected ? AppColors.primary : AppColors.surfaceHighlight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.textSecondary,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PrTile extends StatelessWidget {
  const _PrTile({required this.pr});
  final PullRequest pr;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        pr.isMerged
            ? Icons.merge_rounded
            : pr.isOpen
                ? Icons.call_merge_rounded
                : Icons.do_not_disturb_rounded,
        size: 20,
        color: pr.isMerged
            ? Colors.deepPurple
            : pr.isOpen
                ? AppColors.success
                : AppColors.error,
      ),
      title: Row(
        children: [
          if (pr.isDraft)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('Draft',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
            ),
          Expanded(
            child: Text(
              pr.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '#${pr.number} by ${pr.user} · ${pr.headRef} → ${pr.baseRef}',
        style: const TextStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
