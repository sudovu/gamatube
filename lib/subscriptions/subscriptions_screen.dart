import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../playback/video_player_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/account_sheet.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/video_card.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String _selectedFilter = 'All';
  String? _selectedChannelFilter;

  final List<String> _filters = const [
    'All',
    'Today',
    'Videos',
    'Shorts',
    'Live',
    'Unwatched',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subscribedChannels = library.subscribedChannels;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Subscriptions',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_rounded),
            tooltip: 'Cast',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Searching for Google Cast devices...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () {
              _showNotificationsSheet(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0, left: 4.0),
            child: GestureDetector(
              onTap: () => AccountSheet.show(context),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: auth.isIncognito ? Colors.grey[800] : AppColors.primary,
                backgroundImage: (!auth.isIncognito && auth.user?.avatarUrl != null)
                    ? NetworkImage(auth.user!.avatarUrl!)
                    : null,
                child: auth.isIncognito
                    ? const Icon(Icons.visibility_off, size: 14, color: Colors.white)
                    : (auth.user?.avatarUrl == null
                        ? Text(
                            auth.user?.displayName.isNotEmpty == true
                                ? auth.user!.displayName[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null),
              ),
            ),
          ),
        ],
      ),
      body: !auth.isAuthenticated && subscribedChannels.isEmpty
          ? EmptyStateView(
              icon: Icons.subscriptions_outlined,
              title: 'Don\'t miss new videos',
              message:
                  'Sign in to see updates from your favorite YouTube channels, personalized recommendations, and notifications.',
              action: Column(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => auth.signIn(),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => AccountSheet.showAddGmailDialog(context),
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('Or add Gmail address directly'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await home.loadFeed();
                await library.loadLibraryData();
              },
              child: CustomScrollView(
                slivers: [
                  // Horizontal Channels Avatar Rail
                  SliverToBoxAdapter(
                    child: Container(
                      height: 104,
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF272727) : const Color(0xFFE5E5E5),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: subscribedChannels.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          if (index == subscribedChannels.length) {
                            // "All" / Manage pill
                            return InkWell(
                              onTap: () => _showManageChannelsSheet(context, library),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
                                      ),
                                      child: const Icon(Icons.arrow_forward_rounded, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'All',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3EA6FF)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final channel = subscribedChannels[index];
                          final isSelected = _selectedChannelFilter == channel.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedChannelFilter == channel.id) {
                                  _selectedChannelFilter = null;
                                } else {
                                  _selectedChannelFilter = channel.id;
                                }
                              });
                            },
                            child: SizedBox(
                              width: 64,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: isSelected
                                              ? Border.all(color: AppColors.primary, width: 2)
                                              : null,
                                        ),
                                        child: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFEEEEEE),
                                          backgroundImage: channel.avatarUrl.isNotEmpty
                                              ? NetworkImage(channel.avatarUrl)
                                              : null,
                                          child: channel.avatarUrl.isEmpty
                                              ? Text(
                                                  channel.title.isNotEmpty ? channel.title[0] : 'C',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                )
                                              : null,
                                        ),
                                      ),
                                      // Blue unread activity indicator dot
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3EA6FF),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    channel.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // YouTube Filter Chips Bar
                  SliverToBoxAdapter(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = _selectedFilter == filter;

                          return ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = filter);
                              }
                            },
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : (isDark ? const Color(0xFFF1F1F1) : const Color(0xFF0F0F0F)),
                            ),
                            selectedColor: isDark ? Colors.white : const Color(0xFF0F0F0F),
                            backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide.none,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          );
                        },
                      ),
                    ),
                  ),

                  // Active Channel Filter Banner (if selected)
                  if (_selectedChannelFilter != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                        child: Row(
                          children: [
                            Text(
                              'Showing videos from: ${subscribedChannels.firstWhere((c) => c.id == _selectedChannelFilter, orElse: () => const Channel(id: '', title: '', description: '', avatarUrl: '')).title}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _selectedChannelFilter = null),
                              child: const Text(
                                'Clear',
                                style: TextStyle(fontSize: 12, color: Color(0xFF3EA6FF), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Feed Videos
                  _buildVideosList(home, library, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildVideosList(HomeProvider home, LibraryProvider library, bool isDark) {
    var videos = home.feedVideos;

    if (_selectedChannelFilter != null) {
      final channel = library.subscribedChannels.firstWhere(
        (c) => c.id == _selectedChannelFilter,
        orElse: () => const Channel(id: '', title: '', description: '', avatarUrl: ''),
      );
      videos = videos
          .where((v) =>
              v.channelTitle.toLowerCase().contains(channel.title.toLowerCase()) ||
              v.channelId.toLowerCase() == channel.id.toLowerCase())
          .toList();
    }

    if (videos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 56, color: Colors.grey.withAlpha(150)),
              const SizedBox(height: 12),
              const Text('No subscription videos found for this filter.', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Explore other channels or clear the filter', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final video = videos[index];
          return VideoCard(
            video: video,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(video: video),
                ),
              );
            },
          );
        },
        childCount: videos.length,
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildNotificationTile(
                        channel: 'Veritasium',
                        title: 'uploaded: The Bizarre Physics of Fire',
                        time: '2 hours ago',
                        avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
                      ),
                      _buildNotificationTile(
                        channel: 'Marques Brownlee',
                        title: 'uploaded: Smartphone Awards 2026!',
                        time: '5 hours ago',
                        avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
                      ),
                      _buildNotificationTile(
                        channel: 'Fireship',
                        title: 'uploaded: 100+ Computer Science Concepts Explained',
                        time: '1 day ago',
                        avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTile({
    required String channel,
    required String title,
    required String time,
    required String avatar,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(avatar),
      ),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(text: channel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: ' '),
            TextSpan(text: title),
          ],
        ),
      ),
      subtitle: Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.more_vert_rounded, size: 18),
      onTap: () {},
    );
  }

  void _showManageChannelsSheet(BuildContext context, LibraryProvider library) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final subs = library.subscribedChannels;

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All subscriptions (${subs.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: subs.isEmpty
                      ? const Center(child: Text('No subscriptions yet.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: subs.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final ch = subs[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: ch.avatarUrl.isNotEmpty ? NetworkImage(ch.avatarUrl) : null,
                                child: ch.avatarUrl.isEmpty
                                    ? Text(ch.title.isNotEmpty ? ch.title[0] : 'C')
                                    : null,
                              ),
                              title: Text(ch.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                ch.formattedSubscribers.isNotEmpty ? ch.formattedSubscribers : 'Creator channel',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.notifications_active_rounded, size: 20, color: Color(0xFF3EA6FF)),
                                tooltip: 'Subscribed • Notifications On',
                                onPressed: () {
                                  _showUnsubscribeConfirmDialog(ctx, library, ch);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUnsubscribeConfirmDialog(BuildContext context, LibraryProvider library, Channel channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unsubscribe from ${channel.title}?'),
        content: const Text('You will no longer receive updates and videos from this channel in your subscription feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              library.toggleSubscribe(channel);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
  }
}
