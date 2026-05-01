import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationDisplayData {
  const NotificationDisplayData({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
  });

  final int id;
  final String title;
  final String body;
  final String severity;
}

class NotificationDispatcherService with WidgetsBindingObserver {
  NotificationDispatcherService._();

  static final NotificationDispatcherService instance =
      NotificationDispatcherService._();

  bool _initialized = false;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;

  void initialize() {
    if (_initialized) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _lastLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
  }

  Future<void> dispatch({
    required NotificationDisplayData data,
    required Future<void> Function(NotificationDisplayData data)
    showSystemNotification,
  }) async {
    if (_shouldShowInline()) {
      _showInline(data);
      return;
    }
    await showSystemNotification(data);
  }

  bool _shouldShowInline() {
    final bool isForeground = _lastLifecycleState == AppLifecycleState.resumed;
    final bool hasUiContext = Get.context != null;
    return isForeground && hasUiContext;
  }

  void _showInline(NotificationDisplayData data) {
    final ({Color color, IconData icon}) style = switch (data.severity) {
      'danger' => (color: Colors.red, icon: Icons.warning_amber_rounded),
      'warning' => (color: Colors.orange, icon: Icons.schedule_rounded),
      _ => (color: Colors.blue, icon: Icons.info_outline_rounded),
    };
    Get.closeAllSnackbars();
    Get.snackbar(
      data.title,
      data.body,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 12,
      backgroundColor: style.color.withValues(alpha: 0.95),
      colorText: Colors.white,
      icon: Icon(style.icon, color: Colors.white),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      shouldIconPulse: false,
      barBlur: 0,
      mainButton: TextButton(
        onPressed: Get.closeCurrentSnackbar,
        child: const Text('Close', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
