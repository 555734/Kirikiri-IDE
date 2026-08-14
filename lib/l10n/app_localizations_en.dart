// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'kirikiri';

  @override
  String get tabCloudShell => 'Cloud Shell';

  @override
  String get tabRepository => 'Repositories';

  @override
  String get tabSsh => 'SSH';

  @override
  String get tabAccount => 'Account';

  @override
  String get skip => 'Skip';

  @override
  String get later => 'Later';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get logout => 'Sign Out';

  @override
  String get logoutConfirmTitle => 'Sign Out';

  @override
  String get logoutConfirmBody => 'Sign out of your Google account?';

  @override
  String get logoutTooltip => 'Sign Out';

  @override
  String get loginWithGoogle => 'Sign in with Google';

  @override
  String get loggingIn => 'Signing in...';

  @override
  String get loginWithoutAccount => 'Continue without sign-in';

  @override
  String get googleAccountOnly =>
      'Google account only.\nTokens are stored securely on your device.';

  @override
  String get tryDemo => 'Try Demo (no account needed)';

  @override
  String get onboardingWelcomeTitle => 'Welcome to\nkirikiri';

  @override
  String get onboardingWelcomeBody =>
      'Professional cloud development on your phone.\nYour dev environment, anytime, anywhere.';

  @override
  String get onboardingTerminalTitle => 'Terminal in\nyour hands';

  @override
  String get onboardingTerminalBody =>
      'One-tap connection to Google Cloud Shell.\nRun Linux commands and deploy,\nall from your phone.';

  @override
  String get onboardingGithubTitle => 'Seamless\nGitHub Integration';

  @override
  String get onboardingGithubBody =>
      'Browse repos and open them in Cloud Shell\nwith a single tap.\nSwitch between code and terminal freely.';

  @override
  String get onboardingCommandsTitle => 'FPS-style\nCommand Controls';

  @override
  String get onboardingCommandsBody =>
      'Register frequent commands as round buttons\nand place them freely on screen.\nTap for instant input, like a game controller.';

  @override
  String get onboardingSignInTitle => 'Sign in with\nGoogle';

  @override
  String get onboardingSignInBody =>
      'A Google account is required for Cloud Shell.\nYou can set this up later.';

  @override
  String get letsGo => 'Let\'s Go';

  @override
  String get cloudShellTitle => 'Google Cloud Shell';

  @override
  String get cloudShellSignInPrompt =>
      'Sign in with your Google account\nto use Cloud Shell';

  @override
  String get cloudShellStarting => 'Starting Cloud Shell...';

  @override
  String get cloudShellFirstLaunchNote => 'First launch may take ~30 seconds';

  @override
  String get startupStepPreparingKey => 'Preparing SSH key';

  @override
  String get startupStepCheckingState => 'Checking environment';

  @override
  String get startupStepStarting => 'Starting environment';

  @override
  String get startupStepWaitingRunning => 'Waiting for startup';

  @override
  String get startupStepRegisteringKey => 'Registering SSH key';

  @override
  String startupElapsed(int seconds) {
    return '${seconds}s elapsed';
  }

  @override
  String get cloudShellRunning => 'Cloud Shell Ready';

  @override
  String get cloudShellStopped => 'Cloud Shell is stopped';

  @override
  String get cloudShellStartButton => 'Start';

  @override
  String get openTerminal => 'Open Terminal';

  @override
  String preparingRepo(String repo) {
    return 'Preparing $repo...';
  }

  @override
  String get cloudShellError => 'An error occurred';

  @override
  String get sshConnecting => 'Connecting via SSH...';

  @override
  String get sshConnectingToServer => 'Connecting to server';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get showSshLog => 'Show SSH Log';

  @override
  String get sshLog => 'SSH Connection Log';

  @override
  String get noLogs => 'No logs';

  @override
  String get paste => 'Paste';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get dragToSelect => 'Drag to select text';

  @override
  String get commandButtonAdd => 'Add Command Button';

  @override
  String get commandButtonEdit => 'Edit Button';

  @override
  String get commandButtonLabel => 'Label (e.g. ls, git, clear)';

  @override
  String get commandButtonLabelShort => 'Label';

  @override
  String get commandButtonCommand => 'Command';

  @override
  String get buttonsDone => 'Done';

  @override
  String get buttonsEdit => 'Buttons';

  @override
  String get portPickerTitle => 'Select Port';

  @override
  String get portPickerBody => 'Choose the port of the server to preview';

  @override
  String get portPickerCustom => 'Custom port';

  @override
  String get open => 'Open';

  @override
  String get preview => 'Preview';

  @override
  String get run => 'Run';

  @override
  String get repository => 'Repository';

  @override
  String get reconnectButton => 'Reconnect';

  @override
  String get fontSizeLabel => 'Font Size';

  @override
  String get tuiUploading => 'Uploading tools';

  @override
  String tuiLaunchError(String error) {
    return 'TUI launch error: $error';
  }

  @override
  String get commandInputHint => 'Enter command...';

  @override
  String get favoriteAlreadyExists => 'Already saved';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get undo => 'Undo';

  @override
  String get deleteFavorite => 'Remove favorite';

  @override
  String get githubConnect => 'Connect to GitHub';

  @override
  String get githubPatDescription =>
      'Enter your Personal Access Token (PAT).\nThe repo scope is required for read/write access.';

  @override
  String get githubPatPlaceholder => 'ghp_xxxxxxxxxxxxxxxxxxxx';

  @override
  String get githubConnectButton => 'Connect';

  @override
  String get githubGeneratePat => 'Generate PAT (GitHub)';

  @override
  String get repoSearch => 'Search repositories...';

  @override
  String get repoNotFound => 'No repositories found';

  @override
  String get openInShell => 'Open in Shell';

  @override
  String get noFiles => 'No files';

  @override
  String get relativeTimeToday => 'Today';

  @override
  String get relativeTimeYesterday => 'Yesterday';

  @override
  String relativeTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String relativeTimeMonthsAgo(int months) {
    return '${months}mo ago';
  }

  @override
  String relativeTimeYearsAgo(int years) {
    return '${years}y ago';
  }

  @override
  String get commitSave => 'Save (Commit)';

  @override
  String get commitMessageTitle => 'Commit Message';

  @override
  String get commitMessageHint => 'Enter commit message';

  @override
  String get commit => 'Commit';

  @override
  String get binaryFileNotSupported => 'Binary files cannot be displayed';

  @override
  String get fileSaved => 'Saved';

  @override
  String fileSaveError(String error) {
    return 'Save failed: $error';
  }

  @override
  String get sshServersTitle => 'SSH Servers';

  @override
  String get sshServersEmpty => 'No SSH servers registered';

  @override
  String get sshServersEmptyHint =>
      'Save host, port and credentials\nto connect with one tap';

  @override
  String get sshAddConnection => 'Add Connection';

  @override
  String get sshDeleteConnection => 'Delete Connection';

  @override
  String get sshDeleteConfirm => 'Delete this connection?';

  @override
  String get sshConnectButton => 'Connect';

  @override
  String get sshEditButton => 'Edit';

  @override
  String get sshDeleteButton => 'Delete';

  @override
  String get sshFormEditTitle => 'Edit Connection';

  @override
  String get sshFormNewTitle => 'New Connection';

  @override
  String get sshFieldLabel => 'Label (display name)';

  @override
  String get sshFieldHost => 'Host / IP';

  @override
  String get sshFieldPort => 'Port';

  @override
  String get sshFieldPortInvalid => 'Number';

  @override
  String get sshFieldUsername => 'Username';

  @override
  String get sshAuthMethod => 'Auth Method';

  @override
  String get sshAuthPassword => 'Password';

  @override
  String get sshAuthPrivateKey => 'Private Key';

  @override
  String get sshPrivateKeyLabel => 'Private Key (PEM)';

  @override
  String get sshPrivateKeyHint =>
      '-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----';

  @override
  String get sshPrivateKeyRequired => 'Please enter private key';

  @override
  String get fieldRequired => 'Required';

  @override
  String get pluginsTitle => 'Plugins';

  @override
  String get pluginStoreTitle => 'Plugin Store';

  @override
  String get pluginAddTitle => 'Add Plugin';

  @override
  String get pluginAddDescription =>
      'Enter a GitHub repository URL to install.\nThe repository root must contain plugin.json.';

  @override
  String get pluginUrlHint => 'https://github.com/owner/repo';

  @override
  String get pluginInstall => 'Install';

  @override
  String pluginInstallProgress(int progress) {
    return '$progress% complete';
  }

  @override
  String get pluginInstalledEmpty => 'No plugins installed';

  @override
  String pluginInstalledCount(int count) {
    return 'Installed ($count)';
  }

  @override
  String get pluginToolbarButtons => 'Toolbar Buttons';

  @override
  String get pluginCommandChips => 'Command Chips';

  @override
  String get pluginMenuItems => 'Menu Items';

  @override
  String get pluginPermissions => 'Permissions';

  @override
  String get pluginUninstall => 'Remove Plugin';

  @override
  String get pluginUninstallConfirm => 'Uninstall this plugin?';

  @override
  String get pluginStoreSort => 'Sort';

  @override
  String get pluginStoreSortStars => 'By Stars';

  @override
  String get pluginStoreSortUpdated => 'By Updated';

  @override
  String get pluginStoreSearch => 'Search plugins...';

  @override
  String get pluginStoreDisclaimer =>
      'Community plugins — review before installing.';

  @override
  String get pluginStoreEmpty => 'No plugins found';

  @override
  String get pluginStoreTopicHint =>
      'Set topic: kirikiri-plugin on a GitHub repository to list it here';

  @override
  String get pluginAlreadyInstalled => '✓ Installed';

  @override
  String get pluginInstalled => 'Plugin installed';

  @override
  String pluginInstallError(String error) {
    return 'Error: $error';
  }

  @override
  String get pluginLabel => 'Plugins';

  @override
  String relativeTimeWeeksAgo(int weeks) {
    return '${weeks}w ago';
  }

  @override
  String get authSubtitle => 'Google Cloud Shell on your phone';

  @override
  String get authPrivacyNote =>
      'Google account only.\nYour token is stored securely on your device.';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Switch the entire app to dark colors';

  @override
  String get githubSection => 'GitHub';

  @override
  String get githubLoggedIn => 'Signed in';

  @override
  String get githubNotConnected => 'Not connected to GitHub';

  @override
  String get githubNotConnectedHint => 'Set your PAT from the Repositories tab';

  @override
  String get githubUpdatePat => 'Update Personal Access Token';

  @override
  String get apiKeysSection => 'API Keys';

  @override
  String get apiKeysEmpty => 'No API keys registered yet';

  @override
  String get apiKeyAdd => 'Add API Key';

  @override
  String get apiKeyEdit => 'Edit API Key';

  @override
  String get apiKeyLabelHint => 'Label (e.g. OpenAI)';

  @override
  String get apiKeyFieldLabel => 'API Key';

  @override
  String get commandSnippetsSection => 'Command Snippets';

  @override
  String get commandSnippetsHint => 'Save frequently used commands here';

  @override
  String get commandSnippetAdd => 'Add Command';

  @override
  String get commandSnippetEdit => 'Edit Command';

  @override
  String get commandSnippetLabelHint => 'Label (e.g. git status)';

  @override
  String get commandSnippetCommandLabel => 'Command';

  @override
  String get aboutSection => 'About';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get version => 'Version';

  @override
  String get tunnelActive => 'Active';

  @override
  String get tunnelStop => 'Stop';

  @override
  String get portDetect => 'Detect';

  @override
  String get portDetecting => 'Scanning...';

  @override
  String get portDetectedNone => 'No ports found';

  @override
  String get savedPorts => 'Saved Ports';

  @override
  String get addPort => 'Add Port';

  @override
  String get portLabel => 'Label';

  @override
  String get portNumber => 'Port';

  @override
  String get launcherTitle => 'Launcher';

  @override
  String get launcherAddCategory => 'Add Category';

  @override
  String get launcherAddCommand => 'Add Command';

  @override
  String get launcherCategoryLabel => 'Category Name';

  @override
  String get launcherIcon => 'Icon (emoji)';

  @override
  String get launcherCommandLabel => 'Label';

  @override
  String get launcherCommandHint => 'Command';

  @override
  String get launcherEmptyCategories => 'No categories yet. Tap + to add one.';

  @override
  String get launcherEmptyCommands => 'No commands yet.';

  @override
  String get launcherRun => 'Run';

  @override
  String get launcherDeleteCategory => 'Delete Category';

  @override
  String get cicdTitle => 'CI/CD';

  @override
  String get cicdNoRuns => 'No workflow runs found';

  @override
  String get cicdNoJobs => 'No jobs found';

  @override
  String get cicdRunning => 'running';

  @override
  String get branchesTitle => 'Branches';

  @override
  String get pullRequestsTitle => 'Pull Requests';

  @override
  String get branchNew => 'New Branch';

  @override
  String get branchName => 'Branch Name';

  @override
  String get branchFrom => 'From';

  @override
  String get branchDelete => 'Delete Branch';

  @override
  String get branchDeleteConfirm => 'Delete this branch?';

  @override
  String get branchProtected => 'Protected';

  @override
  String get branchesEmpty => 'No branches';

  @override
  String get prNew => 'New Pull Request';

  @override
  String get prTitleLabel => 'Title';

  @override
  String get prBodyLabel => 'Description (optional)';

  @override
  String get prCreate => 'Create';

  @override
  String get prHead => 'Head Branch';

  @override
  String get prBase => 'Base Branch';

  @override
  String get prStateOpen => 'Open';

  @override
  String get prStateClosed => 'Closed';

  @override
  String get prEmpty => 'No pull requests';

  @override
  String get apiTestTitle => 'API Test';

  @override
  String get apiTestSend => 'Send';

  @override
  String get apiTestResponse => 'Response';

  @override
  String get apiTestBody => 'Body';

  @override
  String get apiTestHeaders => 'Headers';

  @override
  String get apiTestAddHeader => 'Add Header';

  @override
  String get apiTestInsertApiKey => 'Insert API Key';

  @override
  String get apiTestNoApiKeys => 'No API keys saved';

  @override
  String get githubErrorInvalidToken =>
      'That token is not valid. Enter a PAT with the repo scope.';

  @override
  String get pluginErrorDownloadFailed => 'Could not download the plugin.';

  @override
  String get pluginErrorManifestMissing =>
      'plugin.json was not found in the archive.';

  @override
  String get pluginErrorUnsafePath =>
      'Install aborted: the plugin contains an unsafe path.';

  @override
  String get pluginErrorInvalidRepoUrl => 'Enter a GitHub repository URL.';

  @override
  String get pluginErrorUnknown => 'Could not install the plugin.';

  @override
  String get cloudShellErrorNotSignedIn =>
      'Not signed in. Please sign in with Google again.';

  @override
  String get cloudShellErrorAuthExpired =>
      'Your session has expired. Please sign in with Google again.';

  @override
  String get cloudShellErrorStartTimeout =>
      'Cloud Shell did not start in time (about 80 seconds).';

  @override
  String get cloudShellErrorUnknown => 'Could not start Cloud Shell.';

  @override
  String get authErrorCancelled => 'Sign-in was cancelled';

  @override
  String get authErrorTokenUnavailable => 'Could not obtain an access token';

  @override
  String get authErrorSignInFailed => 'Google sign-in failed';

  @override
  String get webPreviewTitle => 'Web Preview';

  @override
  String get webPreviewBack => 'Back';

  @override
  String get webPreviewForward => 'Forward';

  @override
  String get webPreviewReload => 'Reload';

  @override
  String get webPreviewOpenInBrowser => 'Open in browser';

  @override
  String get webPreviewUrlCopied => 'URL copied';

  @override
  String get connectionStateConnected => 'Connected';

  @override
  String get connectionStateConnecting => 'Connecting';

  @override
  String get connectionStateError => 'Error';

  @override
  String get connectionStateDisconnected => 'Disconnected';

  @override
  String get hideUi => 'Hide';

  @override
  String get launcherDeleteCategoryConfirm => 'will be deleted. Continue?';

  @override
  String get sshAuthPrivateKeyLabel => 'Key authentication';

  @override
  String get sshAuthPasswordLabel => 'Password authentication';

  @override
  String get commandSend => 'Send (Enter)';

  @override
  String get sshReconnecting => 'Reconnecting...';

  @override
  String get sshErrorHostkeyUnconfirmed =>
      'Aborted: the server\'s host key could not be verified.';

  @override
  String get sshErrorHostkeyChanged =>
      'Aborted: the server\'s host key has changed, which may indicate a man-in-the-middle attack.';

  @override
  String get sshErrorHostkeyRejected =>
      'Aborted: the host key was not approved.';

  @override
  String get sshErrorHostkeyInvalid => 'Host key verification failed.';

  @override
  String get sshErrorAuthFailed => 'SSH authentication failed.';

  @override
  String get sshErrorAuthRejected => 'SSH authentication was rejected.';

  @override
  String get sshErrorConnectionFailed => 'Could not connect.';

  @override
  String get hostkeyUnknownTitle => 'Verify host key';

  @override
  String get hostkeyChangedTitle => 'Host key has changed';

  @override
  String hostkeyUnknownBody(String host) {
    return 'This is the first connection to $host. Confirm that the fingerprint below matches the one published by the server administrator.';
  }

  @override
  String hostkeyChangedBody(String host) {
    return 'The host key for $host differs from the one saved earlier. This may mean a man-in-the-middle attack, or that the server was rebuilt. Do not connect unless you expected this change.';
  }

  @override
  String get hostkeyTypeLabel => 'Key type';

  @override
  String get hostkeyFingerprintLabel => 'Offered fingerprint';

  @override
  String get hostkeyKnownFingerprintLabel => 'Saved fingerprint';

  @override
  String get hostkeyTrustButton => 'Trust and connect';

  @override
  String get hostkeyRejectButton => 'Don\'t connect';

  @override
  String get additionalFeaturesSection => 'Additional Features';

  @override
  String get featureSshTab => 'SSH Servers Tab';

  @override
  String get featureSshTabSubtitle => 'Connect to custom SSH servers';

  @override
  String get featureApiKeys => 'API Keys & Test';

  @override
  String get featureApiKeysSubtitle => 'Manage keys and test REST APIs';

  @override
  String get featureCicd => 'CI/CD';

  @override
  String get featureCicdSubtitle => 'View GitHub Actions workflows';

  @override
  String get featurePlugins => 'Plugins';

  @override
  String get featurePluginsSubtitle => 'Extend with community plugins';
}
