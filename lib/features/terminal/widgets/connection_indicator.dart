import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';

import '../../../theme/app_theme.dart';
import '../ssh_service.dart';

// ── 接続状態インジケーター ────────────────────────────────────

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({required this.state});
  final SshConnectionState state;

  Color get _color => switch (state) {
        SshConnectionState.connected => AppColors.success,
        SshConnectionState.connecting => AppColors.warning,
        SshConnectionState.error => AppColors.error,
        SshConnectionState.disconnected => AppColors.textMuted,
      };

  String _label(AppLocalizations l) => switch (state) {
        SshConnectionState.connected => l.connectionStateConnected,
        SshConnectionState.connecting => l.connectionStateConnecting,
        SshConnectionState.error => l.connectionStateError,
        SshConnectionState.disconnected => l.connectionStateDisconnected,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: state == SshConnectionState.connected
                ? [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _label(AppLocalizations.of(context)!),
          style: TextStyle(
              color: _color, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
