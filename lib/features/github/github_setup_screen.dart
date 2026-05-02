import 'package:flutter/material.dart';
import 'package:kirikiri/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../preview/web_preview_screen.dart';
import 'github_service.dart';

class GitHubSetupScreen extends StatefulWidget {
  const GitHubSetupScreen({super.key});

  @override
  State<GitHubSetupScreen> createState() => _GitHubSetupScreenState();
}

class _GitHubSetupScreenState extends State<GitHubSetupScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Consumer<GitHubService>(
      builder: (context, github, _) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hub_rounded,
                  color: AppColors.primary, size: 44),
              const SizedBox(height: 20),
              Text(l.githubConnect,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                l.githubPatDescription,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  labelText: l.githubPatPlaceholder,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (github.error != null) ...[
                const SizedBox(height: 12),
                Text(github.error!,
                    style: const TextStyle(
                        color: AppColors.errorLight, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: github.isLoading
                      ? null
                      : () => context
                          .read<GitHubService>()
                          .signIn(_controller.text),
                  child: github.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary))
                      : Text(l.githubConnectButton),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WebPreviewScreen(
                        url: 'https://github.com/settings/tokens/new?scopes=repo,read:user&description=kirikiri',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(l.githubGeneratePat,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
