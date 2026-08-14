import 'package:kirikiri/l10n/app_localizations.dart';

import '../features/auth/google_auth_service.dart';
import '../features/cloudshell/cloud_shell_service.dart';
import '../features/github/github_service.dart';
import '../features/plugins/plugin_service.dart';

/// サービス層が返す失敗の種別を、表示用の文言へ変換する。
///
/// サービスは文言を持たず種別だけを返し、翻訳は UI 層のこの関数に集約する。
/// [AuthFailure.detail] などの技術的な詳細は翻訳せず括弧で添える。

String authFailureMessage(AppLocalizations l, AuthFailure failure) {
  final message = switch (failure.kind) {
    AuthFailureKind.cancelled => l.authErrorCancelled,
    AuthFailureKind.tokenUnavailable => l.authErrorTokenUnavailable,
    AuthFailureKind.signInFailed => l.authErrorSignInFailed,
  };
  return _withDetail(message, failure.detail);
}

String cloudShellFailureMessage(
  AppLocalizations l,
  CloudShellFailure failure,
) {
  final message = switch (failure.kind) {
    CloudShellFailureKind.notSignedIn => l.cloudShellErrorNotSignedIn,
    CloudShellFailureKind.authExpired => l.cloudShellErrorAuthExpired,
    CloudShellFailureKind.startTimeout => l.cloudShellErrorStartTimeout,
    CloudShellFailureKind.unknown => l.cloudShellErrorUnknown,
  };
  return _withDetail(message, failure.detail);
}

String gitHubFailureMessage(AppLocalizations l, GitHubFailure failure) {
  return switch (failure.kind) {
    GitHubFailureKind.invalidToken => l.githubErrorInvalidToken,
  };
}

String pluginFailureMessage(AppLocalizations l, PluginFailure failure) {
  final message = switch (failure.kind) {
    PluginFailureKind.downloadFailed => l.pluginErrorDownloadFailed,
    PluginFailureKind.manifestMissing => l.pluginErrorManifestMissing,
    PluginFailureKind.unsafePath => l.pluginErrorUnsafePath,
    PluginFailureKind.invalidRepoUrl => l.pluginErrorInvalidRepoUrl,
    PluginFailureKind.unknown => l.pluginErrorUnknown,
  };
  return _withDetail(message, failure.detail);
}

String _withDetail(String message, String? detail) =>
    detail == null ? message : '$message ($detail)';
