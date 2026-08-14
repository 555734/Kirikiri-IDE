import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/secure_storage_service.dart';

/// 認証に失敗した理由。表示文言は UI 層（ロケール）が決める。
enum AuthFailureKind {
  /// ユーザーがサインインを中断した
  cancelled,

  /// サインインは成功したがアクセストークンが得られなかった
  tokenUnavailable,

  /// 想定外のエラー（[AuthFailure.detail] に詳細）
  signInFailed,
}

class AuthFailure {
  const AuthFailure(this.kind, {this.detail});

  final AuthFailureKind kind;
  final String? detail;
}

/// Google Sign-In を使った認証サービス
/// flutter_web_auth_2 + 手動 PKCE の代わりに公式 SDK を使用
class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService({bool initiallyAuthenticated = false})
      : _isSignedIn = initiallyAuthenticated;

  final _storage = SecureStorageService.instance;

  static final _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/cloud-platform',
    ],
  );

  bool _isLoading = false;
  AuthFailure? _error;
  bool _isSignedIn;

  bool get isLoading => _isLoading;

  /// 直近の失敗。表示文言は UI 層（ロケール）が決める。
  AuthFailure? get error => _error;
  bool get isSignedIn => _isSignedIn;

  // ── 認証済みチェック (サイレントサインインで最新トークン取得) ──

  Future<bool> isAuthenticated() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          await _storage.saveAccessToken(auth.accessToken!);
          return true;
        }
      }
    } catch (_) {}
    final token = await _storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getAccessToken() async {
    // 現在のアカウントから最新トークンを取得
    final account = _googleSignIn.currentUser
        ?? await _googleSignIn.signInSilently();
    if (account != null) {
      final auth = await account.authentication;
      if (auth.accessToken != null) {
        await _storage.saveAccessToken(auth.accessToken!);
        return auth.accessToken;
      }
    }
    return _storage.getAccessToken();
  }

  // ── Google サインイン ─────────────────────────────────

  Future<void> signIn({required VoidCallback onSuccess}) async {
    _setLoading(true);
    _clearError();

    // Flutter イベントループを一度通過させてメインスレッドのデッドロックを回避
    await Future.delayed(Duration.zero);

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _setError(const AuthFailure(AuthFailureKind.cancelled));
        return;
      }

      final auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null) {
        _setError(const AuthFailure(AuthFailureKind.tokenUnavailable));
        return;
      }

      await _storage.saveAccessToken(accessToken);
      _isSignedIn = true;
      _setLoading(false);
      onSuccess();
    } catch (e) {
      _setError(
          AuthFailure(AuthFailureKind.signInFailed, detail: e.toString()));
    } finally {
      _setLoading(false);
    }
  }

  // ── ログアウト ────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    // Google認証情報とSSH鍵のみ削除。GitHub PAT・設定・プラグインは保持。
    await _storage.clearGoogleAuth();
    _isSignedIn = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(AuthFailure failure) {
    _error = failure;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
