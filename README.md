# Kirikiri

**Mobile Development Environment — Your terminal, everywhere.**

[![App Store](https://img.shields.io/badge/App_Store-Download-black?logo=apple)](https://apps.apple.com/jp/app/kirikiri/id6764003368)
[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-blue?logo=flutter)](https://flutter.dev)

---

## Vision

Software development should be possible from anywhere, on any device — including your phone.

AI coding assistants like Claude Code and Codex are making it possible to write, review, and ship code faster than ever. Kirikiri is built to be the **shell execution layer** for this mobile-first future: a terminal environment that puts the full power of a Linux machine in your pocket.

## What is Kirikiri?

Kirikiri is an open-source Flutter app that connects your smartphone to cloud development environments. It turns your phone into a genuine development terminal by bridging Google Cloud Shell, remote SSH servers, and GitHub — all from a mobile-optimized interface.

<p align="center">
  <img src="assets/icon/icon.png" width="80" alt="Kirikiri icon">
</p>

## Features

- **Google Cloud Shell** — One-tap connection to a full Linux environment in the cloud. No setup required.
- **SSH Client** — Connect to any server with password or private key authentication.
- **GitHub Integration** — Browse repositories and open them instantly in Cloud Shell.
- **Command Buttons** — Place frequently used commands as floating buttons on the terminal screen. Tap to send — no typing required.
- **Plugin System** — Install plugins from any GitHub repository to extend functionality.
- **Localization** — English and Japanese support, automatically based on device language.
- **Demo Mode** — Explore all features without signing in (`--dart-define=SCREENSHOT_MODE=true`).

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Xcode 16+ (for iOS builds)
- A Google Cloud account (for Cloud Shell features)

### Setup

```bash
git clone https://github.com/555734/Kirikiri-IDE.git
cd Kirikiri-IDE
flutter pub get
flutter gen-l10n
flutter run
```

### Google Sign-In (iOS)

1. Create an OAuth 2.0 Client ID for iOS in [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials
2. Replace the placeholder values in `ios/Runner/Info.plist`:

```xml
<key>GIDClientID</key>
<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
```

```xml
<string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
```

### Build

```bash
# Run in demo mode (no account needed)
flutter run --dart-define=SCREENSHOT_MODE=true

# Android release bundle
flutter build appbundle --release

# iOS release (requires Apple Developer account)
flutter build ipa --release
```

## Architecture

```
lib/
├── core/               # Storage, theming, SSH foreground service
├── features/
│   ├── cloudshell/     # Google Cloud Shell connection & API
│   ├── ssh/            # SSH connection management
│   ├── terminal/       # Terminal emulator (xterm) & demo mode
│   ├── github/         # GitHub API integration
│   ├── plugins/        # Plugin system (install from GitHub)
│   ├── onboarding/     # First-run flow
│   └── account/        # Settings & account management
└── l10n/               # ARB localization files (en, ja)
```

**Key dependencies:** `dartssh2` (pure-Dart SSH), `xterm` (terminal emulator), `google_sign_in`, `flutter_secure_storage`, `provider`

## Contributing

Contributions are welcome. Please open an issue before submitting a large pull request.

```bash
# Run tests
flutter test

# Check for issues
flutter analyze
```

## Support

- [App Store](https://apps.apple.com/jp/app/kirikiri/id6764003368)
- [Support Page](https://555734.github.io/kirikiri-web/support.html)
- [Bug Reports](https://github.com/555734/Kirikiri-IDE/issues)

## Roadmap

The long-term goal is simple: **make every aspect of software development possible from a phone.**

Right now, the maintainer is focused on making **web development workflows smoother** — faster Cloud Shell access, better terminal UX, and tighter GitHub integration.

But the most important thing is this: **use it, break it, make it your own.**

Fork it. Build your dream mobile dev tool on top of it. Add the features your workflow needs. That's the whole point.

## License

MIT — see [LICENSE](LICENSE) for details.
