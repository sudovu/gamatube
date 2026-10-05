import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../playback/video_player_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/video_card.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
      ),
      body: !auth.isAuthenticated
          ? EmptyStateView(
              icon: Icons.subscriptions_outlined,
              title: 'Keep up with your favorite channels',
              message:
                  'Sign in with your Google account to sync your subscribed channels and feeds directly.',
              action: FilledButton.icon(
                onPressed: () => auth.signIn(),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Continue with Google'),
              ),
            )
          : ListView(
              children: [
                // Horizontal subscribed channels rail
                Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: 8,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withAlpha(40),
                            child: Text(
                              'C${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Creator ${index + 1}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(),
                // Subscription Feed videos
                ...home.feedVideos.map((video) => VideoCard(
                      video: video,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: video),
                          ),
                        );
                      },
                    )),
              ],
            ),
    );
  }
}
