import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../settings/settings_screen.dart';
import '../theme/app_colors.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = auth.user;
    final isIncognito = auth.isIncognito;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Card
              if (isIncognito)
                _buildIncognitoHeader(context, auth, isDark)
              else if (auth.isAuthenticated && user != null)
                _buildUserHeader(context, user, auth, isDark)
              else
                _buildSignedOutHeader(context, auth, isDark),

              const Divider(height: 1, thickness: 1),

              // Action List Items
              _buildListTile(
                context,
                icon: isIncognito ? Icons.visibility_off_rounded : Icons.visibility_off_outlined,
                title: isIncognito ? 'Turn off Incognito' : 'Turn on Incognito',
                iconColor: isIncognito ? AppColors.primary : null,
                onTap: () {
                  Navigator.pop(context);
                  auth.toggleIncognito();
                },
              ),

              if (!isIncognito && auth.isAuthenticated)
                _buildListTile(
                  context,
                  icon: Icons.switch_account_outlined,
                  title: 'Switch account',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    _showAccountSwitcher(context, auth);
                  },
                ),

              _buildListTile(
                context,
                icon: Icons.workspace_premium_outlined,
                title: 'Get GamaTube Premium',
                subtitle: 'Ad-free playback & background streaming',
                iconColor: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  _showPremiumDialog(context);
                },
              ),

              _buildListTile(
                context,
                icon: Icons.schedule_rounded,
                title: 'Time watched',
                onTap: () {
                  Navigator.pop(context);
                  _showTimeWatchedDialog(context);
                },
              ),

              _buildListTile(
                context,
                icon: Icons.shield_outlined,
                title: 'Your data in YouTube',
                onTap: () {
                  Navigator.pop(context);
                  _showDataPrivacyDialog(context);
                },
              ),

              const Divider(height: 16),

              _buildListTile(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),

              _buildListTile(
                context,
                icon: Icons.help_outline_rounded,
                title: 'Help and feedback',
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(
                    Uri.parse('https://github.com/sudovu/gamatube/issues'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),

              if (auth.isAuthenticated)
                _buildListTile(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  textColor: Colors.redAccent,
                  iconColor: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    await auth.signOut();
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(
    BuildContext context,
    UserProfile user,
    AuthProvider auth,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'G',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.displayHandle} • ${user.email}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://myaccount.google.com/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text(
                    'Manage your Google Account',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3EA6FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncognitoHeader(BuildContext context, AuthProvider auth, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Colors.black,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF272727),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You're Incognito",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Watch & search history are paused',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutHeader(BuildContext context, AuthProvider auth, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFEEEEEE),
                child: Icon(Icons.account_circle_outlined, size: 36, color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign in to GamaTube', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Sync subscriptions, watch history, and liked videos', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await auth.signIn();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showAddGmailDialog(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Add Gmail'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Icon(icon, size: 22, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  static void _showAccountSwitcher(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final accounts = auth.savedAccounts;
        final currentId = auth.user?.id;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Text(
                    'Accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    itemBuilder: (_, index) {
                      final acc = accounts[index];
                      final isSelected = acc.id == currentId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          backgroundImage: acc.avatarUrl != null ? NetworkImage(acc.avatarUrl!) : null,
                          child: acc.avatarUrl == null
                              ? Text(acc.name.isNotEmpty ? acc.name[0].toUpperCase() : 'G', style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${acc.displayHandle} • ${acc.email}'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () {
                          auth.switchAccount(acc.id);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Add Google / Gmail account', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddGmailDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showAddGmailDialog(BuildContext context) {
    final emailController = TextEditingController(text: 'vhuwonmathers12@gmail.com');
    final nameController = TextEditingController(text: 'Vhuwon Mathers');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Google Account Sign-In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Gmail address to sync your YouTube profile, channel, subscriptions, and playlists seamlessly.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Gmail / Google Address',
                  hintText: 'yourname@gmail.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name (Channel Name)',
                  hintText: 'Your Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final email = emailController.text.trim();
                final name = nameController.text.trim();
                if (email.isNotEmpty) {
                  context.read<AuthProvider>().signInWithGmail(
                    email,
                    displayName: name.isNotEmpty ? name : null,
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

  static void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('GamaTube Premium'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All core premium features are included free & open-source in GAMATUBE:'),
            SizedBox(height: 12),
            Text('• 100% Ad-Free Video Streaming'),
            Text('• Background Audio & Picture-in-Picture'),
            Text('• Local-First Privacy & Zero Tracking'),
            Text('• Instant AI Video Summaries'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Awesome'),
          ),
        ],
      ),
    );
  }

  static void _showTimeWatchedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Time watched'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today: 48 minutes', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Daily average: 1 hr 12 min'),
            SizedBox(height: 12),
            Text(
              'GamaTube respects your digital wellbeing with zero autoplay traps and mindful viewing tools.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  static void _showDataPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your Data in GamaTube'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Zero private data is harvested or transmitted to third-party ad networks.'),
            Text('• Watch history and search queries stay local on your device.'),
            Text('• Google OAuth tokens are stored in secure encrypted storage only.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
