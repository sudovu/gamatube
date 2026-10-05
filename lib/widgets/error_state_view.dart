import 'package:flutter/material.dart';
import '../core/errors/failures.dart';
import '../theme/app_colors.dart';

class ErrorStateView extends StatelessWidget {
  final Failure? failure;
  final String? customMessage;
  final VoidCallback? onRetry;

  const ErrorStateView({
    super.key,
    this.failure,
    this.customMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ?? failure?.message ?? 'An unexpected error occurred.';
    final hint = failure?.actionHint ?? 'Try again';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(hint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
