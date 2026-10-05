import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GamatubeLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const GamatubeLogo({
    super.key,
    this.size = 28,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(50),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.65,
              letterSpacing: -1,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              text: 'GAMA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: size * 0.68,
                letterSpacing: 0.5,
              ),
              children: [
                TextSpan(
                  text: 'TUBE',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
