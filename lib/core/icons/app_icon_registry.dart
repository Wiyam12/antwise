import 'package:antwise/core/icons/flutter_material_icons_map.g.dart';
import 'package:flutter/material.dart';

/// Page / field icon keys: persisted as `Icons` static names (e.g. `home_outlined`).
/// Options include every [Icons] `IconData` from the Flutter Material set (see
/// [kFlutterMaterialIconsByName]).
///
/// **Note:** Referencing the full icon map can increase release size; Flutter’s
/// icon font subsetting may retain more glyphs. Regenerate the map with
/// `tool/generate_flutter_material_icon_map.dart` after a Flutter upgrade.
abstract final class AppIconRegistry {
  static const String defaultKey = 'article_outlined';

  static List<AppIconOption>? _optionsCache;

  static IconData iconOf(String? key) {
    if (key == null || key.isEmpty) {
      return kFlutterMaterialIconsByName[defaultKey]!;
    }
    return kFlutterMaterialIconsByName[key] ??
        kFlutterMaterialIconsByName[defaultKey]!;
  }

  static List<AppIconOption> get options {
    if (_optionsCache != null) {
      return _optionsCache!;
    }
    _optionsCache = kFlutterMaterialIconsByName.entries
        .map(
          (MapEntry<String, IconData> e) => AppIconOption(
            key: e.key,
            icon: e.value,
            searchBlob: '${e.key} ${e.key.replaceAll('_', ' ')}',
          ),
        )
        .toList(growable: false);
    return _optionsCache!;
  }

  static List<AppIconOption> filter(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return List<AppIconOption>.from(options);
    }
    return options
        .where(
          (AppIconOption o) =>
              o.key.toLowerCase().contains(q) ||
              o.searchBlob.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }
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
