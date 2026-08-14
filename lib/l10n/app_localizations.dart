import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @appName.
  ///
  /// In ja, this message translates to:
  /// **'kirikiri'**
  String get appName;

  /// No description provided for @tabCloudShell.
  ///
  /// In ja, this message translates to:
  /// **'Cloud Shell'**
  String get tabCloudShell;

  /// No description provided for @tabRepository.
  ///
  /// In ja, this message translates to:
  /// **'リポジトリ'**
  String get tabRepository;

  /// No description provided for @tabSsh.
  ///
  /// In ja, this message translates to:
  /// **'SSH'**
  String get tabSsh;

  /// No description provided for @tabAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウント'**
  String get tabAccount;

  /// No description provided for @skip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get skip;

  /// No description provided for @later.
  ///
  /// In ja, this message translates to:
  /// **'あとで'**
  String get later;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get retry;

  /// No description provided for @connect.
  ///
  /// In ja, this message translates to:
  /// **'接続'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In ja, this message translates to:
  /// **'切断'**
  String get disconnect;

  /// No description provided for @logout.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'Googleアカウントからログアウトしますか？'**
  String get logoutConfirmBody;

  /// No description provided for @logoutTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get logoutTooltip;

  /// No description provided for @loginWithGoogle.
  ///
  /// In ja, this message translates to:
  /// **'Googleアカウントでログイン'**
  String get loginWithGoogle;

  /// No description provided for @loggingIn.
  ///
  /// In ja, this message translates to:
  /// **'ログイン中...'**
  String get loggingIn;

  /// No description provided for @loginWithoutAccount.
  ///
  /// In ja, this message translates to:
  /// **'ログインせずに使う'**
  String get loginWithoutAccount;

  /// No description provided for @googleAccountOnly.
  ///
  /// In ja, this message translates to:
  /// **'Googleアカウントのみ使用。\nトークンはデバイスに安全に保存されます。'**
  String get googleAccountOnly;

  /// No description provided for @tryDemo.
  ///
  /// In ja, this message translates to:
  /// **'デモを試す（アカウント不要）'**
  String get tryDemo;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In ja, this message translates to:
  /// **'ようこそ\nkirikiri へ'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In ja, this message translates to:
  /// **'スマートフォンで本格的なクラウド開発を。\nいつでもどこでも、開発環境が手の中に。'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingTerminalTitle.
  ///
  /// In ja, this message translates to:
  /// **'ターミナルを\n手のひらで'**
  String get onboardingTerminalTitle;

  /// No description provided for @onboardingTerminalBody.
  ///
  /// In ja, this message translates to:
  /// **'Google Cloud Shell にワンタップ接続。\nLinuxコマンドの実行・デプロイまで\nスマホで完結します。'**
  String get onboardingTerminalBody;

  /// No description provided for @onboardingGithubTitle.
  ///
  /// In ja, this message translates to:
  /// **'GitHub と\nシームレス連携'**
  String get onboardingGithubTitle;

  /// No description provided for @onboardingGithubBody.
  ///
  /// In ja, this message translates to:
  /// **'リポジトリを一覧し、タップするだけで\nCloud Shell で即開きます。\nコードとターミナルを自在に行き来。'**
  String get onboardingGithubBody;

  /// No description provided for @onboardingCommandsTitle.
  ///
  /// In ja, this message translates to:
  /// **'FPS感覚の\nコマンド操作'**
  String get onboardingCommandsTitle;

  /// No description provided for @onboardingCommandsBody.
  ///
  /// In ja, this message translates to:
  /// **'頻出コマンドを丸ボタンに登録して\n画面に自由配置。タップで即入力、\nゲームのような快速操作感。'**
  String get onboardingCommandsBody;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In ja, this message translates to:
  /// **'Google で\nサインインする'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingSignInBody.
  ///
  /// In ja, this message translates to:
  /// **'Cloud Shell の利用にはGoogleアカウントが必要です。あとからでも設定できます。'**
  String get onboardingSignInBody;

  /// No description provided for @letsGo.
  ///
  /// In ja, this message translates to:
  /// **'さあ、始めよう'**
  String get letsGo;

  /// No description provided for @cloudShellTitle.
  ///
  /// In ja, this message translates to:
  /// **'Google Cloud Shell'**
  String get cloudShellTitle;

  /// No description provided for @cloudShellSignInPrompt.
  ///
  /// In ja, this message translates to:
  /// **'Googleアカウントでサインインして\nCloud Shell を使用できます'**
  String get cloudShellSignInPrompt;

  /// No description provided for @cloudShellStarting.
  ///
  /// In ja, this message translates to:
  /// **'Cloud Shell を起動中...'**
  String get cloudShellStarting;

  /// No description provided for @cloudShellFirstLaunchNote.
  ///
  /// In ja, this message translates to:
  /// **'初回は30秒ほどかかることがあります'**
  String get cloudShellFirstLaunchNote;

  /// No description provided for @startupStepPreparingKey.
  ///
  /// In ja, this message translates to:
  /// **'SSH 鍵を準備中'**
  String get startupStepPreparingKey;

  /// No description provided for @startupStepCheckingState.
  ///
  /// In ja, this message translates to:
  /// **'環境の状態を確認中'**
  String get startupStepCheckingState;

  /// No description provided for @startupStepStarting.
  ///
  /// In ja, this message translates to:
  /// **'環境を起動中'**
  String get startupStepStarting;

  /// No description provided for @startupStepWaitingRunning.
  ///
  /// In ja, this message translates to:
  /// **'起動完了を待機中'**
  String get startupStepWaitingRunning;

  /// No description provided for @startupStepRegisteringKey.
  ///
  /// In ja, this message translates to:
  /// **'SSH 鍵を登録中'**
  String get startupStepRegisteringKey;

  /// No description provided for @startupElapsed.
  ///
  /// In ja, this message translates to:
  /// **'{seconds}秒経過'**
  String startupElapsed(int seconds);

  /// No description provided for @cloudShellRunning.
  ///
  /// In ja, this message translates to:
  /// **'Cloud Shell 起動中'**
  String get cloudShellRunning;

  /// No description provided for @cloudShellStopped.
  ///
  /// In ja, this message translates to:
  /// **'Cloud Shell は停止中です'**
  String get cloudShellStopped;

  /// No description provided for @cloudShellStartButton.
  ///
  /// In ja, this message translates to:
  /// **'起動する'**
  String get cloudShellStartButton;

  /// No description provided for @openTerminal.
  ///
  /// In ja, this message translates to:
  /// **'ターミナルを開く'**
  String get openTerminal;

  /// No description provided for @preparingRepo.
  ///
  /// In ja, this message translates to:
  /// **'{repo} を準備中...'**
  String preparingRepo(String repo);

  /// No description provided for @cloudShellError.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました'**
  String get cloudShellError;

  /// No description provided for @sshConnecting.
  ///
  /// In ja, this message translates to:
  /// **'SSH 接続中...'**
  String get sshConnecting;

  /// No description provided for @sshConnectingToServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバーに接続しています'**
  String get sshConnectingToServer;

  /// No description provided for @connectionError.
  ///
  /// In ja, this message translates to:
  /// **'接続エラー'**
  String get connectionError;

  /// No description provided for @reconnect.
  ///
  /// In ja, this message translates to:
  /// **'再接続する'**
  String get reconnect;

  /// No description provided for @showSshLog.
  ///
  /// In ja, this message translates to:
  /// **'SSHログを表示'**
  String get showSshLog;

  /// No description provided for @sshLog.
  ///
  /// In ja, this message translates to:
  /// **'SSH 接続ログ'**
  String get sshLog;

  /// No description provided for @noLogs.
  ///
  /// In ja, this message translates to:
  /// **'ログなし'**
  String get noLogs;

  /// No description provided for @paste.
  ///
  /// In ja, this message translates to:
  /// **'ペースト'**
  String get paste;

  /// No description provided for @copy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In ja, this message translates to:
  /// **'コピーしました'**
  String get copied;

  /// No description provided for @dragToSelect.
  ///
  /// In ja, this message translates to:
  /// **'テキストをドラッグして選択してください'**
  String get dragToSelect;

  /// No description provided for @commandButtonAdd.
  ///
  /// In ja, this message translates to:
  /// **'コマンドボタンを追加'**
  String get commandButtonAdd;

  /// No description provided for @commandButtonEdit.
  ///
  /// In ja, this message translates to:
  /// **'ボタンを編集'**
  String get commandButtonEdit;

  /// No description provided for @commandButtonLabel.
  ///
  /// In ja, this message translates to:
  /// **'ラベル（例: ls, git, clear）'**
  String get commandButtonLabel;

  /// No description provided for @commandButtonLabelShort.
  ///
  /// In ja, this message translates to:
  /// **'ラベル'**
  String get commandButtonLabelShort;

  /// No description provided for @commandButtonCommand.
  ///
  /// In ja, this message translates to:
  /// **'コマンド'**
  String get commandButtonCommand;

  /// No description provided for @buttonsDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get buttonsDone;

  /// No description provided for @buttonsEdit.
  ///
  /// In ja, this message translates to:
  /// **'ボタン'**
  String get buttonsEdit;

  /// No description provided for @portPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'ポートを選択'**
  String get portPickerTitle;

  /// No description provided for @portPickerBody.
  ///
  /// In ja, this message translates to:
  /// **'プレビューするサーバーのポートを選んでください'**
  String get portPickerBody;

  /// No description provided for @portPickerCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタムポート'**
  String get portPickerCustom;

  /// No description provided for @open.
  ///
  /// In ja, this message translates to:
  /// **'開く'**
  String get open;

  /// No description provided for @preview.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get preview;

  /// No description provided for @run.
  ///
  /// In ja, this message translates to:
  /// **'実行'**
  String get run;

  /// No description provided for @repository.
  ///
  /// In ja, this message translates to:
  /// **'リポジトリ'**
  String get repository;

  /// No description provided for @reconnectButton.
  ///
  /// In ja, this message translates to:
  /// **'再接続'**
  String get reconnectButton;

  /// No description provided for @fontSizeLabel.
  ///
  /// In ja, this message translates to:
  /// **'フォントサイズ'**
  String get fontSizeLabel;

  /// No description provided for @tuiUploading.
  ///
  /// In ja, this message translates to:
  /// **'ツールをアップロード中'**
  String get tuiUploading;

  /// No description provided for @tuiLaunchError.
  ///
  /// In ja, this message translates to:
  /// **'TUI起動エラー: {error}'**
  String tuiLaunchError(String error);

  /// No description provided for @commandInputHint.
  ///
  /// In ja, this message translates to:
  /// **'コマンドを入力...'**
  String get commandInputHint;

  /// No description provided for @favoriteAlreadyExists.
  ///
  /// In ja, this message translates to:
  /// **'すでに登録済みです'**
  String get favoriteAlreadyExists;

  /// No description provided for @favoriteAdded.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りに追加しました'**
  String get favoriteAdded;

  /// No description provided for @undo.
  ///
  /// In ja, this message translates to:
  /// **'元に戻す'**
  String get undo;

  /// No description provided for @deleteFavorite.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りを削除'**
  String get deleteFavorite;

  /// No description provided for @githubConnect.
  ///
  /// In ja, this message translates to:
  /// **'GitHub に接続'**
  String get githubConnect;

  /// No description provided for @githubPatDescription.
  ///
  /// In ja, this message translates to:
  /// **'Personal Access Token (PAT) を入力してください。\nリポジトリの読み書きには repo スコープが必要です。'**
  String get githubPatDescription;

  /// No description provided for @githubPatPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'ghp_xxxxxxxxxxxxxxxxxxxx'**
  String get githubPatPlaceholder;

  /// No description provided for @githubConnectButton.
  ///
  /// In ja, this message translates to:
  /// **'接続する'**
  String get githubConnectButton;

  /// No description provided for @githubGeneratePat.
  ///
  /// In ja, this message translates to:
  /// **'PAT を生成する (GitHub)'**
  String get githubGeneratePat;

  /// No description provided for @repoSearch.
  ///
  /// In ja, this message translates to:
  /// **'リポジトリを検索...'**
  String get repoSearch;

  /// No description provided for @repoNotFound.
  ///
  /// In ja, this message translates to:
  /// **'リポジトリが見つかりません'**
  String get repoNotFound;

  /// No description provided for @openInShell.
  ///
  /// In ja, this message translates to:
  /// **'Shell で開く'**
  String get openInShell;

  /// No description provided for @noFiles.
  ///
  /// In ja, this message translates to:
  /// **'ファイルなし'**
  String get noFiles;

  /// No description provided for @relativeTimeToday.
  ///
  /// In ja, this message translates to:
  /// **'今日'**
  String get relativeTimeToday;

  /// No description provided for @relativeTimeYesterday.
  ///
  /// In ja, this message translates to:
  /// **'昨日'**
  String get relativeTimeYesterday;

  /// No description provided for @relativeTimeDaysAgo.
  ///
  /// In ja, this message translates to:
  /// **'{days}日前'**
  String relativeTimeDaysAgo(int days);

  /// No description provided for @relativeTimeMonthsAgo.
  ///
  /// In ja, this message translates to:
  /// **'{months}ヶ月前'**
  String relativeTimeMonthsAgo(int months);

  /// No description provided for @relativeTimeYearsAgo.
  ///
  /// In ja, this message translates to:
  /// **'{years}年前'**
  String relativeTimeYearsAgo(int years);

  /// No description provided for @commitSave.
  ///
  /// In ja, this message translates to:
  /// **'保存 (コミット)'**
  String get commitSave;

  /// No description provided for @commitMessageTitle.
  ///
  /// In ja, this message translates to:
  /// **'コミットメッセージ'**
  String get commitMessageTitle;

  /// No description provided for @commitMessageHint.
  ///
  /// In ja, this message translates to:
  /// **'コミットメッセージを入力'**
  String get commitMessageHint;

  /// No description provided for @commit.
  ///
  /// In ja, this message translates to:
  /// **'コミット'**
  String get commit;

  /// No description provided for @binaryFileNotSupported.
  ///
  /// In ja, this message translates to:
  /// **'バイナリファイルは表示できません'**
  String get binaryFileNotSupported;

  /// No description provided for @fileSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get fileSaved;

  /// No description provided for @fileSaveError.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました: {error}'**
  String fileSaveError(String error);

  /// No description provided for @sshServersTitle.
  ///
  /// In ja, this message translates to:
  /// **'SSH サーバー'**
  String get sshServersTitle;

  /// No description provided for @sshServersEmpty.
  ///
  /// In ja, this message translates to:
  /// **'SSH サーバーが登録されていません'**
  String get sshServersEmpty;

  /// No description provided for @sshServersEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'ホスト・ポート・認証情報を保存して\nワンタップで接続できます'**
  String get sshServersEmptyHint;

  /// No description provided for @sshAddConnection.
  ///
  /// In ja, this message translates to:
  /// **'接続を追加'**
  String get sshAddConnection;

  /// No description provided for @sshDeleteConnection.
  ///
  /// In ja, this message translates to:
  /// **'接続を削除'**
  String get sshDeleteConnection;

  /// No description provided for @sshDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'削除しますか？'**
  String get sshDeleteConfirm;

  /// No description provided for @sshConnectButton.
  ///
  /// In ja, this message translates to:
  /// **'接続'**
  String get sshConnectButton;

  /// No description provided for @sshEditButton.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get sshEditButton;

  /// No description provided for @sshDeleteButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get sshDeleteButton;

  /// No description provided for @sshFormEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'接続を編集'**
  String get sshFormEditTitle;

  /// No description provided for @sshFormNewTitle.
  ///
  /// In ja, this message translates to:
  /// **'新しい接続'**
  String get sshFormNewTitle;

  /// No description provided for @sshFieldLabel.
  ///
  /// In ja, this message translates to:
  /// **'ラベル（表示名）'**
  String get sshFieldLabel;

  /// No description provided for @sshFieldHost.
  ///
  /// In ja, this message translates to:
  /// **'ホスト / IP'**
  String get sshFieldHost;

  /// No description provided for @sshFieldPort.
  ///
  /// In ja, this message translates to:
  /// **'ポート'**
  String get sshFieldPort;

  /// No description provided for @sshFieldPortInvalid.
  ///
  /// In ja, this message translates to:
  /// **'数値'**
  String get sshFieldPortInvalid;

  /// No description provided for @sshFieldUsername.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名'**
  String get sshFieldUsername;

  /// No description provided for @sshAuthMethod.
  ///
  /// In ja, this message translates to:
  /// **'認証方式'**
  String get sshAuthMethod;

  /// No description provided for @sshAuthPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワード'**
  String get sshAuthPassword;

  /// No description provided for @sshAuthPrivateKey.
  ///
  /// In ja, this message translates to:
  /// **'秘密鍵'**
  String get sshAuthPrivateKey;

  /// No description provided for @sshPrivateKeyLabel.
  ///
  /// In ja, this message translates to:
  /// **'秘密鍵 (PEM形式)'**
  String get sshPrivateKeyLabel;

  /// No description provided for @sshPrivateKeyHint.
  ///
  /// In ja, this message translates to:
  /// **'-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----'**
  String get sshPrivateKeyHint;

  /// No description provided for @sshPrivateKeyRequired.
  ///
  /// In ja, this message translates to:
  /// **'秘密鍵を入力してください'**
  String get sshPrivateKeyRequired;

  /// No description provided for @fieldRequired.
  ///
  /// In ja, this message translates to:
  /// **'必須項目です'**
  String get fieldRequired;

  /// No description provided for @pluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get pluginsTitle;

  /// No description provided for @pluginStoreTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインストア'**
  String get pluginStoreTitle;

  /// No description provided for @pluginAddTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを追加'**
  String get pluginAddTitle;

  /// No description provided for @pluginAddDescription.
  ///
  /// In ja, this message translates to:
  /// **'GitHubリポジトリのURLを入力してインストールします。\nリポジトリのルートに plugin.json が必要です。'**
  String get pluginAddDescription;

  /// No description provided for @pluginUrlHint.
  ///
  /// In ja, this message translates to:
  /// **'https://github.com/owner/repo'**
  String get pluginUrlHint;

  /// No description provided for @pluginInstall.
  ///
  /// In ja, this message translates to:
  /// **'インストール'**
  String get pluginInstall;

  /// No description provided for @pluginInstallProgress.
  ///
  /// In ja, this message translates to:
  /// **'{progress}% 完了'**
  String pluginInstallProgress(int progress);

  /// No description provided for @pluginInstalledEmpty.
  ///
  /// In ja, this message translates to:
  /// **'プラグインがインストールされていません'**
  String get pluginInstalledEmpty;

  /// No description provided for @pluginInstalledCount.
  ///
  /// In ja, this message translates to:
  /// **'インストール済み ({count})'**
  String pluginInstalledCount(int count);

  /// No description provided for @pluginToolbarButtons.
  ///
  /// In ja, this message translates to:
  /// **'ツールバーボタン'**
  String get pluginToolbarButtons;

  /// No description provided for @pluginCommandChips.
  ///
  /// In ja, this message translates to:
  /// **'コマンドチップ'**
  String get pluginCommandChips;

  /// No description provided for @pluginMenuItems.
  ///
  /// In ja, this message translates to:
  /// **'メニュー項目'**
  String get pluginMenuItems;

  /// No description provided for @pluginPermissions.
  ///
  /// In ja, this message translates to:
  /// **'パーミッション'**
  String get pluginPermissions;

  /// No description provided for @pluginUninstall.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを削除'**
  String get pluginUninstall;

  /// No description provided for @pluginUninstallConfirm.
  ///
  /// In ja, this message translates to:
  /// **'アンインストールしますか？'**
  String get pluginUninstallConfirm;

  /// No description provided for @pluginStoreSort.
  ///
  /// In ja, this message translates to:
  /// **'並び替え'**
  String get pluginStoreSort;

  /// No description provided for @pluginStoreSortStars.
  ///
  /// In ja, this message translates to:
  /// **'スター数順'**
  String get pluginStoreSortStars;

  /// No description provided for @pluginStoreSortUpdated.
  ///
  /// In ja, this message translates to:
  /// **'更新日順'**
  String get pluginStoreSortUpdated;

  /// No description provided for @pluginStoreSearch.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを検索...'**
  String get pluginStoreSearch;

  /// No description provided for @pluginStoreDisclaimer.
  ///
  /// In ja, this message translates to:
  /// **'コミュニティ製プラグインです。内容を確認してからインストールしてください。'**
  String get pluginStoreDisclaimer;

  /// No description provided for @pluginStoreEmpty.
  ///
  /// In ja, this message translates to:
  /// **'プラグインが見つかりません'**
  String get pluginStoreEmpty;

  /// No description provided for @pluginStoreTopicHint.
  ///
  /// In ja, this message translates to:
  /// **'GitHubリポジトリに topic: kirikiri-plugin を設定するとここに表示されます'**
  String get pluginStoreTopicHint;

  /// No description provided for @pluginAlreadyInstalled.
  ///
  /// In ja, this message translates to:
  /// **'✓ インストール済み'**
  String get pluginAlreadyInstalled;

  /// No description provided for @pluginInstalled.
  ///
  /// In ja, this message translates to:
  /// **'インストールしました'**
  String get pluginInstalled;

  /// No description provided for @pluginInstallError.
  ///
  /// In ja, this message translates to:
  /// **'エラー: {error}'**
  String pluginInstallError(String error);

  /// No description provided for @pluginLabel.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get pluginLabel;

  /// No description provided for @relativeTimeWeeksAgo.
  ///
  /// In ja, this message translates to:
  /// **'{weeks}週間前'**
  String relativeTimeWeeksAgo(int weeks);

  /// No description provided for @authSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'Google Cloud Shell をスマホから'**
  String get authSubtitle;

  /// No description provided for @authPrivacyNote.
  ///
  /// In ja, this message translates to:
  /// **'Googleアカウントのみ使用。\nトークンはデバイスに安全に保存されます。'**
  String get authPrivacyNote;

  /// No description provided for @appearanceSection.
  ///
  /// In ja, this message translates to:
  /// **'外観'**
  String get appearanceSection;

  /// No description provided for @darkMode.
  ///
  /// In ja, this message translates to:
  /// **'ダークモード'**
  String get darkMode;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'アプリ全体を暗い配色に変更します'**
  String get darkModeSubtitle;

  /// No description provided for @githubSection.
  ///
  /// In ja, this message translates to:
  /// **'GitHub'**
  String get githubSection;

  /// No description provided for @githubLoggedIn.
  ///
  /// In ja, this message translates to:
  /// **'ログイン中'**
  String get githubLoggedIn;

  /// No description provided for @githubNotConnected.
  ///
  /// In ja, this message translates to:
  /// **'GitHubに未接続'**
  String get githubNotConnected;

  /// No description provided for @githubNotConnectedHint.
  ///
  /// In ja, this message translates to:
  /// **'リポジトリタブからPATを設定できます'**
  String get githubNotConnectedHint;

  /// No description provided for @githubUpdatePat.
  ///
  /// In ja, this message translates to:
  /// **'Personal Access Token を更新'**
  String get githubUpdatePat;

  /// No description provided for @apiKeysSection.
  ///
  /// In ja, this message translates to:
  /// **'APIキー'**
  String get apiKeysSection;

  /// No description provided for @apiKeysEmpty.
  ///
  /// In ja, this message translates to:
  /// **'APIキーはまだ登録されていません'**
  String get apiKeysEmpty;

  /// No description provided for @apiKeyAdd.
  ///
  /// In ja, this message translates to:
  /// **'APIキーを追加'**
  String get apiKeyAdd;

  /// No description provided for @apiKeyEdit.
  ///
  /// In ja, this message translates to:
  /// **'APIキーを編集'**
  String get apiKeyEdit;

  /// No description provided for @apiKeyLabelHint.
  ///
  /// In ja, this message translates to:
  /// **'ラベル (例: OpenAI)'**
  String get apiKeyLabelHint;

  /// No description provided for @apiKeyFieldLabel.
  ///
  /// In ja, this message translates to:
  /// **'APIキー'**
  String get apiKeyFieldLabel;

  /// No description provided for @commandSnippetsSection.
  ///
  /// In ja, this message translates to:
  /// **'コマンドスニペット'**
  String get commandSnippetsSection;

  /// No description provided for @commandSnippetsHint.
  ///
  /// In ja, this message translates to:
  /// **'よく使うコマンドを登録しておけます'**
  String get commandSnippetsHint;

  /// No description provided for @commandSnippetAdd.
  ///
  /// In ja, this message translates to:
  /// **'コマンドを追加'**
  String get commandSnippetAdd;

  /// No description provided for @commandSnippetEdit.
  ///
  /// In ja, this message translates to:
  /// **'コマンドを編集'**
  String get commandSnippetEdit;

  /// No description provided for @commandSnippetLabelHint.
  ///
  /// In ja, this message translates to:
  /// **'ラベル (例: git status)'**
  String get commandSnippetLabelHint;

  /// No description provided for @commandSnippetCommandLabel.
  ///
  /// In ja, this message translates to:
  /// **'コマンド'**
  String get commandSnippetCommandLabel;

  /// No description provided for @aboutSection.
  ///
  /// In ja, this message translates to:
  /// **'このアプリについて'**
  String get aboutSection;

  /// No description provided for @termsOfUse.
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get privacyPolicy;

  /// No description provided for @version.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get version;

  /// No description provided for @tunnelActive.
  ///
  /// In ja, this message translates to:
  /// **'アクティブ'**
  String get tunnelActive;

  /// No description provided for @tunnelStop.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get tunnelStop;

  /// No description provided for @portDetect.
  ///
  /// In ja, this message translates to:
  /// **'検出'**
  String get portDetect;

  /// No description provided for @portDetecting.
  ///
  /// In ja, this message translates to:
  /// **'スキャン中...'**
  String get portDetecting;

  /// No description provided for @portDetectedNone.
  ///
  /// In ja, this message translates to:
  /// **'ポートが見つかりません'**
  String get portDetectedNone;

  /// No description provided for @savedPorts.
  ///
  /// In ja, this message translates to:
  /// **'保存済みポート'**
  String get savedPorts;

  /// No description provided for @addPort.
  ///
  /// In ja, this message translates to:
  /// **'ポートを追加'**
  String get addPort;

  /// No description provided for @portLabel.
  ///
  /// In ja, this message translates to:
  /// **'ラベル'**
  String get portLabel;

  /// No description provided for @portNumber.
  ///
  /// In ja, this message translates to:
  /// **'ポート番号'**
  String get portNumber;

  /// No description provided for @launcherTitle.
  ///
  /// In ja, this message translates to:
  /// **'ランチャー'**
  String get launcherTitle;

  /// No description provided for @launcherAddCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリを追加'**
  String get launcherAddCategory;

  /// No description provided for @launcherAddCommand.
  ///
  /// In ja, this message translates to:
  /// **'コマンドを追加'**
  String get launcherAddCommand;

  /// No description provided for @launcherCategoryLabel.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ名'**
  String get launcherCategoryLabel;

  /// No description provided for @launcherIcon.
  ///
  /// In ja, this message translates to:
  /// **'アイコン（絵文字）'**
  String get launcherIcon;

  /// No description provided for @launcherCommandLabel.
  ///
  /// In ja, this message translates to:
  /// **'ラベル'**
  String get launcherCommandLabel;

  /// No description provided for @launcherCommandHint.
  ///
  /// In ja, this message translates to:
  /// **'コマンド'**
  String get launcherCommandHint;

  /// No description provided for @launcherEmptyCategories.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリがありません。＋をタップして追加してください。'**
  String get launcherEmptyCategories;

  /// No description provided for @launcherEmptyCommands.
  ///
  /// In ja, this message translates to:
  /// **'コマンドがありません。'**
  String get launcherEmptyCommands;

  /// No description provided for @launcherRun.
  ///
  /// In ja, this message translates to:
  /// **'実行'**
  String get launcherRun;

  /// No description provided for @launcherDeleteCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリを削除'**
  String get launcherDeleteCategory;

  /// No description provided for @cicdTitle.
  ///
  /// In ja, this message translates to:
  /// **'CI/CD'**
  String get cicdTitle;

  /// No description provided for @cicdNoRuns.
  ///
  /// In ja, this message translates to:
  /// **'ワークフローの実行履歴がありません'**
  String get cicdNoRuns;

  /// No description provided for @cicdNoJobs.
  ///
  /// In ja, this message translates to:
  /// **'ジョブが見つかりません'**
  String get cicdNoJobs;

  /// No description provided for @cicdRunning.
  ///
  /// In ja, this message translates to:
  /// **'実行中'**
  String get cicdRunning;

  /// No description provided for @branchesTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブランチ'**
  String get branchesTitle;

  /// No description provided for @pullRequestsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プルリクエスト'**
  String get pullRequestsTitle;

  /// No description provided for @branchNew.
  ///
  /// In ja, this message translates to:
  /// **'新しいブランチ'**
  String get branchNew;

  /// No description provided for @branchName.
  ///
  /// In ja, this message translates to:
  /// **'ブランチ名'**
  String get branchName;

  /// No description provided for @branchFrom.
  ///
  /// In ja, this message translates to:
  /// **'元のブランチ'**
  String get branchFrom;

  /// No description provided for @branchDelete.
  ///
  /// In ja, this message translates to:
  /// **'ブランチを削除'**
  String get branchDelete;

  /// No description provided for @branchDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'このブランチを削除しますか？'**
  String get branchDeleteConfirm;

  /// No description provided for @branchProtected.
  ///
  /// In ja, this message translates to:
  /// **'保護済み'**
  String get branchProtected;

  /// No description provided for @branchesEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ブランチがありません'**
  String get branchesEmpty;

  /// No description provided for @prNew.
  ///
  /// In ja, this message translates to:
  /// **'新しいプルリクエスト'**
  String get prNew;

  /// No description provided for @prTitleLabel.
  ///
  /// In ja, this message translates to:
  /// **'タイトル'**
  String get prTitleLabel;

  /// No description provided for @prBodyLabel.
  ///
  /// In ja, this message translates to:
  /// **'説明（任意）'**
  String get prBodyLabel;

  /// No description provided for @prCreate.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get prCreate;

  /// No description provided for @prHead.
  ///
  /// In ja, this message translates to:
  /// **'ヘッドブランチ'**
  String get prHead;

  /// No description provided for @prBase.
  ///
  /// In ja, this message translates to:
  /// **'ベースブランチ'**
  String get prBase;

  /// No description provided for @prStateOpen.
  ///
  /// In ja, this message translates to:
  /// **'オープン'**
  String get prStateOpen;

  /// No description provided for @prStateClosed.
  ///
  /// In ja, this message translates to:
  /// **'クローズ'**
  String get prStateClosed;

  /// No description provided for @prEmpty.
  ///
  /// In ja, this message translates to:
  /// **'プルリクエストがありません'**
  String get prEmpty;

  /// No description provided for @apiTestTitle.
  ///
  /// In ja, this message translates to:
  /// **'APIテスト'**
  String get apiTestTitle;

  /// No description provided for @apiTestSend.
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get apiTestSend;

  /// No description provided for @apiTestResponse.
  ///
  /// In ja, this message translates to:
  /// **'レスポンス'**
  String get apiTestResponse;

  /// No description provided for @apiTestBody.
  ///
  /// In ja, this message translates to:
  /// **'ボディ'**
  String get apiTestBody;

  /// No description provided for @apiTestHeaders.
  ///
  /// In ja, this message translates to:
  /// **'ヘッダー'**
  String get apiTestHeaders;

  /// No description provided for @apiTestAddHeader.
  ///
  /// In ja, this message translates to:
  /// **'ヘッダーを追加'**
  String get apiTestAddHeader;

  /// No description provided for @apiTestInsertApiKey.
  ///
  /// In ja, this message translates to:
  /// **'APIキーを挿入'**
  String get apiTestInsertApiKey;

  /// No description provided for @apiTestNoApiKeys.
  ///
  /// In ja, this message translates to:
  /// **'APIキーが保存されていません'**
  String get apiTestNoApiKeys;

  /// No description provided for @hostkeyUnknownTitle.
  ///
  /// In ja, this message translates to:
  /// **'ホスト鍵の確認'**
  String get hostkeyUnknownTitle;

  /// No description provided for @hostkeyChangedTitle.
  ///
  /// In ja, this message translates to:
  /// **'ホスト鍵が変更されています'**
  String get hostkeyChangedTitle;

  /// No description provided for @hostkeyUnknownBody.
  ///
  /// In ja, this message translates to:
  /// **'{host} へは初めて接続します。表示されている指紋がサーバー管理者の提示した値と一致することを確認してください。'**
  String hostkeyUnknownBody(String host);

  /// No description provided for @hostkeyChangedBody.
  ///
  /// In ja, this message translates to:
  /// **'{host} のホスト鍵が前回接続時と異なります。中間者攻撃を受けているか、サーバーが再構築された可能性があります。心当たりがない場合は接続しないでください。'**
  String hostkeyChangedBody(String host);

  /// No description provided for @hostkeyTypeLabel.
  ///
  /// In ja, this message translates to:
  /// **'鍵種別'**
  String get hostkeyTypeLabel;

  /// No description provided for @hostkeyFingerprintLabel.
  ///
  /// In ja, this message translates to:
  /// **'提示された指紋'**
  String get hostkeyFingerprintLabel;

  /// No description provided for @hostkeyKnownFingerprintLabel.
  ///
  /// In ja, this message translates to:
  /// **'保存済みの指紋'**
  String get hostkeyKnownFingerprintLabel;

  /// No description provided for @hostkeyTrustButton.
  ///
  /// In ja, this message translates to:
  /// **'信頼して接続'**
  String get hostkeyTrustButton;

  /// No description provided for @hostkeyRejectButton.
  ///
  /// In ja, this message translates to:
  /// **'接続しない'**
  String get hostkeyRejectButton;

  /// No description provided for @additionalFeaturesSection.
  ///
  /// In ja, this message translates to:
  /// **'追加機能'**
  String get additionalFeaturesSection;

  /// No description provided for @featureSshTab.
  ///
  /// In ja, this message translates to:
  /// **'SSHサーバータブ'**
  String get featureSshTab;

  /// No description provided for @featureSshTabSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムSSHサーバーに接続'**
  String get featureSshTabSubtitle;

  /// No description provided for @featureApiKeys.
  ///
  /// In ja, this message translates to:
  /// **'APIキー & テスト'**
  String get featureApiKeys;

  /// No description provided for @featureApiKeysSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'APIキーの管理とRESTテスト'**
  String get featureApiKeysSubtitle;

  /// No description provided for @featureCicd.
  ///
  /// In ja, this message translates to:
  /// **'CI/CD'**
  String get featureCicd;

  /// No description provided for @featureCicdSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'GitHub Actionsのワークフローを表示'**
  String get featureCicdSubtitle;

  /// No description provided for @featurePlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get featurePlugins;

  /// No description provided for @featurePluginsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'コミュニティプラグインで機能を拡張'**
  String get featurePluginsSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
