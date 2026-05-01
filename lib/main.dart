import 'package:antwise/core/constants/app_constants.dart';
import 'package:antwise/core/services/notification_dispatcher_service.dart';
import 'package:antwise/core/services/notification_runtime_service.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/core/theme/app_theme.dart';
import 'package:antwise/core/theme/app_theme_controller.dart';
import 'package:antwise/presentation/bindings/initial_binding.dart';
import 'package:antwise/presentation/routes/app_pages.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final HiveService hiveService = HiveService();
  await hiveService.init();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppThemeController themeController = AppThemeController(hiveService);
  await themeController.loadFromStorage();
  Get.put<HiveService>(hiveService, permanent: true);
  Get.put<SharedPreferences>(prefs, permanent: true);
  Get.put<AppThemeController>(themeController, permanent: true);
  NotificationDispatcherService.instance.initialize();
  await NotificationRuntimeService.ensureInitialized();
  await NotificationRuntimeService.setupBackgroundChecks();
  await NotificationRuntimeService.evaluateRulesAndNotify();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialRoute});

  /// Defaults to [AppRoutes.splash]. Tests may set [AppRoutes.home] to skip startup flow.
  final String? initialRoute;

  @override
  Widget build(BuildContext context) {
    final AppThemeController themeController = Get.find<AppThemeController>();
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(
          primary: themeController.selectedPreset.primary,
          secondary: themeController.selectedPreset.secondary,
          onPrimary: themeController.selectedPreset.onPrimary,
        ),
        darkTheme: AppTheme.dark(
          primary: themeController.selectedPreset.primary,
          secondary: themeController.selectedPreset.secondary,
          onPrimary: themeController.selectedPreset.onPrimary,
        ),
        themeMode: themeController.themeMode.value,
        initialBinding: InitialBinding(),
        initialRoute: initialRoute ?? AppRoutes.splash,
        getPages: AppPages.routes,
      ),
    );
  }
}
