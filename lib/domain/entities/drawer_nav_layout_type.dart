enum DrawerNavLayoutType {
  classicList,
  softCard,
  pillGradient;

  static DrawerNavLayoutType fromStorage(String? value) {
    switch (value) {
      case 'classicList':
        return DrawerNavLayoutType.classicList;
      case 'pillGradient':
        return DrawerNavLayoutType.pillGradient;
      default:
        return DrawerNavLayoutType.softCard;
    }
  }

  String get storageValue => switch (this) {
    DrawerNavLayoutType.classicList => 'classicList',
    DrawerNavLayoutType.softCard => 'softCard',
    DrawerNavLayoutType.pillGradient => 'pillGradient',
  };
}
