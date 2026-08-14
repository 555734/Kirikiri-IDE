import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/feature_flag_service.dart';
import '../../core/secure_storage_service.dart';
import '../../core/theme_service.dart';
import '../auth/google_auth_service.dart';
import '../cloudshell/cloud_shell_service.dart';
import '../../theme/app_theme.dart';
import '../api_test/api_test_screen.dart';
import '../github/github_service.dart';
import '../preview/web_preview_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FeatureFlagService>(
      builder: (context, flags, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _GoogleAccountSection(),
          const _Divider(),
          const _AppearanceSection(),
          const _Divider(),
          const _GitHubSection(),
          const _Divider(),
          if (flags.apiKeys) ...[
            const _ApiKeysSection(),
            const _Divider(),
            const _ApiTestSection(),
            const _Divider(),
          ],
          const _CommandSnippetsSection(),
          const _Divider(),
          const _AdditionalFeaturesSection(),
          const _Divider(),
          const _AboutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8);
  }
}

// ── Googleアカウントセクション ────────────────────────────────

class _GoogleAccountSection extends StatelessWidget {
  const _GoogleAccountSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Consumer<GoogleAuthService>(
      builder: (context, auth, _) {
        if (!auth.isSignedIn) return const SizedBox.shrink();
        return _Section(
          title: 'Google Cloud Shell',
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_rounded),
              title: Text(l.githubLoggedIn),
              trailing: TextButton(
                onPressed: () => _confirmLogout(context, auth),
                child: Text(l.logout,
                    style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, GoogleAuthService auth) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.logoutConfirmTitle),
        content: Text(l.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.signOut();
              if (ctx.mounted) {
                ctx.read<CloudShellService>().reset();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l.logout),
          ),
        ],
      ),
    );
  }
}

// ── 外観セクション ─────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Consumer<ThemeService>(
      builder: (_, themeService, __) {
        return _Section(
          title: l.appearanceSection,
          children: [
            SwitchListTile(
              title: Text(l.darkMode),
              subtitle: Text(l.darkModeSubtitle),
              value: themeService.isDark,
              activeColor: AppColors.primary,
              onChanged: (v) => themeService.setDark(v),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields_rounded),
              title: Text(l.fontSizeLabel),
              subtitle: Text('${themeService.terminalFontSize.toInt()}px'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _showFontSizePicker(context, themeService),
            ),
          ],
        );
      },
    );
  }

  void _showFontSizePicker(BuildContext context, ThemeService themeService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final l = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.fontSizeLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [10, 11, 12, 13, 14, 16, 18, 20]
                    .map((size) => GestureDetector(
                          onTap: () {
                            themeService.setTerminalFontSize(size.toDouble());
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            width: 60,
                            height: 44,
                            decoration: BoxDecoration(
                              color: themeService.terminalFontSize == size
                                  ? AppColors.primary
                                  : AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${size}px',
                              style: TextStyle(
                                color: themeService.terminalFontSize == size
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ── GitHubセクション ─────────────────────────────────────────

class _GitHubSection extends StatelessWidget {
  const _GitHubSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Consumer<GitHubService>(
      builder: (_, github, __) {
        return _Section(
          title: l.githubSection,
          children: [
            if (github.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(l.githubLoggedIn),
                subtitle: Text('@${github.username ?? '...'}'),
                trailing: TextButton(
                  onPressed: () => github.signOut(),
                  child: Text(l.logout,
                      style: const TextStyle(color: AppColors.error)),
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: Text(l.githubNotConnected),
                subtitle: Text(l.githubNotConnectedHint),
              ),
            ListTile(
              leading: const Icon(Icons.token_rounded),
              title: Text(l.githubUpdatePat),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WebPreviewScreen(
                    url: 'https://github.com/settings/tokens/new?scopes=repo,read:user&description=kirikiri',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── APIキーセクション ─────────────────────────────────────────

class _ApiKeysSection extends StatefulWidget {
  const _ApiKeysSection();

  @override
  State<_ApiKeysSection> createState() => _ApiKeysSectionState();
}

class _ApiKeysSectionState extends State<_ApiKeysSection> {
  List<Map<String, String>> _keys = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await SecureStorageService.instance.getApiKeys();
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _keys = list
          .map((e) => {'label': e['label'] as String, 'key': e['key'] as String})
          .toList();
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await SecureStorageService.instance.saveApiKeys(jsonEncode(_keys));
  }

  void _showAddDialog([int? editIndex]) {
    final labelCtrl = TextEditingController(
        text: editIndex != null ? _keys[editIndex]['label'] : '');
    final keyCtrl = TextEditingController(
        text: editIndex != null ? _keys[editIndex]['key'] : '');
    bool obscure = true;

    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(editIndex != null ? l.apiKeyEdit : l.apiKeyAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: l.apiKeyLabelHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: l.apiKeyFieldLabel,
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () => setD(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final key = keyCtrl.text.trim();
                if (label.isEmpty || key.isEmpty) return;
                setState(() {
                  if (editIndex != null) {
                    _keys[editIndex] = {'label': label, 'key': key};
                  } else {
                    _keys.add({'label': label, 'key': key});
                  }
                });
                _save();
                Navigator.pop(ctx);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return _Section(
      title: l.apiKeysSection,
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded),
        tooltip: l.add,
        onPressed: () => _showAddDialog(),
      ),
      children: [
        if (_keys.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(l.apiKeysEmpty,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ..._keys.asMap().entries.map((e) => _ApiKeyTile(
              label: e.value['label']!,
              apiKey: e.value['key']!,
              onEdit: () => _showAddDialog(e.key),
              onDelete: () {
                setState(() => _keys.removeAt(e.key));
                _save();
              },
            )),
      ],
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({
    required this.label,
    required this.apiKey,
    required this.onEdit,
    required this.onDelete,
  });
  final String label;
  final String apiKey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final masked = _visible
        ? widget.apiKey
        : '${widget.apiKey.substring(0, widget.apiKey.length.clamp(0, 6))}••••••';
    return ListTile(
      leading: const Icon(Icons.vpn_key_rounded, size: 20),
      title: Text(widget.label),
      subtitle: Text(masked,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_visible
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded, size: 18),
            onPressed: () => setState(() => _visible = !_visible),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: AppLocalizations.of(context)!.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.apiKey));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(AppLocalizations.of(context)!.copied),
                    duration: const Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: widget.onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ── APIテストセクション ──────────────────────────────────────

class _ApiTestSection extends StatelessWidget {
  const _ApiTestSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _Section(
      title: l.apiTestTitle,
      children: [
        ListTile(
          leading: const Icon(Icons.api_rounded),
          title: Text(l.apiTestTitle),
          subtitle: const Text('REST HTTP client with API key support',
              style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApiTestScreen()),
          ),
        ),
      ],
    );
  }
}

// ── コマンドスニペットセクション ─────────────────────────────

class _CommandSnippetsSection extends StatefulWidget {
  const _CommandSnippetsSection();

  @override
  State<_CommandSnippetsSection> createState() =>
      _CommandSnippetsSectionState();
}

class _CommandSnippetsSectionState extends State<_CommandSnippetsSection> {
  List<Map<String, String>> _snippets = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await SecureStorageService.instance.getCommandSnippets();
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _snippets = list
          .map((e) => {
                'label': e['label'] as String,
                'command': e['command'] as String,
              })
          .toList();
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await SecureStorageService.instance.saveCommandSnippets(
        jsonEncode(_snippets));
  }

  void _showAddDialog([int? editIndex]) {
    final labelCtrl = TextEditingController(
        text: editIndex != null ? _snippets[editIndex]['label'] : '');
    final cmdCtrl = TextEditingController(
        text: editIndex != null ? _snippets[editIndex]['command'] : '');

    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editIndex != null ? l.commandSnippetEdit : l.commandSnippetAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(labelText: l.commandSnippetLabelHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cmdCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(labelText: l.commandSnippetCommandLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              final cmd = cmdCtrl.text.trim();
              if (label.isEmpty || cmd.isEmpty) return;
              setState(() {
                if (editIndex != null) {
                  _snippets[editIndex] = {'label': label, 'command': cmd};
                } else {
                  _snippets.add({'label': label, 'command': cmd});
                }
              });
              _save();
              Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return _Section(
      title: l.commandSnippetsSection,
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded),
        tooltip: l.add,
        onPressed: () => _showAddDialog(),
      ),
      children: [
        if (_snippets.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(l.commandSnippetsHint,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ..._snippets.asMap().entries.map((e) => ListTile(
              leading: const Icon(Icons.terminal_rounded, size: 20),
              title: Text(e.value['label']!),
              subtitle: Text(
                e.value['command']!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: AppLocalizations.of(context)!.copy,
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: e.value['command']!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(AppLocalizations.of(context)!.copied),
                            duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: () => _showAddDialog(e.key),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        size: 18, color: AppColors.error),
                    onPressed: () {
                      setState(() => _snippets.removeAt(e.key));
                      _save();
                    },
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── 追加機能セクション ────────────────────────────────────────

class _AdditionalFeaturesSection extends StatelessWidget {
  const _AdditionalFeaturesSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Consumer<FeatureFlagService>(
      builder: (_, flags, __) => _Section(
        title: l.additionalFeaturesSection,
        children: [
          SwitchListTile(
            title: Text(l.featureSshTab),
            subtitle: Text(l.featureSshTabSubtitle),
            value: flags.sshTab,
            activeColor: AppColors.primary,
            onChanged: flags.setSshTab,
          ),
          SwitchListTile(
            title: Text(l.featureApiKeys),
            subtitle: Text(l.featureApiKeysSubtitle),
            value: flags.apiKeys,
            activeColor: AppColors.primary,
            onChanged: flags.setApiKeys,
          ),
          SwitchListTile(
            title: Text(l.featureCicd),
            subtitle: Text(l.featureCicdSubtitle),
            value: flags.cicd,
            activeColor: AppColors.primary,
            onChanged: flags.setCicd,
          ),
          SwitchListTile(
            title: Text(l.featurePlugins),
            subtitle: Text(l.featurePluginsSubtitle),
            value: flags.plugins,
            activeColor: AppColors.primary,
            onChanged: flags.setPlugins,
          ),
        ],
      ),
    );
  }
}

// ── このアプリについてセクション ────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _Section(
      title: l.aboutSection,
      children: [
        ListTile(
          leading: const Icon(Icons.description_rounded),
          title: Text(l.termsOfUse),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => launchUrl(
            Uri.parse(AppConstants.termsOfUseUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_rounded),
          title: Text(l.privacyPolicy),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => launchUrl(
            Uri.parse(AppConstants.privacyPolicyUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: Text(l.version),
          // バージョンは pubspec.yaml を単一の情報源とし、実行時に読み出す
          trailing: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snapshot) => Text(
              snapshot.data?.version ?? '',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 共通セクションラッパー ────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}
