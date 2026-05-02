import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import 'ssh_connection.dart';
import 'ssh_connection_service.dart';

class SshConnectionForm extends StatefulWidget {
  const SshConnectionForm({super.key, this.existing});
  final SshConnection? existing;

  @override
  State<SshConnectionForm> createState() => _SshConnectionFormState();
}

class _SshConnectionFormState extends State<SshConnectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _privateKey;
  late SshAuthType _authType;
  bool _obscurePassword = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _host = TextEditingController(text: e?.host ?? '');
    _port = TextEditingController(text: (e?.port ?? 22).toString());
    _username = TextEditingController(text: e?.username ?? '');
    _password = TextEditingController();
    _privateKey = TextEditingController();
    _authType = e?.authType ?? SshAuthType.password;

    if (_isEdit) _loadExistingSecret();
  }

  Future<void> _loadExistingSecret() async {
    final svc = context.read<SshConnectionService>();
    if (_authType == SshAuthType.password) {
      final pw = await svc.getPassword(widget.existing!.id);
      if (pw != null) _password.text = pw;
    } else {
      final key = await svc.getPrivateKey(widget.existing!.id);
      if (key != null) _privateKey.text = key;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _label, _host, _port, _username, _password, _privateKey
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = context.read<SshConnectionService>();
      final conn = SshConnection(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        label: _label.text.trim(),
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 22,
        username: _username.text.trim(),
        authType: _authType,
      );
      if (_isEdit) {
        await svc.update(
          conn,
          password:
              _authType == SshAuthType.password ? _password.text : null,
          privateKeyPem:
              _authType == SshAuthType.privateKey ? _privateKey.text : null,
        );
      } else {
        await svc.add(
          conn,
          password:
              _authType == SshAuthType.password ? _password.text : null,
          privateKeyPem:
              _authType == SshAuthType.privateKey ? _privateKey.text : null,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_isEdit
            ? AppLocalizations.of(context)!.sshFormEditTitle
            : AppLocalizations.of(context)!.sshFormNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_label, AppLocalizations.of(context)!.sshFieldLabel, validator: _required),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _field(_host, AppLocalizations.of(context)!.sshFieldHost,
                      keyboard: TextInputType.url,
                      validator: _required),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_port, AppLocalizations.of(context)!.sshFieldPort,
                      keyboard: TextInputType.number,
                      validator: (v) => (int.tryParse(v ?? '') == null)
                          ? AppLocalizations.of(context)!.sshFieldPortInvalid
                          : null),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field(_username, AppLocalizations.of(context)!.sshFieldUsername, validator: _required),
            const SizedBox(height: 20),
            _sectionLabel(AppLocalizations.of(context)!.sshAuthMethod),
            const SizedBox(height: 8),
            _authTypePicker(),
            const SizedBox(height: 14),
            if (_authType == SshAuthType.password) ...[
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.sshAuthPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _privateKey,
                maxLines: 8,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.sshPrivateKeyLabel,
                  hintText: AppLocalizations.of(context)!.sshPrivateKeyHint,
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? AppLocalizations.of(context)!.sshPrivateKeyRequired
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
      );

  Widget _authTypePicker() {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        _chip(SshAuthType.password, l.sshAuthPassword, Icons.password_rounded),
        const SizedBox(width: 10),
        _chip(SshAuthType.privateKey, l.sshAuthPrivateKey, Icons.key_rounded),
      ],
    );
  }

  Widget _chip(SshAuthType type, String label, IconData icon) {
    final selected = _authType == type;
    return GestureDetector(
      onTap: () => setState(() => _authType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.surfaceHighlight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? AppColors.primaryLight
                    : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.primaryLight
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.fieldRequired : null;
}
