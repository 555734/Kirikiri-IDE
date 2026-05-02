import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/screenshot_mode.dart';
import '../../theme/app_theme.dart';
import '../terminal/demo_terminal_screen.dart';
import '../terminal/terminal_controller.dart';
import '../terminal/terminal_screen.dart';
import 'ssh_connection.dart';
import 'ssh_connection_form.dart';
import 'ssh_connection_service.dart';

class SshServersScreen extends StatefulWidget {
  const SshServersScreen({super.key});

  @override
  State<SshServersScreen> createState() => _SshServersScreenState();
}

class _SshServersScreenState extends State<SshServersScreen> {
  static final _demoConnections = [
    const SshConnection(
        id: '1',
        label: 'Production',
        host: 'prod.example.com',
        port: 22,
        username: 'deploy',
        authType: SshAuthType.privateKey),
    const SshConnection(
        id: '2',
        label: 'Dev Server',
        host: '192.168.1.100',
        port: 2222,
        username: 'dev',
        authType: SshAuthType.password),
    const SshConnection(
        id: '3',
        label: 'Raspberry Pi',
        host: 'raspberrypi.local',
        port: 22,
        username: 'pi',
        authType: SshAuthType.privateKey),
  ];

  @override
  void initState() {
    super.initState();
    if (kDemoMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SshConnectionService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context)!.sshServersTitle),
      ),
      body: kDemoMode
          ? ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _demoConnections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _ConnectionCard(conn: _demoConnections[i]),
            )
          : Consumer<SshConnectionService>(
        builder: (context, svc, _) {
          if (svc.connections.isEmpty) {
            return _buildEmpty(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: svc.connections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _ConnectionCard(conn: svc.connections[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const SshConnectionForm(),
        )),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: Text(AppLocalizations.of(context)!.sshAddConnection),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_rounded,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.sshServersEmpty,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.sshServersEmptyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SshConnectionForm(),
            )),
            icon: const Icon(Icons.add_rounded),
            label: Text(AppLocalizations.of(context)!.sshAddConnection),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.conn});
  final SshConnection conn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _connect(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.computer_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conn.label,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${conn.username}@${conn.displayHost}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              _authBadge(),
              const SizedBox(width: 4),
              PopupMenuButton<_Action>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                color: AppColors.surfaceVariant,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (ctx) {
                  final l = AppLocalizations.of(ctx)!;
                  return [
                    PopupMenuItem(
                      value: _Action.connect,
                      child: Row(children: [
                        const Icon(Icons.terminal_rounded, size: 16),
                        const SizedBox(width: 10),
                        Text(l.sshConnectButton),
                      ]),
                    ),
                    PopupMenuItem(
                      value: _Action.edit,
                      child: Row(children: [
                        const Icon(Icons.edit_rounded, size: 16),
                        const SizedBox(width: 10),
                        Text(l.sshEditButton),
                      ]),
                    ),
                    PopupMenuItem(
                      value: _Action.delete,
                      child: Row(children: [
                        const Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text(l.sshDeleteButton,
                            style: const TextStyle(color: AppColors.errorLight)),
                      ]),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authBadge() {
    final isKey = conn.authType == SshAuthType.privateKey;
    return Tooltip(
      message: isKey ? '秘密鍵認証' : 'パスワード認証',
      child: Icon(
        isKey ? Icons.key_rounded : Icons.password_rounded,
        size: 16,
        color: AppColors.textMuted,
      ),
    );
  }

  void _onAction(BuildContext context, _Action action) {
    switch (action) {
      case _Action.connect:
        _connect(context);
      case _Action.edit:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SshConnectionForm(existing: conn),
        ));
      case _Action.delete:
        _confirmDelete(context);
    }
  }

  Future<void> _connect(BuildContext context) async {
    if (kDemoMode) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DemoTerminalScreen(title: conn.label),
      ));
      return;
    }

    final svc = context.read<SshConnectionService>();
    final password = conn.authType == SshAuthType.password
        ? await svc.getPassword(conn.id)
        : null;
    final privateKey = conn.authType == SshAuthType.privateKey
        ? await svc.getPrivateKey(conn.id)
        : null;

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => TerminalController(
          workspaceId: conn.label,
          sshHost: conn.host,
          ownerToken: password,
          sshPrivateKeyPem:
              (privateKey != null && privateKey.isNotEmpty)
                  ? privateKey
                  : null,
          sshUsername: conn.username,
          sshPort: conn.port,
        ),
        child: const TerminalScreen(),
      ),
    ));
  }

  void _confirmDelete(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.sshDeleteConnection),
        content: Text('「${conn.label}」${l.sshDeleteConfirm}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SshConnectionService>().remove(conn.id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }
}

enum _Action { connect, edit, delete }
