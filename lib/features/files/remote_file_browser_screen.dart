import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../theme/app_theme.dart';
import 'remote_file_editor_screen.dart';
import 'remote_file_messages.dart';
import 'remote_file_service.dart';

/// リモートの作業ツリーを辿る画面。
///
/// ターミナルで `cd` した先から始まるので、いま作業しているディレクトリの
/// ファイルをそのまま開ける。
class RemoteFileBrowserScreen extends StatefulWidget {
  const RemoteFileBrowserScreen({super.key, required this.service});

  final RemoteFileService service;

  @override
  State<RemoteFileBrowserScreen> createState() =>
      _RemoteFileBrowserScreenState();
}

class _RemoteFileBrowserScreenState extends State<RemoteFileBrowserScreen> {
  String? _path;
  List<RemoteEntry> _entries = const [];
  bool _loading = true;
  RemoteFileException? _error;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _openStartDirectory();
  }

  Future<void> _openStartDirectory() async {
    try {
      final start = await widget.service.startDirectory();
      await _load(start);
    } on RemoteFileException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.service.list(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
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

  Future<void> _openFile(RemoteEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RemoteFileEditorScreen(
        service: widget.service,
        path: entry.path,
        name: entry.name,
      ),
    ));
  }

  List<RemoteEntry> get _visible => _showHidden
      ? _entries
      : _entries.where((e) => !e.isHidden).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final path = _path;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.remoteFilesTitle, style: const TextStyle(fontSize: 16)),
            if (path != null)
              Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.remoteFilesShowHidden,
            icon: Icon(_showHidden
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _showHidden = !_showHidden),
          ),
          if (path != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _load(path),
            ),
        ],
      ),
      body: _buildBody(l),
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
              const Icon(Icons.folder_off_rounded,
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

    final path = _path;
    final entries = _visible;
    final atRoot = path == null || path == '/';

    return ListView.builder(
      itemCount: entries.length + (atRoot ? 0 : 1),
      itemBuilder: (_, index) {
        if (!atRoot && index == 0) {
          return ListTile(
            leading: const Icon(Icons.arrow_upward_rounded,
                color: AppColors.textMuted),
            title: Text(l.remoteFilesParent,
                style: const TextStyle(color: AppColors.textSecondary)),
            onTap: () => _load(RemoteFileService.parentOf(path)),
          );
        }

        final entry = entries[atRoot ? index : index - 1];
        return ListTile(
          leading: Icon(
            entry.isDirectory
                ? Icons.folder_rounded
                : Icons.description_outlined,
            color: entry.isDirectory
                ? AppColors.primary
                : AppColors.textMuted,
          ),
          title: Text(
            entry.name,
            style: TextStyle(
              color: entry.isHidden
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          subtitle: entry.isDirectory || entry.size == null
              ? null
              : Text(_formatSize(entry.size!),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
          trailing: entry.isDirectory
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18)
              : null,
          onTap: () =>
              entry.isDirectory ? _load(entry.path) : _openFile(entry),
        );
      },
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
