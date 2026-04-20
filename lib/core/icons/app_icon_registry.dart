import 'package:flutter/material.dart';

/// Central registry: page icon keys (stored in Hive) → [IconData] + search metadata.
abstract final class AppIconRegistry {
  static const String defaultKey = 'article_outlined';

  static IconData iconOf(String? key) {
    if (key == null || key.isEmpty) {
      return _map[defaultKey]!;
    }
    return _map[key] ?? _map[defaultKey]!;
  }

  static List<AppIconOption> get options => _options;

  static List<AppIconOption> filter(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return List<AppIconOption>.from(_options);
    }
    return _options
        .where(
          (AppIconOption o) =>
              o.key.toLowerCase().contains(q) ||
              o.searchBlob.contains(q),
        )
        .toList(growable: false);
  }

  static final Map<String, IconData> _map = <String, IconData>{
    for (final AppIconOption o in _options) o.key: o.icon,
  };

  static const List<AppIconOption> _options = <AppIconOption>[
    AppIconOption(key: 'article_outlined', icon: Icons.article_outlined, searchBlob: 'article document page text'),
    AppIconOption(key: 'home_outlined', icon: Icons.home_outlined, searchBlob: 'home house main'),
    AppIconOption(key: 'dashboard_outlined', icon: Icons.dashboard_outlined, searchBlob: 'dashboard grid'),
    AppIconOption(key: 'analytics_outlined', icon: Icons.analytics_outlined, searchBlob: 'analytics chart graph stats'),
    AppIconOption(key: 'wallet_outlined', icon: Icons.account_balance_wallet_outlined, searchBlob: 'wallet money finance'),
    AppIconOption(key: 'settings_outlined', icon: Icons.settings_outlined, searchBlob: 'settings gear'),
    AppIconOption(key: 'person_outlined', icon: Icons.person_outlined, searchBlob: 'person user profile account'),
    AppIconOption(key: 'notifications_outlined', icon: Icons.notifications_outlined, searchBlob: 'notifications bell alert'),
    AppIconOption(key: 'search', icon: Icons.search, searchBlob: 'search find magnify'),
    AppIconOption(key: 'favorite_outlined', icon: Icons.favorite_outline, searchBlob: 'favorite heart like'),
    AppIconOption(key: 'star_outlined', icon: Icons.star_outline, searchBlob: 'star rate'),
    AppIconOption(key: 'map_outlined', icon: Icons.map_outlined, searchBlob: 'map location'),
    AppIconOption(key: 'calendar_today', icon: Icons.calendar_today_outlined, searchBlob: 'calendar date schedule'),
    AppIconOption(key: 'email_outlined', icon: Icons.email_outlined, searchBlob: 'email mail message'),
    AppIconOption(key: 'chat_outlined', icon: Icons.chat_bubble_outline, searchBlob: 'chat message talk'),
    AppIconOption(key: 'shopping_cart_outlined', icon: Icons.shopping_cart_outlined, searchBlob: 'cart shop store'),
    AppIconOption(key: 'inventory_outlined', icon: Icons.inventory_2_outlined, searchBlob: 'inventory box stock'),
    AppIconOption(key: 'folder_outlined', icon: Icons.folder_outlined, searchBlob: 'folder directory'),
    AppIconOption(key: 'description_outlined', icon: Icons.description_outlined, searchBlob: 'description file note'),
    AppIconOption(key: 'task_outlined', icon: Icons.task_alt_outlined, searchBlob: 'task check todo'),
    AppIconOption(key: 'schedule', icon: Icons.schedule, searchBlob: 'schedule clock time'),
    AppIconOption(key: 'bar_chart', icon: Icons.bar_chart, searchBlob: 'bar chart report'),
    AppIconOption(key: 'pie_chart_outlined', icon: Icons.pie_chart_outline_outlined, searchBlob: 'pie chart'),
    AppIconOption(key: 'trending_up', icon: Icons.trending_up, searchBlob: 'trending growth up'),
    AppIconOption(key: 'payments_outlined', icon: Icons.payments_outlined, searchBlob: 'payments pay money'),
    AppIconOption(key: 'credit_card', icon: Icons.credit_card, searchBlob: 'card credit debit'),
    AppIconOption(key: 'savings_outlined', icon: Icons.savings_outlined, searchBlob: 'savings bank piggy'),
    AppIconOption(key: 'receipt_long', icon: Icons.receipt_long, searchBlob: 'receipt invoice'),
    AppIconOption(key: 'group_outlined', icon: Icons.group_outlined, searchBlob: 'group people team'),
    AppIconOption(key: 'work_outlined', icon: Icons.work_outline, searchBlob: 'work briefcase job'),
    AppIconOption(key: 'school_outlined', icon: Icons.school_outlined, searchBlob: 'school education'),
    AppIconOption(key: 'fitness_center', icon: Icons.fitness_center, searchBlob: 'fitness gym health'),
    AppIconOption(key: 'restaurant', icon: Icons.restaurant, searchBlob: 'restaurant food meal'),
    AppIconOption(key: 'flight', icon: Icons.flight, searchBlob: 'flight travel plane'),
    AppIconOption(key: 'hotel', icon: Icons.hotel, searchBlob: 'hotel stay'),
    AppIconOption(key: 'local_shipping_outlined', icon: Icons.local_shipping_outlined, searchBlob: 'shipping truck delivery'),
    AppIconOption(key: 'build_outlined', icon: Icons.build_outlined, searchBlob: 'build tool wrench'),
    AppIconOption(key: 'code', icon: Icons.code, searchBlob: 'code developer'),
    AppIconOption(key: 'bug_report_outlined', icon: Icons.bug_report_outlined, searchBlob: 'bug issue'),
    AppIconOption(key: 'security', icon: Icons.security, searchBlob: 'security shield lock'),
    AppIconOption(key: 'lock_outlined', icon: Icons.lock_outline, searchBlob: 'lock privacy'),
    AppIconOption(key: 'visibility_outlined', icon: Icons.visibility_outlined, searchBlob: 'visibility eye view'),
    AppIconOption(key: 'help_outlined', icon: Icons.help_outline, searchBlob: 'help question support'),
    AppIconOption(key: 'info_outlined', icon: Icons.info_outline, searchBlob: 'info about'),
    AppIconOption(key: 'history', icon: Icons.history, searchBlob: 'history past'),
    AppIconOption(key: 'bookmark_outlined', icon: Icons.bookmark_outline, searchBlob: 'bookmark save'),
    AppIconOption(key: 'share_outlined', icon: Icons.share_outlined, searchBlob: 'share'),
    AppIconOption(key: 'link', icon: Icons.link, searchBlob: 'link url'),
    AppIconOption(key: 'camera_alt_outlined', icon: Icons.camera_alt_outlined, searchBlob: 'camera photo'),
    AppIconOption(key: 'image_outlined', icon: Icons.image_outlined, searchBlob: 'image picture'),
    AppIconOption(key: 'music_note', icon: Icons.music_note, searchBlob: 'music audio'),
    AppIconOption(key: 'play_circle_outlined', icon: Icons.play_circle_outline, searchBlob: 'play video'),
    AppIconOption(key: 'cloud_outlined', icon: Icons.cloud_outlined, searchBlob: 'cloud storage'),
    AppIconOption(key: 'wifi', icon: Icons.wifi, searchBlob: 'wifi network'),
    AppIconOption(key: 'bluetooth', icon: Icons.bluetooth, searchBlob: 'bluetooth'),
    AppIconOption(key: 'battery_charging_full', icon: Icons.battery_charging_full, searchBlob: 'battery power'),
    AppIconOption(key: 'light_mode_outlined', icon: Icons.light_mode_outlined, searchBlob: 'light sun theme'),
    AppIconOption(key: 'dark_mode_outlined', icon: Icons.dark_mode_outlined, searchBlob: 'dark moon night'),
    AppIconOption(key: 'palette_outlined', icon: Icons.palette_outlined, searchBlob: 'palette color design'),
    AppIconOption(key: 'extension', icon: Icons.extension, searchBlob: 'extension puzzle module'),
    AppIconOption(key: 'widgets_outlined', icon: Icons.widgets_outlined, searchBlob: 'widgets layout'),
    AppIconOption(key: 'table_chart_outlined', icon: Icons.table_chart_outlined, searchBlob: 'table grid data'),
    AppIconOption(key: 'summarize', icon: Icons.summarize, searchBlob: 'summary list'),
  ];
}

/// One selectable icon in the picker (key is persisted).
class AppIconOption {
  const AppIconOption({
    required this.key,
    required this.icon,
    required this.searchBlob,
  });

  final String key;
  final IconData icon;
  final String searchBlob;
}
