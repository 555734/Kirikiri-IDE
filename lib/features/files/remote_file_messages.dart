import 'package:kirikiri/l10n/app_localizations.dart';

import 'remote_file_service.dart';

/// リモートファイル操作の失敗を表示用の文言に変換する。
String remoteFileFailureMessage(
  AppLocalizations l,
  RemoteFileException failure,
) {
  final message = switch (failure.kind) {
    RemoteFileFailureKind.notConnected => l.remoteFileErrorNotConnected,
    RemoteFileFailureKind.notText => l.remoteFileErrorNotText,
    RemoteFileFailureKind.tooLarge => l.remoteFileErrorTooLarge,
    RemoteFileFailureKind.failed => l.remoteFileErrorFailed,
  };
  final detail = failure.detail;
  return detail == null ? message : '$message ($detail)';
}
