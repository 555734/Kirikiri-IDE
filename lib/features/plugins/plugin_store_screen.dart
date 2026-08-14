import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/failure_messages.dart';
import '../../theme/app_theme.dart';
import 'plugin_service.dart';

/// VSCode風プラグインストア画面
///
/// GitHub Topics API で topic:kirikiri-plugin を検索し、
/// リポジトリ一覧を表示する。タップで即インストール可能。
class PluginStoreScreen extends StatefulWidget {
  const PluginStoreScreen({super.key});

  @override
  State<PluginStoreScreen> createState() => _PluginStoreScreenState();
}

class _PluginStoreScreenState extends State<PluginStoreScreen> {
  final _searchController = TextEditingController();
  List<PluginStoreEntry>? _results;
  bool _loading = false;
  String? _error;
  String _sort = 'stars';
  String? _installingRepoUrl;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<PluginService>();
      final results = await service.searchStore(
        query: _searchController.text,
        sort: _sort,
      );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _install(String repoUrl) async {
    setState(() => _installingRepoUrl = repoUrl);
    try {
      await context.read<PluginService>().installFromGitHub(repoUrl);
      if (mounted) {
        final err = context.read<PluginService>().installError;
        if (err == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.pluginInstalled)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.pluginInstallError(
                  pluginFailureMessage(AppLocalizations.of(context)!, err))),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _installingRepoUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.pluginStoreTitle),
        actions: [
          // ソート切り替え
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: AppLocalizations.of(context)!.pluginStoreSort,
            initialValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _search();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'stars', child: Text(AppLocalizations.of(ctx)!.pluginStoreSortStars)),
              PopupMenuItem(
                  value: 'updated', child: Text(AppLocalizations.of(ctx)!.pluginStoreSortUpdated)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 検索バー ──────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.pluginStoreSearch,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
            ),
          ),

          // ── 注意書き ──────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.warning.withOpacity(0.08),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.pluginStoreDisclaimer,
                    style: TextStyle(
                      color: AppColors.warning.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 結果リスト ────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }
    final results = _results ?? [];
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.extension_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.pluginStoreEmpty,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.pluginStoreTopicHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.8),
                  fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _search,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _StoreCard(
          entry: results[i],
          isInstalled: context.read<PluginService>().isInstalled(
                results[i].repoUrl,
              ),
          isInstalling: _installingRepoUrl == results[i].repoUrl,
          onInstall: () => _install(results[i].repoUrl),
        ),
      ),
    );
  }
}

// ── ストアカード ───────────────────────────────────────

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.entry,
    required this.isInstalled,
    required this.isInstalling,
    required this.onInstall,
  });

  final PluginStoreEntry entry;
  final bool isInstalled;
  final bool isInstalling;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final otherTopics = entry.topics
        .where((t) => t != 'kirikiri-plugin')
        .take(4)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInstalled
              ? AppColors.success.withOpacity(0.3)
              : AppColors.surfaceHighlight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ヘッダー行 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.redSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.extension_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        entry.author,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // インストールボタン
                _buildInstallButton(context),
              ],
            ),

            // ── 説明文 ──
            if (entry.description != null &&
                entry.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.description!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── フッター（スター・更新日・タグ）──
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 3),
                Text(
                  '${entry.stars}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 12),
                if (entry.updatedAt != null)
                  Text(
                    _formatDate(context, entry.updatedAt!),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                const Spacer(),
                if (isInstalled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.pluginAlreadyInstalled,
                      style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),

            // トピックチップ（kirikiri-plugin 以外）
            if (otherTopics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: otherTopics
                    .map((t) => _topicChip(t))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstallButton(BuildContext context) {
    if (isInstalled) {
      return const SizedBox.shrink();
    }
    if (isInstalling) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }
    return ElevatedButton(
      onPressed: onInstall,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(AppLocalizations.of(context)!.pluginInstall),
    );
  }

  Widget _topicChip(String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 10),
        ),
      );

  String _formatDate(BuildContext context, DateTime dt) {
    final l = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 1) return l.relativeTimeToday;
    if (diff.inDays < 7) return l.relativeTimeDaysAgo(diff.inDays);
    if (diff.inDays < 30) return l.relativeTimeWeeksAgo((diff.inDays / 7).floor());
    if (diff.inDays < 365) return l.relativeTimeMonthsAgo((diff.inDays / 30).floor());
    return l.relativeTimeYearsAgo((diff.inDays / 365).floor());
  }
}
