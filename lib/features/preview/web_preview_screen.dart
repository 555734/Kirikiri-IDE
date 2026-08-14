import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/secure_storage_service.dart';
import '../../theme/app_theme.dart';

/// 開発サーバーのWebプレビュー画面
///
/// Cloud Shell の webHost から構築した URL を WebView で表示する。
/// ツールバーにリロード・外部ブラウザ起動・URL コピーを提供。
class WebPreviewScreen extends StatefulWidget {
  const WebPreviewScreen({super.key, required this.url});

  final String url;

  @override
  State<WebPreviewScreen> createState() => _WebPreviewScreenState();
}

class _WebPreviewScreenState extends State<WebPreviewScreen> {
  late final WebViewController _webCtrl;
  int _loadingProgress = 0; // 0–100
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _loadingProgress = p),
        onPageStarted: (url) => setState(() => _currentUrl = url),
        onPageFinished: (url) async {
          setState(() {
            _currentUrl = url;
            _loadingProgress = 100;
          });
          _canGoBack = await _webCtrl.canGoBack();
          _canGoForward = await _webCtrl.canGoForward();
          if (mounted) setState(() {});
        },
      ));
    _loadWithAuth();
  }

  Future<void> _loadWithAuth() async {
    // Only inject Google access token for Cloud Shell proxy URLs (https).
    // Local tunnel URLs (http://127.0.0.1) don't need auth headers.
    final isLocal = widget.url.startsWith('http://127.0.0.1');
    final token = isLocal
        ? null
        : await SecureStorageService.instance.getAccessToken();
    _webCtrl.loadRequest(
      Uri.parse(widget.url),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── ローディングバー ──
          if (_loadingProgress < 100)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              minHeight: 2,
              backgroundColor: AppColors.surfaceHighlight,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
          // ── URL バー ──
          _UrlBar(
            url: _currentUrl,
            onRefresh: () => _webCtrl.reload(),
          ),
          // ── WebView ──
          Expanded(child: WebViewWidget(controller: _webCtrl)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final l = AppLocalizations.of(context)!;
    return AppBar(
      backgroundColor: AppColors.surface,
      title: Text(l.webPreviewTitle),
      actions: [
        // 戻る
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          tooltip: l.webPreviewBack,
          onPressed: _canGoBack ? () => _webCtrl.goBack() : null,
        ),
        // 進む
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          tooltip: l.webPreviewForward,
          onPressed: _canGoForward ? () => _webCtrl.goForward() : null,
        ),
        // リロード
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: l.webPreviewReload,
          onPressed: () => _webCtrl.reload(),
        ),
        // 外部ブラウザで開く
        IconButton(
          icon: const Icon(Icons.open_in_browser_rounded),
          tooltip: l.webPreviewOpenInBrowser,
          onPressed: () => launchUrl(
            Uri.parse(_currentUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}

// ── URLバー ───────────────────────────────────────────────

class _UrlBar extends StatelessWidget {
  const _UrlBar({required this.url, required this.onRefresh});

  final String url;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: GestureDetector(
        onLongPress: () => _copyUrl(context),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.surfaceHighlight),
          ),
          child: Row(
            children: [
              Icon(
                url.startsWith('https://')
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                size: 14,
                color: url.startsWith('https://')
                    ? AppColors.textMuted
                    : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  url,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _copyUrl(context),
                child: const Icon(Icons.copy_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyUrl(BuildContext context) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.webPreviewUrlCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
