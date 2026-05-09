import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../core/secure_storage_service.dart';
import '../../theme/app_theme.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final _urlCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _method = 'GET';
  final List<_Header> _headers = [];
  bool _loading = false;
  _ApiResponse? _response;

  static const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

  @override
  void dispose() {
    _urlCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _response = null;
    });

    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(url);
      final headers = {
        for (final h in _headers.where((h) => h.key.isNotEmpty))
          h.key: h.value,
      };
      final body = _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text;

      http.Response resp;
      switch (_method) {
        case 'POST':
          resp = await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));
        case 'PUT':
          resp = await http
              .put(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));
        case 'PATCH':
          resp = await http
              .patch(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));
        case 'DELETE':
          resp = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
        default:
          resp = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
      }

      sw.stop();
      if (mounted) {
        setState(() => _response = _ApiResponse(
              statusCode: resp.statusCode,
              body: resp.body,
              headers: resp.headers,
              ms: sw.elapsedMilliseconds,
            ));
      }
    } on TimeoutException {
      sw.stop();
      if (mounted) {
        setState(() => _response = _ApiResponse.error('Timeout (30s)'));
      }
    } catch (e) {
      sw.stop();
      if (mounted) {
        setState(() => _response = _ApiResponse.error(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addHeader({String key = '', String value = ''}) {
    setState(() => _headers.add(_Header(key: key, value: value)));
  }

  Future<void> _showApiKeyPicker(int headerIndex) async {
    final l = AppLocalizations.of(context)!;
    final raw = await SecureStorageService.instance.getApiKeys();
    if (!mounted) return;

    List<Map<String, String>> keys = [];
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      keys = list
          .map((e) => {
                'label': e['label'] as String,
                'key': e['key'] as String,
              })
          .toList();
    }

    if (!mounted) return;
    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.apiTestNoApiKeys)),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.apiTestInsertApiKey,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
          ...keys.map((k) => ListTile(
                leading: const Icon(Icons.vpn_key_rounded, size: 18),
                title: Text(k['label']!),
                subtitle: Text(
                  '${k['key']!.substring(0, k['key']!.length.clamp(0, 8))}••••',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _headers[headerIndex].value = k['key']!;
                  });
                },
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(l.apiTestTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // URL + Method row
                  Row(
                    children: [
                      _MethodPicker(
                        value: _method,
                        methods: _methods,
                        onChanged: (v) => setState(() => _method = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlCtrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'https://api.example.com/v1/...',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Headers
                  Row(
                    children: [
                      Text(l.apiTestHeaders,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addHeader,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l.apiTestAddHeader,
                            style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  if (_headers.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: _headers
                            .asMap()
                            .entries
                            .map((e) => _HeaderRow(
                                  key: ValueKey(e.key),
                                  header: e.value,
                                  onDelete: () => setState(
                                      () => _headers.removeAt(e.key)),
                                  onKeyPicker: () =>
                                      _showApiKeyPicker(e.key),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Body (POST/PUT/PATCH only)
                  if (_method == 'POST' ||
                      _method == 'PUT' ||
                      _method == 'PATCH') ...[
                    Text(l.apiTestBody,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 8,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '{"key": "value"}',
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Response
                  if (_response != null) ...[
                    _ResponseView(response: _response!, l: l),
                  ],
                ],
              ),
            ),
          ),

          // Send button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _send,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l.apiTestSend,
                          style: const TextStyle(fontSize: 15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Method picker ──────────────────────────────────────────

class _MethodPicker extends StatelessWidget {
  const _MethodPicker(
      {required this.value,
      required this.methods,
      required this.onChanged});
  final String value;
  final List<String> methods;
  final ValueChanged<String> onChanged;

  static Color _methodColor(String m) => switch (m) {
        'GET' => AppColors.success,
        'POST' => AppColors.primary,
        'PUT' => Colors.orange,
        'PATCH' => Colors.amber,
        'DELETE' => AppColors.error,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: methods
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m,
                        style: TextStyle(
                            color: _methodColor(m),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}

// ── Header row ────────────────────────────────────────────

class _Header {
  _Header({this.key = '', this.value = ''});
  String key;
  String value;
}

class _HeaderRow extends StatefulWidget {
  const _HeaderRow({
    super.key,
    required this.header,
    required this.onDelete,
    required this.onKeyPicker,
  });
  final _Header header;
  final VoidCallback onDelete;
  final VoidCallback onKeyPicker;

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valCtrl;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.header.key);
    _valCtrl = TextEditingController(text: widget.header.value);
  }

  @override
  void didUpdateWidget(_HeaderRow old) {
    super.didUpdateWidget(old);
    if (old.header != widget.header) {
      if (_valCtrl.text != widget.header.value) {
        _valCtrl.text = widget.header.value;
        _valCtrl.selection = TextSelection.collapsed(
            offset: widget.header.value.length);
      }
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _keyCtrl,
              onChanged: (v) => widget.header.key = v,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                  hintText: 'Key',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _valCtrl,
              onChanged: (v) => widget.header.value = v,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Value',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.vpn_key_rounded, size: 14),
                  onPressed: widget.onKeyPicker,
                  tooltip: 'API Key',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.textMuted),
            onPressed: widget.onDelete,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ── Response view ─────────────────────────────────────────

class _ApiResponse {
  _ApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.ms,
  }) : error = null;

  _ApiResponse.error(this.error)
      : statusCode = null,
        body = '',
        headers = {},
        ms = 0;

  final int? statusCode;
  final String body;
  final Map<String, String> headers;
  final int ms;
  final String? error;

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;
  bool get hasError => error != null;

  String get prettyBody {
    try {
      final decoded = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return body;
    }
  }
}

class _ResponseView extends StatefulWidget {
  const _ResponseView({required this.response, required this.l});
  final _ApiResponse response;
  final AppLocalizations l;

  @override
  State<_ResponseView> createState() => _ResponseViewState();
}

class _ResponseViewState extends State<_ResponseView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.response;
    final l = widget.l;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: r.hasError
                ? AppColors.error.withOpacity(0.1)
                : r.isSuccess
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                r.hasError
                    ? Icons.error_outline_rounded
                    : r.isSuccess
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                size: 16,
                color: r.hasError
                    ? AppColors.error
                    : r.isSuccess
                        ? AppColors.success
                        : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                r.hasError
                    ? r.error!
                    : 'HTTP ${r.statusCode}',
                style: TextStyle(
                  color: r.hasError
                      ? AppColors.error
                      : r.isSuccess
                          ? AppColors.success
                          : AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (!r.hasError)
                Text('${r.ms}ms',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        if (!r.hasError) ...[
          const SizedBox(height: 12),
          TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: l.apiTestResponse),
              Tab(text: l.apiTestHeaders),
            ],
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tab,
              children: [
                // Body tab
                Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        r.prettyBody,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon:
                            const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l.copy,
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: r.body));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.copied),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Headers tab
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: r.headers.entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(e.key,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontFamily: 'monospace')),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Text(e.value,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color:
                                              AppColors.textPrimary)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
