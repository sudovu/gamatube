import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/device/device_profiler.dart';
import '../models/app_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // 1. Account Section
          _buildSectionHeader(context, 'Account'),
          if (auth.isAuthenticated)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  auth.user?.name.isNotEmpty == true ? auth.user!.name[0] : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(auth.user?.name ?? 'User'),
              subtitle: Text(auth.user?.email ?? 'Signed in with Google'),
              trailing: OutlinedButton(
                onPressed: () => auth.signOut(),
                child: const Text('Sign out'),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, size: 28),
              title: const Text('Google Account'),
              subtitle: const Text('Sync subscriptions and cloud playlists'),
              trailing: FilledButton(
                onPressed: () => auth.signIn(),
                child: const Text('Sign In'),
              ),
            ),

          const Divider(),

          // 2. Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            title: const Text('Theme Mode'),
            subtitle: Text(_getThemeName(settings.settings.themeMode)),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.settings.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: AppThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: AppThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark (Slate)')),
                DropdownMenuItem(value: AppThemeMode.amoled, child: Text('AMOLED Black')),
              ],
              onChanged: (mode) {
                if (mode != null) settings.setThemeMode(mode);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('High Contrast'),
            subtitle: const Text('Enhance legibility with maximum contrast colors'),
            value: settings.settings.highContrast,
            onChanged: (val) => settings.setHighContrast(val),
          ),
          SwitchListTile(
            title: const Text('Reduce Motion'),
            subtitle: const Text('Minimize UI animations for accessibility'),
            value: settings.settings.reduceMotion,
            onChanged: (val) => settings.setReduceMotion(val),
          ),

          const Divider(),

          // 3. Playback Section
          _buildSectionHeader(context, 'Playback'),
          SwitchListTile(
            title: const Text('Autoplay Next'),
            subtitle: const Text('Automatically play recommended video upon completion'),
            value: settings.settings.autoplay,
            onChanged: (val) => settings.setAutoplay(val),
          ),
          ListTile(
            title: const Text('Default Speed'),
            subtitle: Text('${settings.settings.playbackSpeed}x'),
            trailing: DropdownButton<double>(
              value: settings.settings.playbackSpeed,
              underline: const SizedBox.shrink(),
              items: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                  .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                  .toList(),
              onChanged: (s) {
                if (s != null) settings.setPlaybackSpeed(s);
              },
            ),
          ),
          ListTile(
            title: const Text('Bandwidth Mode'),
            subtitle: Text(_getBandwidthName(settings.settings.bandwidthMode)),
            trailing: DropdownButton<BandwidthMode>(
              value: settings.settings.bandwidthMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: BandwidthMode.dataSaver, child: Text('Data Saver')),
                DropdownMenuItem(value: BandwidthMode.normal, child: Text('Normal')),
                DropdownMenuItem(value: BandwidthMode.highQuality, child: Text('High Quality')),
              ],
              onChanged: (b) {
                if (b != null) settings.setBandwidthMode(b);
              },
            ),
          ),

          const Divider(),

          // 4. Data & Caching Section
          _buildSectionHeader(context, 'Data & Caching'),
          ListTile(
            title: const Text('Max Cache Size'),
            subtitle: Text('${settings.settings.maxCacheSizeMb} MB'),
            trailing: DropdownButton<int>(
              value: settings.settings.maxCacheSizeMb,
              underline: const SizedBox.shrink(),
              items: AppConstants.cacheSizeOptionsMb
                  .map((mb) => DropdownMenuItem(value: mb, child: Text('$mb MB')))
                  .toList(),
              onChanged: (mb) {
                if (mb != null) settings.setMaxCacheSizeMb(mb);
              },
            ),
          ),
          ListTile(
            title: const Text('Clear Cache'),
            subtitle: const Text('Remove cached thumbnails, metadata, and responses'),
            trailing: OutlinedButton(
              onPressed: () {
                settings.clearCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared successfully.')),
                );
              },
              child: const Text('Clear'),
            ),
          ),
          SwitchListTile(
            title: const Text('Pause Watch History'),
            subtitle: const Text('Stop recording new playback sessions to history'),
            value: settings.settings.historyPaused,
            onChanged: (val) => settings.setHistoryPaused(val),
          ),

          const Divider(),

          // 5. Privacy Section
          _buildSectionHeader(context, 'Privacy & Diagnostics'),
          SwitchListTile(
            title: const Text('Opt-In Anonymous Analytics'),
            subtitle: const Text('Disabled by default. Help improve GAMATUBE performance.'),
            value: settings.settings.analyticsOptIn,
            onChanged: (val) => settings.setAnalyticsOptIn(val),
          ),
          SwitchListTile(
            title: const Text('Opt-In Crash Reporting'),
            subtitle: const Text('Disabled by default. Send anonymized stack traces on crash.'),
            value: settings.settings.crashReportingOptIn,
            onChanged: (val) => settings.setCrashReportingOptIn(val),
          ),
          ListTile(
            title: const Text('Clear All Local Data', style: TextStyle(color: AppColors.error)),
            subtitle: const Text('Delete history, playlists, settings, and cache permanently'),
            trailing: FilledButton.tonal(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error.withAlpha(30)),
              onPressed: () => _showClearAllDataDialog(context, settings),
              child: const Text('Reset', style: TextStyle(color: AppColors.error)),
            ),
          ),

          const Divider(),

          // 6. API Configuration Section
          _buildSectionHeader(context, 'API Configuration (Optional)'),
          ListTile(
            title: const Text('Custom YouTube API Key'),
            subtitle: Text(settings.settings.customApiKey?.isNotEmpty == true
                ? 'Active (Custom Key configured)'
                : 'Using default client integration'),
            trailing: IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => _showApiKeyDialog(context, settings),
            ),
          ),

          const Divider(),

          // 7. About Section
          _buildSectionHeader(context, 'About GAMATUBE'),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('${AppConstants.appVersion}+${AppConstants.buildNumber} • Multi-Platform'),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl)),
          ),
          ListTile(
            title: const Text('Open Source Repository'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => launchUrl(Uri.parse(AppConstants.sourceRepoUrl)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Follows System';
      case AppThemeMode.light:
        return 'Light Theme';
      case AppThemeMode.dark:
        return 'Dark (Slate)';
      case AppThemeMode.amoled:
        return 'AMOLED Pure Black';
    }
  }

  String _getBandwidthName(BandwidthMode mode) {
    switch (mode) {
      case BandwidthMode.dataSaver:
        return 'Data Saver (Low quality thumbnails)';
      case BandwidthMode.normal:
        return 'Normal';
      case BandwidthMode.highQuality:
        return 'High Quality (High resolution thumbnails)';
    }
  }

  void _showApiKeyDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.settings.customApiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom YouTube API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optionally supply your own Google Cloud YouTube Data API v3 key to eliminate shared quota limits.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              settings.setCustomApiKey(text.isEmpty ? null : text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDataDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset GAMATUBE?'),
        content: const Text(
          'This will permanently erase all local history, playlists, cached content, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await settings.clearAllLocalData();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All local data was reset.')),
                );
              }
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}
