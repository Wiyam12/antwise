enum DrawerNavLayoutType {
  classicList,
  softCard,
  pillGradient,
  themeBackground;

  static DrawerNavLayoutType fromStorage(String? value) {
    switch (value) {
      case 'classicList':
        return DrawerNavLayoutType.classicList;
      case 'pillGradient':
        return DrawerNavLayoutType.pillGradient;
      case 'themeBackground':
        return DrawerNavLayoutType.themeBackground;
      default:
        return DrawerNavLayoutType.softCard;
    }
  }

  String get storageValue => switch (this) {
    DrawerNavLayoutType.classicList => 'classicList',
    DrawerNavLayoutType.softCard => 'softCard',
    DrawerNavLayoutType.pillGradient => 'pillGradient',
    DrawerNavLayoutType.themeBackground => 'themeBackground',
  };
}
