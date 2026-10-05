import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/network_info.dart';
import '../providers/network_provider.dart';
import '../theme/app_colors.dart';

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final net = context.watch<NetworkProvider>();
    if (net.status == NetworkStatus.online) {
      return const SizedBox.shrink();
    }

    final isOffline = net.status == NetworkStatus.offline;
    final color = isOffline ? AppColors.error : AppColors.warning;
    final text = isOffline
        ? 'Offline Mode • Browsing saved library and cache'
        : 'Connecting to network...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      color: color.withAlpha(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
