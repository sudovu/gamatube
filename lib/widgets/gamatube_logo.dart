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
        // Creative 3D Neon-Ruby Play Emblem
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Outer Halo Glow
            Container(
              width: size * 1.35,
              height: size * 0.96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0033).withAlpha(120),
                    blurRadius: size * 0.45,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFE50914).withAlpha(70),
                    blurRadius: size * 0.2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),

            // Main Badge with rich Ruby/Crimson 3D Gradient
            Container(
              width: size * 1.35,
              height: size * 0.96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF2A55), // Radiant Crimson
                    Color(0xFFE50914), // Pure YouTube Red
                    Color(0xFF990022), // Deep Velvet Ruby
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withAlpha(50),
                  width: 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner Specular Glass Highlight (top-left gloss)
                  Positioned(
                    top: 1,
                    left: 2,
                    right: 2,
                    height: size * 0.4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.24)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(60),
                            Colors.white.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Crisp White Play Triangle
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: size * 0.72,
                  ),
                ],
              ),
            ),

            // Gamma Energy Sparkle / Pulse Badge at top-right
            Positioned(
              top: -2,
              right: -3,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(200),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Creative Typography
        if (showText) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'GAMA',
                style: TextStyle(
                  fontSize: size * 0.82,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white : const Color(0xFF0F0F0F),
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: EdgeInsets.symmetric(horizontal: size * 0.18, vertical: size * 0.05),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0033), Color(0xFFB00020)],
                  ),
                  borderRadius: BorderRadius.circular(size * 0.16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(90),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  'TUBE',
                  style: TextStyle(
                    fontSize: size * 0.70,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: Colors.white,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
