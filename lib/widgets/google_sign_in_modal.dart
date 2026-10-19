import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';

class GoogleSignInModal extends StatefulWidget {
  const GoogleSignInModal({super.key});

  static Future<bool?> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const GoogleSignInModal(),
    );
  }

  @override
  State<GoogleSignInModal> createState() => _GoogleSignInModalState();
}

class _GoogleSignInModalState extends State<GoogleSignInModal> {
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

  Future<void> _submitDirectGmail(AuthProvider auth, LibraryProvider library) async {
    final emailText = _emailController.text.trim();
    if (emailText.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Gmail address');
      return;
    }

    final fullEmail = emailText.contains('@') ? emailText : '$emailText@gmail.com';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await auth.signInWithGmail(
        fullEmail,
        displayName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          await library.loadLibraryData();
          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Signed in as $fullEmail'),
                  ],
                ),
                backgroundColor: const Color(0xFF1E8E3E),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          setState(() => _errorMessage = 'Failed to sign in. Please verify your address.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _tryNativeGoogleSignIn(AuthProvider auth, LibraryProvider library) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await auth.signIn();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        await library.loadLibraryData();
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Signed in as ${auth.user?.email ?? "Google User"}'),
                ],
              ),
              backgroundColor: const Color(0xFF1E8E3E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'System Google Sign-In not configured or was cancelled. Enter your Gmail address below to sign in instantly.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final savedAccounts = auth.savedAccounts;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Google Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGoogleGLogo(),
                const SizedBox(width: 10),
                Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to synchronize your subscriptions, watch history, and liked videos directly across GamaTube.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Error notice if any
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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

            // Saved Accounts List (if available)
            if (savedAccounts.isNotEmpty) ...[
              Text(
                'Choose an account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282828) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: savedAccounts.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0),
                  ),
                  itemBuilder: (context, index) {
                    final acc = savedAccounts[index];
                    final isCurrent = auth.user?.email == acc.email;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        backgroundImage: acc.avatarUrl != null ? NetworkImage(acc.avatarUrl!) : null,
                        child: acc.avatarUrl == null
                            ? Text(
                                acc.name.isNotEmpty ? acc.name[0].toUpperCase() : 'G',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(
                        acc.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        acc.email,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E8E3E), size: 20)
                          : const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isLoading = true);
                        await auth.switchAccount(acc.id);
                        await library.loadLibraryData();
                        if (mounted) {
                          setState(() => _isLoading = false);
                          nav.pop(true);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Switched to ${acc.email}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or enter new account', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
                  Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Quick Google Sign-In Action Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : () => _tryNativeGoogleSignIn(auth, library),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.account_circle_rounded, size: 20),
              label: const Text(
                'Continue with Google Account',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or sign in with Gmail', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
                Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
              ],
            ),
            const SizedBox(height: 16),

            // Direct Gmail Input Fields
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Gmail Address',
                hintText: 'username@gmail.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF1F3F4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'e.g. Gautam Bhuwan',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF1F3F4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
              ),
              onPressed: _isLoading ? null : () => _submitDirectGmail(auth, library),
              child: const Text(
                'Sign In with Gmail Address',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleGLogo() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4285F4),
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }
}
