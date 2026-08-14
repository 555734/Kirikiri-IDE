# ProGuard/R8 rules for release builds (minifyEnabled true)
#
# build.gradle がこのファイルを参照しているため、存在しないと R8 タスクが
# FileNotFoundException で失敗する。

# ── Flutter ────────────────────────────────────────────────
# io.flutter.** を丸ごと保持する（下位のパターンはこれに含まれるため不要）
-keep class io.flutter.** { *; }

# Flutter エンジンは遅延コンポーネント（Play Feature Delivery）用に
# Play Core を参照するが、このアプリは遅延コンポーネントを使わないので
# 依存を入れていない。AGP 8 では参照先の欠落がエラーになるため、
# 警告を抑止する。実行時に読み込まれることはない。
#   FlutterPlayStoreSplitApplication は AndroidManifest から参照されておらず
#   （${applicationName} は FlutterApplication に解決される）、
#   PlayStoreDeferredComponentManager も使用していない。
-dontwarn com.google.android.play.core.**

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
