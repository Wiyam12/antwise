import 'package:antwise/presentation/bindings/create_new_page_binding.dart';
import 'package:antwise/presentation/bindings/create_page_binding.dart';
import 'package:antwise/presentation/bindings/create_table_binding.dart';
import 'package:antwise/presentation/bindings/create_widget_binding.dart';
import 'package:antwise/presentation/bindings/download_resources_binding.dart';
import 'package:antwise/presentation/bindings/home_binding.dart';
import 'package:antwise/presentation/bindings/settings_binding.dart';
import 'package:antwise/presentation/bindings/splash_binding.dart';
import 'package:antwise/presentation/pages/create_page/create_new_page_screen.dart';
import 'package:antwise/presentation/pages/create_page/create_page_screen.dart';
import 'package:antwise/presentation/pages/create_page/create_table_screen.dart';
import 'package:antwise/presentation/pages/create_page/create_widget_screen.dart';
import 'package:antwise/presentation/pages/download_resources_page.dart';
import 'package:antwise/presentation/pages/home_page.dart';
import 'package:antwise/presentation/pages/settings/settings_bottom_nav_page.dart';
import 'package:antwise/presentation/pages/settings/settings_deleted_pages_page.dart';
import 'package:antwise/presentation/pages/settings/settings_drawer_nav_page.dart';
import 'package:antwise/presentation/pages/settings/edit_table_screen.dart';
import 'package:antwise/presentation/pages/settings/settings_page_layout_edit_page.dart';
import 'package:antwise/presentation/pages/settings/settings_page_layouts_page.dart';
import 'package:antwise/presentation/pages/settings/settings_page.dart';
import 'package:antwise/presentation/pages/settings/settings_widget_edit_page.dart';
import 'package:antwise/presentation/pages/settings/settings_tables_page.dart';
import 'package:antwise/presentation/pages/settings/settings_widgets_page.dart';
import 'package:antwise/presentation/pages/settings/theme_settings_page.dart';
import 'package:antwise/presentation/pages/splash_page.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:get/get.dart';

class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> routes = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.splash,
      page: SplashPage.new,
      binding: SplashBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.downloadResources,
      page: DownloadResourcesPage.new,
      binding: DownloadResourcesBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: HomePage.new,
      binding: HomeBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.createPage,
      page: CreatePageScreen.new,
      binding: CreatePageBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.createNewPage,
      page: CreateNewPageScreen.new,
      binding: CreateNewPageBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.createTable,
      page: CreateTableScreen.new,
      binding: CreateTableBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.createWidget,
      page: CreateWidgetScreen.new,
      binding: CreateWidgetBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settings,
      page: SettingsPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsBottomNav,
      page: SettingsBottomNavPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsDrawerNav,
      page: SettingsDrawerNavPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsDeletedPages,
      page: SettingsDeletedPagesPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsTheme,
      page: ThemeSettingsPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsPageLayouts,
      page: SettingsPageLayoutsPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsPageLayoutEdit,
      page: SettingsPageLayoutEditPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsTables,
      page: SettingsTablesPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsEditTable,
      page: EditTableScreen.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsWidgets,
      page: SettingsWidgetsPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settingsEditWidget,
      page: SettingsWidgetEditPage.new,
      binding: SettingsBinding(),
    ),
  ];
}
