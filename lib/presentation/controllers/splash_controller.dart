import 'package:antwise/core/services/logger_service.dart';
import 'package:antwise/domain/usecases/check_resources_downloaded_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// Runs startup checks and routes to download flow or home.
class SplashController extends GetxController {
  SplashController(this._checkResourcesDownloaded);

  final CheckResourcesDownloadedUseCase _checkResourcesDownloaded;

  /// Shown on splash while waiting for minimum display; 0 = countdown finished.
  final RxInt splashSecondsLeft = 0.obs;

  static const Duration _minDisplayDuration = Duration(seconds: 2);
  static const Duration _checkTimeout = Duration(seconds: 8);

  @override
  void onInit() {
    super.onInit();
    // Ensures the navigator is mounted before [Get.offAllNamed] (avoids stuck splash).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runFlow();
    });
  }

  Future<void> _runFlow() async {
    try {
      final Future<bool> checkFuture = _startupAssetsReady();
      final Future<void> minDisplayFuture = _runSplashCountdown();

      final bool ready = await checkFuture;
      await minDisplayFuture;

      if (ready) {
        Get.offAllNamed<void>(AppRoutes.home);
      } else {
        Get.offAllNamed<void>(AppRoutes.downloadResources);
      }
    } catch (e, st) {
      if (Get.isRegistered<LoggerService>()) {
        Get.find<LoggerService>().d('Splash navigation failed', e, st);
      }
      Get.offAllNamed<void>(AppRoutes.downloadResources);
    }
  }

  Future<bool> _startupAssetsReady() async {
    try {
      return await _safeCheckResources();
    } catch (e, st) {
      if (Get.isRegistered<LoggerService>()) {
        Get.find<LoggerService>().d('Splash asset check failed', e, st);
      }
      return false;
    }
  }

  Future<bool> _safeCheckResources() async {
    try {
      return await _checkResourcesDownloaded().timeout(_checkTimeout);
    } catch (e, st) {
      if (Get.isRegistered<LoggerService>()) {
        Get.find<LoggerService>().d('Splash resource check failed', e, st);
      }
      return false;
    }
  }

  Future<void> _runSplashCountdown() async {
    final int totalSeconds = _minDisplayDuration.inSeconds;
    if (totalSeconds <= 0) {
      return;
    }
    for (int s = totalSeconds; s > 0; s--) {
      splashSecondsLeft.value = s;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    splashSecondsLeft.value = 0;
  }
}
