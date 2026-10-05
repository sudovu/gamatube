import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GamatubeLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const GamatubeLogo({
    super.key,
    this.size = 24,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Iconic Red Play Badge (YouTube Silhouette)
        Container(
          width: size * 1.35,
          height: size * 0.95,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(80),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: size * 0.72,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 6),
          Text(
            'GamaTube',
            style: TextStyle(
              fontSize: size * 0.78,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: isDark ? Colors.white : const Color(0xFF0F0F0F),
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ],
    );
  }
}
