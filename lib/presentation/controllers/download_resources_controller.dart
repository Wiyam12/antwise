import 'dart:async';

import 'package:antwise/core/services/logger_service.dart';
import 'package:antwise/domain/usecases/check_resources_downloaded_usecase.dart';
import 'package:antwise/domain/usecases/download_app_resources_usecase.dart';
import 'package:antwise/domain/usecases/mark_resources_downloaded_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Downloads required app resources, then continues.
class DownloadResourcesController extends GetxController {
  DownloadResourcesController(
    this._markDownloaded,
    this._downloadResources,
    this._checkResourcesDownloaded,
  );

  final MarkResourcesDownloadedUseCase _markDownloaded;
  final DownloadAppResourcesUseCase _downloadResources;
  final CheckResourcesDownloadedUseCase _checkResourcesDownloaded;

  final RxDouble progress = 0.0.obs;
  final RxString statusMessage = 'Preparing download…'.obs;
  final RxBool isComplete = false.obs;
  final RxBool isBusy = false.obs;
  final RxnString errorMessage = RxnString();

  late final bool _popWhenDone;

  @override
  void onInit() {
    super.onInit();
    final dynamic args = Get.arguments;
    _popWhenDone = args is Map && args['popWhenDone'] == true;
    _startDownload();
  }

  /// Retry after a failure (or to resume from a partial `.partial` file).
  Future<void> retry() => _startDownload();

  Future<void> _startDownload() async {
    if (isBusy.value) {
      return;
    }
    isBusy.value = true;
    errorMessage.value = null;
    isComplete.value = false;
    try {
      final bool needResources = !(await _checkResourcesDownloaded());

      if (!needResources) {
        await _navigateAfterSuccess();
        return;
      }
      statusMessage.value = 'Downloading app resources…';
      await _downloadResources(
        onProgress: (double value) {
          progress.value = value.clamp(0.0, 1.0);
          statusMessage.value =
              'Downloading app resources… '
              '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%';
        },
      );
      await _markDownloaded();

      progress.value = 1.0;
      await _navigateAfterSuccess();
    } catch (e, st) {
      Get.find<LoggerService>().d('Download failed', e, st);
      errorMessage.value =
          'Download failed. Check your connection and tap Retry.';
      statusMessage.value = 'Error';
      progress.value = 0;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> _navigateAfterSuccess() async {
    statusMessage.value = 'Finalizing…';
    isComplete.value = true;
    statusMessage.value = 'Ready';
    final bool shouldPop = _popWhenDone;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (shouldPop) {
      final NavigatorState? nav = Get.key.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        return;
      }
    }
    Get.offAllNamed<void>(AppRoutes.home);
  }
}
