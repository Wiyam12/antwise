import 'package:antwise/presentation/controllers/download_resources_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Mandatory app resource download; back navigation disabled while busy.
class DownloadResourcesPage extends GetView<DownloadResourcesController> {
  const DownloadResourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Obx(() {
      final bool busy = controller.isBusy.value;
      final double p = controller.progress.value.clamp(0.0, 1.0);
      final int pct = (p * 100).round().clamp(0, 100);
      final String? error = controller.errorMessage.value;

      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Downloading resources'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Required content must finish downloading before you can '
                  'continue.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                LinearProgressIndicator(
                  value: p <= 0 && busy ? null : p,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Text(
                  '$pct%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.statusMessage.value,
                  style: theme.textTheme.titleMedium,
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 24),
                  Text(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: busy ? null : () => controller.retry(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
                const Spacer(),
                if (busy && error == null)
                  Text(
                    'Please wait — you cannot go back during download.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
