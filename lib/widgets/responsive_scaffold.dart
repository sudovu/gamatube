import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'gamatube_logo.dart';
import 'network_status_banner.dart';

class ResponsiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;
  final Widget body;
  final Widget? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        return Scaffold(
          body: Column(
            children: [
              const NetworkStatusBanner(),
              Expanded(
                child: Row(
                  children: [
                    if (isDesktop || isTablet)
                      _buildNavigationRail(context, isDesktop),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: (isDesktop || isTablet)
              ? null
              : _buildBottomNavigationBar(context),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool isDesktop) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: isDesktop ? 220 : 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF272727) : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 18,
              horizontal: isDesktop ? 20 : 12,
            ),
            child: GamatubeLogo(
              size: 24,
              showText: isDesktop,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isDesktop: isDesktop,
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  icon: Icons.flash_on_outlined,
                  activeIcon: Icons.flash_on_rounded,
                  label: 'Shorts',
                  isDesktop: isDesktop,
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  icon: Icons.subscriptions_outlined,
                  activeIcon: Icons.subscriptions_rounded,
                  label: 'Subscriptions',
                  isDesktop: isDesktop,
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  icon: Icons.account_circle_outlined,
                  activeIcon: Icons.account_circle_rounded,
                  label: 'You',
                  isDesktop: isDesktop,
                ),
                const Divider(height: 24),
                _buildNavItem(
                  context,
                  index: 4,
                  icon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  label: 'Search',
                  isDesktop: isDesktop,
                ),
                _buildNavItem(
                  context,
                  index: 5,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isDesktop: isDesktop,
                ),
              ],
            ),
          ),
          if (isDesktop)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF212121) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      auth.user?.name.isNotEmpty == true ? auth.user!.name[0].toUpperCase() : 'G',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user?.name ?? 'Guest User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          auth.isAuthenticated ? 'Signed In' : 'Local Mode',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDesktop,
  }) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? (isDark ? const Color(0xFF272727) : const Color(0xFFE5E5E5))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onNavigationChanged(index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 11,
              horizontal: isDesktop ? 16 : 0,
            ),
            child: Row(
              mainAxisAlignment:
                  isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex.clamp(0, 3),
      onDestinationSelected: onNavigationChanged,
      indicatorColor: Colors.transparent,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.flash_on_outlined),
          selectedIcon: Icon(Icons.flash_on_rounded),
          label: 'Shorts',
        ),
        NavigationDestination(
          icon: Icon(Icons.subscriptions_outlined),
          selectedIcon: Icon(Icons.subscriptions_rounded),
          label: 'Subscriptions',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle_rounded),
          label: 'You',
        ),
      ],
    );
  }
}
