import 'package:antwise/presentation/controllers/download_resources_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Mandatory resource download; back navigation is disabled until complete.
class DownloadResourcesPage extends GetView<DownloadResourcesController> {
  const DownloadResourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Downloading resources'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final double p = controller.progress.value.clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Required content must finish downloading before you can continue.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                LinearProgressIndicator(
                  value: p,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.statusMessage.value,
                  style: theme.textTheme.titleMedium,
                ),
                if (controller.errorMessage.value != null) ...<Widget>[
                  const SizedBox(height: 24),
                  Text(
                    controller.errorMessage.value!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const Spacer(),
                if (!controller.isComplete.value &&
                    controller.errorMessage.value == null)
                  Text(
                    'Please wait — skipping is not available.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
