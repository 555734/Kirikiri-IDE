import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/skeleton_box.dart';
import 'github_service.dart';

/// GitHub Actions ワークフロー実行状況画面
class CiCdScreen extends StatefulWidget {
  const CiCdScreen({super.key, required this.repo});
  final GitHubRepo repo;

  @override
  State<CiCdScreen> createState() => _CiCdScreenState();
}

class _CiCdScreenState extends State<CiCdScreen> {
  List<WorkflowRun>? _runs;
  bool _loading = false;
  String? _error;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final github = context.read<GitHubService>();
      final runs = await github.getWorkflowRuns(
          widget.repo.owner, widget.repo.name);
      if (mounted) {
        setState(() => _runs = runs);
        _scheduleAutoRefresh(runs);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleAutoRefresh(List<WorkflowRun> runs) {
    _autoRefresh?.cancel();
    _autoRefresh = null;
    if (runs.any((r) => r.isRunning || r.isQueued)) {
      _autoRefresh = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.cicdTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(widget.repo.fullName,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l.retry,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(l),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(
          height: 1, indent: 16, endIndent: 16,
          color: AppColors.surfaceHighlight),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SkeletonBox(width: 10, height: 10, borderRadius: 5),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160.0 + (i % 3) * 30, height: 13),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 100, height: 11),
                ],
              ),
            ),
            SkeletonBox(width: 48, height: 20, borderRadius: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading && _runs == null) {
      return _buildSkeleton();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              ElevatedButton(onPressed: _load, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }
    final runs = _runs ?? [];
    if (runs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rocket_launch_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(l.cicdNoRuns,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: runs.length,
        separatorBuilder: (_, __) => const Divider(
            height: 1, indent: 16, endIndent: 16,
            color: AppColors.surfaceHighlight),
        itemBuilder: (ctx, i) => _RunCard(
          run: runs[i],
          repo: widget.repo,
        ),
      ),
    );
  }
}

// ── ワークフロー実行カード ─────────────────────────────────

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run, required this.repo});
  final WorkflowRun run;
  final GitHubRepo repo;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(run);
    final statusIcon = _statusIcon(run);
    final timeAgo = _timeAgo(run.updatedAt);

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _JobsScreen(run: run, repo: repo),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ステータスアイコン
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _StatusDot(color: statusColor, icon: statusIcon,
                  spinning: run.isRunning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ワークフロー名 + 実行番号
                  Row(
                    children: [
                      Expanded(
                        child: Text(run.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('#${run.runNumber}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // コミットメッセージ（display title）
                  Text(run.displayTitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // ブランチ + イベント + 時刻
                  Row(
                    children: [
                      const Icon(Icons.call_split_rounded,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(run.headBranch,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      _EventBadge(event: run.event),
                      const Spacer(),
                      Text(timeAgo,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  // 結論バッジ
                  if (run.isCompleted && run.conclusion != null) ...[
                    const SizedBox(height: 4),
                    _ConclusionBadge(
                        conclusion: run.conclusion!, color: statusColor),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Color _statusColor(WorkflowRun r) {
    if (r.isRunning || r.isQueued) return AppColors.warning;
    if (r.isSuccess) return AppColors.success;
    if (r.isFailure) return AppColors.error;
    return AppColors.textMuted;
  }

  IconData _statusIcon(WorkflowRun r) {
    if (r.isRunning) return Icons.sync_rounded;
    if (r.isQueued) return Icons.hourglass_empty_rounded;
    if (r.isSuccess) return Icons.check_circle_rounded;
    if (r.isFailure) return Icons.cancel_rounded;
    return Icons.remove_circle_outline_rounded;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot(
      {required this.color, required this.icon, required this.spinning});
  final Color color;
  final IconData icon;
  final bool spinning;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.spinning) {
      return Icon(widget.icon, color: widget.color, size: 20);
    }
    return RotationTransition(
      turns: _ctrl,
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}

class _EventBadge extends StatelessWidget {
  const _EventBadge({required this.event});
  final String event;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (event) {
      'push' => ('push', Icons.upload_rounded),
      'pull_request' => ('PR', Icons.merge_type_rounded),
      'workflow_dispatch' => ('manual', Icons.play_arrow_rounded),
      'schedule' => ('schedule', Icons.schedule_rounded),
      _ => (event, Icons.bolt_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _ConclusionBadge extends StatelessWidget {
  const _ConclusionBadge(
      {required this.conclusion, required this.color});
  final String conclusion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(conclusion,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── ジョブ一覧画面 ────────────────────────────────────────

class _JobsScreen extends StatefulWidget {
  const _JobsScreen({required this.run, required this.repo});
  final WorkflowRun run;
  final GitHubRepo repo;

  @override
  State<_JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<_JobsScreen> {
  List<WorkflowJob>? _jobs;
  bool _loading = false;
  String? _error;

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
      final jobs = await github.getWorkflowJobs(
          widget.repo.owner, widget.repo.name, widget.run.id);
      if (mounted) setState(() => _jobs = jobs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final run = widget.run;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(run.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text('#${run.runNumber} · ${run.headBranch}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l.retry,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(l),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading && _jobs == null) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 4,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SkeletonBox(width: 20, height: 20),
              const SizedBox(width: 12),
              SkeletonBox(width: 120.0 + (i % 3) * 40, height: 14),
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
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: Text(l.retry)),
          ],
        ),
      );
    }

    final jobs = _jobs ?? [];

    // ── 実行サマリーヘッダー ──
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _RunSummaryCard(run: widget.run),
        const SizedBox(height: 8),
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(l.cicdNoJobs,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            ),
          )
        else
          ...jobs.map((job) => _JobCard(job: job)),
      ],
    );
  }
}

class _RunSummaryCard extends StatelessWidget {
  const _RunSummaryCard({required this.run});
  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final statusColor = run.isSuccess
        ? AppColors.success
        : run.isFailure
            ? AppColors.error
            : run.isRunning
                ? AppColors.warning
                : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(run.displayTitle,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.commit_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(run.shortSha,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'monospace')),
              const SizedBox(width: 12),
              const Icon(Icons.call_split_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(run.headBranch,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const Spacer(),
              if (run.conclusion != null)
                _ConclusionBadge(
                    conclusion: run.conclusion!, color: statusColor),
              if (run.isRunning)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(l.cicdRunning,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  const _JobCard({required this.job});
  final WorkflowJob job;

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final statusColor = job.isSuccess
        ? AppColors.success
        : job.isFailure
            ? AppColors.error
            : job.isRunning
                ? AppColors.warning
                : AppColors.textMuted;
    final statusIcon = job.isSuccess
        ? Icons.check_circle_rounded
        : job.isFailure
            ? Icons.cancel_rounded
            : job.isRunning
                ? Icons.sync_rounded
                : Icons.remove_circle_outline_rounded;

    final durationStr = job.duration != null
        ? _formatDuration(job.duration!)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(job.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                  if (durationStr != null) ...[
                    const Icon(Icons.timer_outlined,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(durationStr,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && job.steps.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.surfaceHighlight)),
              ),
              child: Column(
                children: job.steps.map((step) => _StepRow(step: step)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final WorkflowStep step;

  @override
  Widget build(BuildContext context) {
    final color = step.isSuccess
        ? AppColors.success
        : step.isFailure
            ? AppColors.error
            : step.isSkipped
                ? AppColors.textMuted
                : AppColors.warning;
    final icon = step.isSuccess
        ? Icons.check_rounded
        : step.isFailure
            ? Icons.close_rounded
            : step.isSkipped
                ? Icons.remove_rounded
                : Icons.circle_outlined;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${step.number}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(step.name,
                style: TextStyle(
                    color: step.isSkipped
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                    fontSize: 12,
                    decoration: step.isSkipped
                        ? TextDecoration.lineThrough
                        : null)),
          ),
        ],
      ),
    );
  }
}
