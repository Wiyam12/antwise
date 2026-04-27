/// How a new page is registered in the app shell (Create New Page flow).
enum PageCreationPlacement {
  /// Normal page; user picks bottom bar and/or drawer + optional hierarchy.
  standalone,

  /// Becomes a drawer child of an existing page; [NestedPageDisplayType] is stored on the new page.
  nestedInPage,
}
