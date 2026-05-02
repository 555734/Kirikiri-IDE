import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import 'github_service.dart';

class FileEditorScreen extends StatefulWidget {
  const FileEditorScreen({
    super.key,
    required this.repo,
    required this.filePath,
  });
  final GitHubRepo repo;
  final String filePath;

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> {
  late final TextEditingController _textCtrl;
  GitHubFileContent? _fileContent;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _hasChanges = false;

  static const _binaryExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'webp', 'svg',
    'pdf', 'zip', 'tar', 'gz', 'jar', 'class', 'exe', 'so', 'dylib',
    'woff', 'woff2', 'ttf', 'otf', 'eot',
    'mp4', 'mp3', 'wav', 'avi', 'mov',
  };

  String get _ext =>
      widget.filePath.split('.').last.toLowerCase();
  bool get _isBinary => _binaryExtensions.contains(_ext);

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _textCtrl.addListener(() {
      if (_fileContent != null &&
          _textCtrl.text != _fileContent!.content) {
        if (!_hasChanges) setState(() => _hasChanges = true);
      }
    });
    _loadFile();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final github = context.read<GitHubService>();
      final content = await github.getFileContent(
          widget.repo.owner, widget.repo.name, widget.filePath);
      _fileContent = content;
      _textCtrl.text = content.content;
      setState(() => _hasChanges = false);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_fileContent == null || _saving) return;

    final message = await _showCommitDialog();
    if (message == null) return;

    setState(() => _saving = true);
    try {
      final github = context.read<GitHubService>();
      await github.updateFile(
        owner: widget.repo.owner,
        repo: widget.repo.name,
        path: widget.filePath,
        content: _textCtrl.text,
        sha: _fileContent!.sha,
        commitMessage: message,
      );
      // 保存後に最新の SHA を再取得
      final updated = await github.getFileContent(
          widget.repo.owner, widget.repo.name, widget.filePath);
      _fileContent = updated;
      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fileSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.fileSaveError(e.toString())),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<String?> _showCommitDialog() async {
    final ctrl = TextEditingController(
        text: 'Update ${widget.filePath.split('/').last} via kirikiri');
    final l = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.commitMessageTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l.commitMessageHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(l.commit)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Expanded(
              child: Text(fileName,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            if (_hasChanges)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(left: 6),
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        actions: [
          if (!_isBinary && !_loading && _error == null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary))
                  : const Icon(Icons.save_rounded),
              tooltip: AppLocalizations.of(context)!.commitSave,
              onPressed: _hasChanges ? _save : null,
            ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: AppLocalizations.of(context)!.copy,
            onPressed: _fileContent == null
                ? null
                : () {
                    Clipboard.setData(
                        ClipboardData(text: _textCtrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.copied)),
                    );
                  },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
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
                onPressed: _loadFile,
                child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      );
    }
    if (_isBinary) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.binaryFileNotSupported,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return TextField(
      controller: _textCtrl,
      maxLines: null,
      expands: true,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: AppColors.textPrimary,
        height: 1.6,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: AppColors.background,
        filled: true,
      ),
    );
  }
}
