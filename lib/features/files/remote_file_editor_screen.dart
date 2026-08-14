import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../theme/app_theme.dart';
import 'remote_file_messages.dart';
import 'remote_file_service.dart';

/// リモートの作業ツリーにあるファイルを直接編集する。
///
/// GitHub API 経由のエディタと違い、コミットを経由せずターミナルが見ている
/// ファイルそのものを書き換える。
class RemoteFileEditorScreen extends StatefulWidget {
  const RemoteFileEditorScreen({
    super.key,
    required this.service,
    required this.path,
    required this.name,
  });

  final RemoteFileService service;
  final String path;
  final String name;

  @override
  State<RemoteFileEditorScreen> createState() => _RemoteFileEditorScreenState();
}

class _RemoteFileEditorScreenState extends State<RemoteFileEditorScreen> {
  final TextEditingController _controller = TextEditingController();

  String _original = '';
  bool _loading = true;
  bool _saving = false;
  RemoteFileException? _error;

  bool get _hasChanges => _controller.text != _original;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final content = await widget.service.readText(widget.path);
      if (!mounted) return;
      setState(() {
        _original = content;
        _controller.text = content;
        _loading = false;
      });
    } on RemoteFileException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final content = _controller.text;
    try {
      await widget.service.writeText(widget.path, content);
      if (!mounted) return;
      setState(() {
        _original = content;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.remoteFileSaved)),
      );
    } on RemoteFileException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              remoteFileFailureMessage(AppLocalizations.of(context)!, e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// 未保存の変更があるまま閉じようとしたら確認する。
  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final l = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.remoteFileDiscardTitle,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 15)),
        content: Text(l.remoteFileDiscardBody,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l.discard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: const TextStyle(fontSize: 15)),
              Text(
                widget.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _hasChanges ? _save : null,
                child: Text(l.save),
              ),
          ],
        ),
        body: _buildBody(l),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined,
                  color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text(
                remoteFileFailureMessage(l, error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        onChanged: (_) => setState(() {}),
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }
}
