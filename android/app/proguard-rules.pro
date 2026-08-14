# ProGuard/R8 rules for release builds (minifyEnabled true)
#
# build.gradle がこのファイルを参照しているため、存在しないと R8 タスクが
# FileNotFoundException で失敗する。

# ── Flutter ────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── flutter_secure_storage (androidx.security / Tink) ─────
# EncryptedSharedPreferences はリフレクションで Tink のプリミティブを解決する
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ── google_sign_in (Google Play Services Auth) ────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# ── flutter_foreground_task ───────────────────────────────
-keep class com.pravera.flutter_foreground_task.** { *; }

# ── webview_flutter ───────────────────────────────────────
-keep class io.flutter.plugins.webviewflutter.** { *; }

# ── アノテーション/シグネチャの保持 ───────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# R8 full mode で欠落クラス警告をエラーにしない
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
