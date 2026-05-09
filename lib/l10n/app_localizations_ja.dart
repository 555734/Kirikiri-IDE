// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'kirikiri';

  @override
  String get tabCloudShell => 'Cloud Shell';

  @override
  String get tabRepository => 'リポジトリ';

  @override
  String get tabSsh => 'SSH';

  @override
  String get tabAccount => 'アカウント';

  @override
  String get skip => 'スキップ';

  @override
  String get later => 'あとで';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get add => '追加';

  @override
  String get edit => '編集';

  @override
  String get close => '閉じる';

  @override
  String get retry => '再試行';

  @override
  String get connect => '接続';

  @override
  String get disconnect => '切断';

  @override
  String get logout => 'ログアウト';

  @override
  String get logoutConfirmTitle => 'ログアウト';

  @override
  String get logoutConfirmBody => 'Googleアカウントからログアウトしますか？';

  @override
  String get logoutTooltip => 'ログアウト';

  @override
  String get loginWithGoogle => 'Googleアカウントでログイン';

  @override
  String get loggingIn => 'ログイン中...';

  @override
  String get loginWithoutAccount => 'ログインせずに使う';

  @override
  String get googleAccountOnly => 'Googleアカウントのみ使用。\nトークンはデバイスに安全に保存されます。';

  @override
  String get onboardingWelcomeTitle => 'ようこそ\nkirikiri へ';

  @override
  String get onboardingWelcomeBody =>
      'スマートフォンで本格的なクラウド開発を。\nいつでもどこでも、開発環境が手の中に。';

  @override
  String get onboardingTerminalTitle => 'ターミナルを\n手のひらで';

  @override
  String get onboardingTerminalBody =>
      'Google Cloud Shell にワンタップ接続。\nLinuxコマンドの実行・デプロイまで\nスマホで完結します。';

  @override
  String get onboardingGithubTitle => 'GitHub と\nシームレス連携';

  @override
  String get onboardingGithubBody =>
      'リポジトリを一覧し、タップするだけで\nCloud Shell で即開きます。\nコードとターミナルを自在に行き来。';

  @override
  String get onboardingCommandsTitle => 'FPS感覚の\nコマンド操作';

  @override
  String get onboardingCommandsBody =>
      '頻出コマンドを丸ボタンに登録して\n画面に自由配置。タップで即入力、\nゲームのような快速操作感。';

  @override
  String get onboardingSignInTitle => 'Google で\nサインインする';

  @override
  String get onboardingSignInBody =>
      'Cloud Shell の利用にはGoogleアカウントが必要です。あとからでも設定できます。';

  @override
  String get letsGo => 'さあ、始めよう';

  @override
  String get cloudShellTitle => 'Google Cloud Shell';

  @override
  String get cloudShellSignInPrompt =>
      'Googleアカウントでサインインして\nCloud Shell を使用できます';

  @override
  String get cloudShellStarting => 'Cloud Shell を起動中...';

  @override
  String get cloudShellFirstLaunchNote => '初回は30秒ほどかかることがあります';

  @override
  String get startupStepPreparingKey => 'SSH 鍵を準備中';
  @override
  String get startupStepCheckingState => '環境の状態を確認中';
  @override
  String get startupStepStarting => '環境を起動中';
  @override
  String get startupStepWaitingRunning => '起動完了を待機中';
  @override
  String get startupStepRegisteringKey => 'SSH 鍵を登録中';
  @override
  String startupElapsed(int seconds) => '${seconds}秒経過';

  @override
  String get cloudShellRunning => 'Cloud Shell 起動中';

  @override
  String get cloudShellStopped => 'Cloud Shell は停止中です';

  @override
  String get cloudShellStartButton => '起動する';

  @override
  String get openTerminal => 'ターミナルを開く';

  @override
  String preparingRepo(String repo) {
    return '$repo を準備中...';
  }

  @override
  String get cloudShellError => 'エラーが発生しました';

  @override
  String get sshConnecting => 'SSH 接続中...';

  @override
  String get sshConnectingToServer => 'サーバーに接続しています';

  @override
  String get connectionError => '接続エラー';

  @override
  String get reconnect => '再接続する';

  @override
  String get showSshLog => 'SSHログを表示';

  @override
  String get sshLog => 'SSH 接続ログ';

  @override
  String get noLogs => 'ログなし';

  @override
  String get paste => 'ペースト';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'コピーしました';

  @override
  String get dragToSelect => 'テキストをドラッグして選択してください';

  @override
  String get commandButtonAdd => 'コマンドボタンを追加';

  @override
  String get commandButtonEdit => 'ボタンを編集';

  @override
  String get commandButtonLabel => 'ラベル（例: ls, git, clear）';

  @override
  String get commandButtonLabelShort => 'ラベル';

  @override
  String get commandButtonCommand => 'コマンド';

  @override
  String get buttonsDone => '完了';

  @override
  String get buttonsEdit => 'ボタン';

  @override
  String get portPickerTitle => 'ポートを選択';

  @override
  String get portPickerBody => 'プレビューするサーバーのポートを選んでください';

  @override
  String get portPickerCustom => 'カスタムポート';

  @override
  String get open => '開く';

  @override
  String get preview => 'プレビュー';

  @override
  String get run => '実行';

  @override
  String get repository => 'リポジトリ';

  @override
  String get reconnectButton => '再接続';

  @override
  String get fontSizeLabel => 'フォントサイズ';

  @override
  String get tuiUploading => 'ツールをアップロード中';

  @override
  String tuiLaunchError(String error) {
    return 'TUI起動エラー: $error';
  }

  @override
  String get commandInputHint => 'コマンドを入力...';

  @override
  String get favoriteAlreadyExists => 'すでに登録済みです';

  @override
  String get favoriteAdded => 'お気に入りに追加しました';

  @override
  String get undo => '元に戻す';

  @override
  String get deleteFavorite => 'お気に入りを削除';

  @override
  String get githubConnect => 'GitHub に接続';

  @override
  String get githubPatDescription =>
      'Personal Access Token (PAT) を入力してください。\nリポジトリの読み書きには repo スコープが必要です。';

  @override
  String get githubPatPlaceholder => 'ghp_xxxxxxxxxxxxxxxxxxxx';

  @override
  String get githubConnectButton => '接続する';

  @override
  String get githubGeneratePat => 'PAT を生成する (GitHub)';

  @override
  String get repoSearch => 'リポジトリを検索...';

  @override
  String get repoNotFound => 'リポジトリが見つかりません';

  @override
  String get openInShell => 'Shell で開く';

  @override
  String get noFiles => 'ファイルなし';

  @override
  String get relativeTimeToday => '今日';

  @override
  String get relativeTimeYesterday => '昨日';

  @override
  String relativeTimeDaysAgo(int days) {
    return '$days日前';
  }

  @override
  String relativeTimeMonthsAgo(int months) {
    return '$monthsヶ月前';
  }

  @override
  String relativeTimeYearsAgo(int years) {
    return '$years年前';
  }

  @override
  String get commitSave => '保存 (コミット)';

  @override
  String get commitMessageTitle => 'コミットメッセージ';

  @override
  String get commitMessageHint => 'コミットメッセージを入力';

  @override
  String get commit => 'コミット';

  @override
  String get binaryFileNotSupported => 'バイナリファイルは表示できません';

  @override
  String get fileSaved => '保存しました';

  @override
  String fileSaveError(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get sshServersTitle => 'SSH サーバー';

  @override
  String get sshServersEmpty => 'SSH サーバーが登録されていません';

  @override
  String get sshServersEmptyHint => 'ホスト・ポート・認証情報を保存して\nワンタップで接続できます';

  @override
  String get sshAddConnection => '接続を追加';

  @override
  String get sshDeleteConnection => '接続を削除';

  @override
  String get sshDeleteConfirm => '削除しますか？';

  @override
  String get sshConnectButton => '接続';

  @override
  String get sshEditButton => '編集';

  @override
  String get sshDeleteButton => '削除';

  @override
  String get sshFormEditTitle => '接続を編集';

  @override
  String get sshFormNewTitle => '新しい接続';

  @override
  String get sshFieldLabel => 'ラベル（表示名）';

  @override
  String get sshFieldHost => 'ホスト / IP';

  @override
  String get sshFieldPort => 'ポート';

  @override
  String get sshFieldPortInvalid => '数値';

  @override
  String get sshFieldUsername => 'ユーザー名';

  @override
  String get sshAuthMethod => '認証方式';

  @override
  String get sshAuthPassword => 'パスワード';

  @override
  String get sshAuthPrivateKey => '秘密鍵';

  @override
  String get sshPrivateKeyLabel => '秘密鍵 (PEM形式)';

  @override
  String get sshPrivateKeyHint =>
      '-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----';

  @override
  String get sshPrivateKeyRequired => '秘密鍵を入力してください';

  @override
  String get fieldRequired => '必須項目です';

  @override
  String get pluginsTitle => 'プラグイン';

  @override
  String get pluginStoreTitle => 'プラグインストア';

  @override
  String get pluginAddTitle => 'プラグインを追加';

  @override
  String get pluginAddDescription =>
      'GitHubリポジトリのURLを入力してインストールします。\nリポジトリのルートに plugin.json が必要です。';

  @override
  String get pluginUrlHint => 'https://github.com/owner/repo';

  @override
  String get pluginInstall => 'インストール';

  @override
  String pluginInstallProgress(int progress) {
    return '$progress% 完了';
  }

  @override
  String get pluginInstalledEmpty => 'プラグインがインストールされていません';

  @override
  String pluginInstalledCount(int count) {
    return 'インストール済み ($count)';
  }

  @override
  String get pluginToolbarButtons => 'ツールバーボタン';

  @override
  String get pluginCommandChips => 'コマンドチップ';

  @override
  String get pluginMenuItems => 'メニュー項目';

  @override
  String get pluginPermissions => 'パーミッション';

  @override
  String get pluginUninstall => 'プラグインを削除';

  @override
  String get pluginUninstallConfirm => 'アンインストールしますか？';

  @override
  String get pluginStoreSort => '並び替え';

  @override
  String get pluginStoreSortStars => 'スター数順';

  @override
  String get pluginStoreSortUpdated => '更新日順';

  @override
  String get pluginStoreSearch => 'プラグインを検索...';

  @override
  String get pluginStoreDisclaimer => 'コミュニティ製プラグインです。内容を確認してからインストールしてください。';

  @override
  String get pluginStoreEmpty => 'プラグインが見つかりません';

  @override
  String get pluginStoreTopicHint =>
      'GitHubリポジトリに topic: kirikiri-plugin を設定するとここに表示されます';

  @override
  String get pluginAlreadyInstalled => '✓ インストール済み';

  @override
  String get pluginInstalled => 'インストールしました';

  @override
  String pluginInstallError(String error) {
    return 'エラー: $error';
  }

  @override
  String get pluginLabel => 'プラグイン';

  @override
  String relativeTimeWeeksAgo(int weeks) {
    return '$weeks週間前';
  }

  @override
  String get authSubtitle => 'Google Cloud Shell をスマホから';

  @override
  String get authPrivacyNote => 'Googleアカウントのみ使用。\nトークンはデバイスに安全に保存されます。';

  @override
  String get appearanceSection => '外観';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get darkModeSubtitle => 'アプリ全体を暗い配色に変更します';

  @override
  String get githubSection => 'GitHub';

  @override
  String get githubLoggedIn => 'ログイン中';

  @override
  String get githubNotConnected => 'GitHubに未接続';

  @override
  String get githubNotConnectedHint => 'リポジトリタブからPATを設定できます';

  @override
  String get githubUpdatePat => 'Personal Access Token を更新';

  @override
  String get apiKeysSection => 'APIキー';

  @override
  String get apiKeysEmpty => 'APIキーはまだ登録されていません';

  @override
  String get apiKeyAdd => 'APIキーを追加';

  @override
  String get apiKeyEdit => 'APIキーを編集';

  @override
  String get apiKeyLabelHint => 'ラベル (例: OpenAI)';

  @override
  String get apiKeyFieldLabel => 'APIキー';

  @override
  String get commandSnippetsSection => 'コマンドスニペット';

  @override
  String get commandSnippetsHint => 'よく使うコマンドを登録しておけます';

  @override
  String get commandSnippetAdd => 'コマンドを追加';

  @override
  String get commandSnippetEdit => 'コマンドを編集';

  @override
  String get commandSnippetLabelHint => 'ラベル (例: git status)';

  @override
  String get commandSnippetCommandLabel => 'コマンド';

  @override
  String get aboutSection => 'このアプリについて';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get version => 'バージョン';

  @override
  String get tunnelActive => 'アクティブ';

  @override
  String get tunnelStop => '停止';

  @override
  String get portDetect => '検出';

  @override
  String get portDetecting => 'スキャン中...';

  @override
  String get portDetectedNone => 'ポートが見つかりません';

  @override
  String get savedPorts => '保存済みポート';

  @override
  String get addPort => 'ポートを追加';

  @override
  String get portLabel => 'ラベル';

  @override
  String get portNumber => 'ポート番号';

  @override
  String get launcherTitle => 'ランチャー';

  @override
  String get launcherAddCategory => 'カテゴリを追加';

  @override
  String get launcherAddCommand => 'コマンドを追加';

  @override
  String get launcherCategoryLabel => 'カテゴリ名';

  @override
  String get launcherIcon => 'アイコン（絵文字）';

  @override
  String get launcherCommandLabel => 'ラベル';

  @override
  String get launcherCommandHint => 'コマンド';

  @override
  String get launcherEmptyCategories => 'カテゴリがありません。＋をタップして追加してください。';

  @override
  String get launcherEmptyCommands => 'コマンドがありません。';

  @override
  String get launcherRun => '実行';

  @override
  String get launcherDeleteCategory => 'カテゴリを削除';

  @override
  String get cicdTitle => 'CI/CD';

  @override
  String get cicdNoRuns => 'ワークフローの実行履歴がありません';

  @override
  String get cicdNoJobs => 'ジョブが見つかりません';

  @override
  String get cicdRunning => '実行中';

  @override
  String get branchesTitle => 'ブランチ';

  @override
  String get pullRequestsTitle => 'プルリクエスト';

  @override
  String get branchNew => '新しいブランチ';

  @override
  String get branchName => 'ブランチ名';

  @override
  String get branchFrom => '元のブランチ';

  @override
  String get branchDelete => 'ブランチを削除';

  @override
  String get branchDeleteConfirm => 'このブランチを削除しますか？';

  @override
  String get branchProtected => '保護済み';

  @override
  String get branchesEmpty => 'ブランチがありません';

  @override
  String get prNew => '新しいプルリクエスト';

  @override
  String get prTitleLabel => 'タイトル';

  @override
  String get prBodyLabel => '説明（任意）';

  @override
  String get prCreate => '作成';

  @override
  String get prHead => 'ヘッドブランチ';

  @override
  String get prBase => 'ベースブランチ';

  @override
  String get prStateOpen => 'オープン';

  @override
  String get prStateClosed => 'クローズ';

  @override
  String get prEmpty => 'プルリクエストがありません';

  @override
  String get apiTestTitle => 'APIテスト';

  @override
  String get apiTestSend => '送信';

  @override
  String get apiTestResponse => 'レスポンス';

  @override
  String get apiTestBody => 'ボディ';

  @override
  String get apiTestHeaders => 'ヘッダー';

  @override
  String get apiTestAddHeader => 'ヘッダーを追加';

  @override
  String get apiTestInsertApiKey => 'APIキーを挿入';

  @override
  String get apiTestNoApiKeys => 'APIキーが保存されていません';

  @override
  String get additionalFeaturesSection => '追加機能';

  @override
  String get featureSshTab => 'SSHサーバータブ';

  @override
  String get featureSshTabSubtitle => 'カスタムSSHサーバーに接続';

  @override
  String get featureApiKeys => 'APIキー & テスト';

  @override
  String get featureApiKeysSubtitle => 'キー管理とREST APIテスト';

  @override
  String get featureCicd => 'CI/CD';

  @override
  String get featureCicdSubtitle => 'GitHub Actionsのワークフロー表示';

  @override
  String get featurePlugins => 'プラグイン';

  @override
  String get featurePluginsSubtitle => 'コミュニティプラグインで機能を拡張';
}
