import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/gamatube_logo.dart';

class SetupWizardDialog extends StatefulWidget {
  const SetupWizardDialog({super.key});

  @override
  State<SetupWizardDialog> createState() => _SetupWizardDialogState();
}

class _SetupWizardDialogState extends State<SetupWizardDialog> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const GamatubeLogo(size: 24),
                  Text(
                    'Step ${_currentStep + 1} of 4',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_currentStep + 1) / 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
              const SizedBox(height: 24),

              // Step content
              Expanded(
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep1Welcome(theme),
                    _buildStep2Theme(settings, theme),
                    _buildStep3Account(auth, theme),
                    _buildStep4Finish(theme),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: () {
                      if (_currentStep < 3) {
                        setState(() => _currentStep++);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(_currentStep < 3 ? 'Continue' : 'Get Started'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Welcome(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.movie_filter_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          'Welcome to GAMATUBE',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Your personal, lightweight, privacy-first video client. No tracking, no injected advertising, purely your clean media space.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(180),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStep2Theme(SettingsProvider settings, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Appearance',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick how GAMATUBE should look. You can change this anytime.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...[
          AppThemeMode.system,
          AppThemeMode.dark,
          AppThemeMode.amoled,
          AppThemeMode.light,
        ].map((mode) {
          String title = 'System Default';
          if (mode == AppThemeMode.dark) title = 'Dark (Deep Slate)';
          if (mode == AppThemeMode.amoled) title = 'AMOLED (Pure Black)';
          if (mode == AppThemeMode.light) title = 'Light (Clean Paper)';

          final isSelected = settings.settings.themeMode == mode;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : null,
            ),
            title: Text(title, style: const TextStyle(fontSize: 14)),
            onTap: () => settings.setThemeMode(mode),
          );
        }),
      ],
    );
  }

  Widget _buildStep3Account(AuthProvider auth, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 48, color: AppColors.secondary),
        const SizedBox(height: 12),
        Text(
          'Google Account (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'GAMATUBE works completely offline and locally without an account. Sign in if you want to sync subscriptions.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 24),
        if (auth.isAuthenticated)
          Chip(
            avatar: const Icon(Icons.check_circle_rounded, color: AppColors.success),
            label: Text('Signed in as ${auth.user?.name}'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => auth.signIn(),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Continue with Google'),
          ),
      ],
    );
  }

  Widget _buildStep4Finish(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        Text(
          'You\'re All Set!',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enjoy high-definition, distraction-free video playback across all your devices.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
