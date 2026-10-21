import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../settings/settings_screen.dart';
import '../theme/app_colors.dart';

enum _AccountSheetPage { menu, switcher, addAccount }

class AccountSheet extends StatefulWidget {
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
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  _AccountSheetPage _currentPage = _AccountSheetPage.menu;

  // Form controllers for add account
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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

                // Render current page
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildPageContent(context, auth, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(BuildContext context, AuthProvider auth, bool isDark) {
    switch (_currentPage) {
      case _AccountSheetPage.switcher:
        return _buildAccountSwitcherPage(context, auth, isDark);
      case _AccountSheetPage.addAccount:
        return _buildAddAccountPage(context, auth, isDark);
      case _AccountSheetPage.menu:
        return _buildMainAccountMenu(context, auth, isDark);
    }
  }

  // ==========================================
  // PAGE 1: MAIN MENU
  // ==========================================
  Widget _buildMainAccountMenu(BuildContext context, AuthProvider auth, bool isDark) {
    final user = auth.user;
    final isIncognito = auth.isIncognito;

    return Column(
      key: const ValueKey('account_menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        if (isIncognito)
          _buildIncognitoHeader(context, auth, isDark)
        else if (auth.isAuthenticated && user != null)
          _buildUserHeader(context, user, auth, isDark)
        else
          _buildSignedOutHeader(context, auth, isDark),

        const Divider(height: 1, thickness: 1),

        // Action Items
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
              setState(() {
                _currentPage = _AccountSheetPage.switcher;
              });
            },
          ),

        _buildListTile(
          context,
          icon: Icons.workspace_premium_outlined,
          title: 'Get GamaTube Premium',
          subtitle: 'Ad-free playback & background streaming',
          iconColor: AppColors.primary,
          onTap: () => _showPremiumDialog(context),
        ),

        _buildListTile(
          context,
          icon: Icons.schedule_rounded,
          title: 'Time watched',
          onTap: () => _showTimeWatchedDialog(context),
        ),

        _buildListTile(
          context,
          icon: Icons.shield_outlined,
          title: 'Your data in YouTube',
          onTap: () => _showDataPrivacyDialog(context),
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
          onTap: () => _showHelpDialog(context),
        ),

        _buildListTile(
          context,
          icon: Icons.code_rounded,
          title: 'Developer info',
          onTap: () => _showDeveloperDialog(context),
        ),

        if (auth.isAuthenticated && !isIncognito)
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
    );
  }

  // ==========================================
  // PAGE 2: ACCOUNT SWITCHER
  // ==========================================
  Widget _buildAccountSwitcherPage(BuildContext context, AuthProvider auth, bool isDark) {
    final accounts = auth.savedAccounts;
    final currentId = auth.user?.id;
    final currentEmail = auth.user?.email;

    return Column(
      key: const ValueKey('account_switcher'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _currentPage = _AccountSheetPage.menu;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Accounts List
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No saved Google accounts found.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accounts.length,
            itemBuilder: (_, index) {
              final acc = accounts[index];
              final isSelected = acc.id == currentId || acc.email == currentEmail;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  backgroundImage: acc.avatarUrl != null ? NetworkImage(acc.avatarUrl!) : null,
                  child: acc.avatarUrl == null
                      ? Text(
                          acc.name.isNotEmpty ? acc.name[0].toUpperCase() : 'G',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${acc.displayHandle} • ${acc.email}'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final library = context.read<LibraryProvider>();
                  await auth.switchAccount(acc.id);
                  await library.loadLibraryData();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Switched to ${acc.email}'),
                      backgroundColor: const Color(0xFF1E8E3E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  navigator.pop();
                },
              );
            },
          ),

        const Divider(height: 1),

        // Add Account Button
        ListTile(
          leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
          title: const Text(
            'Add Google / Gmail account',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () {
            setState(() {
              _errorMessage = null;
              _currentPage = _AccountSheetPage.addAccount;
            });
          },
        ),

        // Use Signed Out
        ListTile(
          leading: const Icon(Icons.person_off_outlined),
          title: const Text('Use GamaTube signed out'),
          onTap: () async {
            Navigator.pop(context);
            await auth.signOut();
          },
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  // ==========================================
  // PAGE 3: ADD ACCOUNT
  // ==========================================
  Widget _buildAddAccountPage(BuildContext context, AuthProvider auth, bool isDark) {
    return Padding(
      key: const ValueKey('add_account'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Back button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _currentPage = _AccountSheetPage.switcher;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Add Google Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Error banner if any
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          // Option 1: Native Google Sign-In Chooser
          FilledButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final library = context.read<LibraryProvider>();
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    final ok = await auth.signIn();
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (ok) {
                      await library.loadLibraryData();
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Added and switched to ${auth.user?.email ?? "Google Account"}'),
                          backgroundColor: const Color(0xFF1E8E3E),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      setState(() {
                        _errorMessage = 'Google picker was closed or unconfigured. Enter your Gmail address below to add account instantly.';
                      });
                    }
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.account_box_rounded),
            label: const Text('Choose Device Google Account'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR ENTER GMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
            ],
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Gmail Address',
              hintText: 'e.g. yourname@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF1F3F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display Name (Optional)',
              hintText: 'e.g. Gautam',
              prefixIcon: const Icon(Icons.badge_outlined),
              filled: true,
              fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF1F3F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 18),

          FilledButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final library = context.read<LibraryProvider>();
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() => _errorMessage = 'Please enter a valid Gmail address');
                      return;
                    }
                    final fullEmail = email.contains('@') ? email : '$email@gmail.com';

                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });

                    final ok = await auth.signInWithGmail(
                      fullEmail,
                      displayName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
                    );

                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (ok) {
                      await library.loadLibraryData();
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Successfully added and switched to $fullEmail'),
                          backgroundColor: const Color(0xFF1E8E3E),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      setState(() => _errorMessage = 'Failed to add account. Please check your address.');
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add & Switch To Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // HEADERS & DIALOGS
  // ==========================================
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
            radius: 26,
            backgroundColor: AppColors.primary,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'G',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                    setState(() {
                      _currentPage = _AccountSheetPage.switcher;
                    });
                  },
                  child: const Text(
                    'Switch or add account',
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
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              setState(() {
                _currentPage = _AccountSheetPage.switcher;
              });
            },
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're Incognito",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
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
                  onPressed: () {
                    setState(() {
                      _currentPage = _AccountSheetPage.addAccount;
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Sign in with Google / Gmail', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
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

  void _showPremiumDialog(BuildContext context) {
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

  void _showTimeWatchedDialog(BuildContext context) {
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

  void _showDataPrivacyDialog(BuildContext context) {
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to GAMATUBE v1.3.3!'),
            SizedBox(height: 10),
            Text('• Background Play: Minimizing the app or turning off the screen keeps audio playing continuously with system notification controls.'),
            SizedBox(height: 6),
            Text('• Multi-Account: Switch between multiple Google / Gmail accounts seamlessly in this Account sheet.'),
            SizedBox(height: 6),
            Text('• Picture-in-Picture: Tap the PiP button while playing to pop out the video.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showDeveloperDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Developer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bhuwan Gautam',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Full-Stack & Mobile Developer passionate about building high-performance, privacy-focused open source applications.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://gautambhuwan.com.np'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text(
                'https://gautambhuwan.com.np',
                style: TextStyle(
                  color: Color(0xFF3EA6FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
