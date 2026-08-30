import 'package:flutter/material.dart';
import 'status_request.dart';

class HandlingDataRequest extends StatelessWidget {
  final StatusRequest statusRequest;
  final Widget widget;
  final VoidCallback? onRetry;

  const HandlingDataRequest({
    super.key,
    required this.statusRequest,
    required this.widget,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (statusRequest) {
      case StatusRequest.none:
      case StatusRequest.success:
        return widget;
      case StatusRequest.loading:
        return const Center(
          child: CircularProgressIndicator.adaptive(),
        );
      case StatusRequest.offline:
        return _ErrorState(
          icon: Icons.cloud_off_outlined,
          message: 'لا يوجد اتصال بالإنترنت',
          onRetry: onRetry,
        );
      case StatusRequest.serverFailure:
        return _ErrorState(
          icon: Icons.error_outline,
          message: 'حدث خطأ في الخادم',
          onRetry: onRetry,
        );
      case StatusRequest.failure:
        return _ErrorState(
          icon: Icons.error_outline,
          message: 'حدث خطأ، حاول مرة أخرى',
          onRetry: onRetry,
        );
    }
  }
}

class _ErrorState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ],
        ),
      ),
    );
  }
}
