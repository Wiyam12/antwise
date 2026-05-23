import 'dart:ui';

import 'package:antwise/core/services/ai/ai_workspace_mention.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chat composer with `@` workspace mentions (pages, tables, widgets).
class AiChatMentionInput extends StatefulWidget {
  const AiChatMentionInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Message',
    this.minLines = 1,
    this.maxLines = 5,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<AiChatMentionInput> createState() => _AiChatMentionInputState();
}

class _AiChatMentionInputState extends State<AiChatMentionInput> {
  static const double _kTileHeight = 44;
  static const double _kHeaderHeight = 36;
  static const double _kMaxListHeight = 220;
  static const int _kVisibleItemCap = 5;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _anchorKey = GlobalKey();
  final ScrollController _suggestionScrollController = ScrollController();

  OverlayEntry? _overlayEntry;
  AiWorkspaceMentionCatalog _catalog = AiWorkspaceMentionCatalog.load();
  List<AiWorkspaceMention> _suggestions = <AiWorkspaceMention>[];
  int _selectedIndex = 0;
  int? _mentionStart;
  String _mentionQuery = '';
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _suggestionScrollController.dispose();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    _updateMentionState();
  }

  void _updateMentionState() {
    final String text = widget.controller.text;
    final int cursor = widget.controller.selection.baseOffset;
    final int safeCursor = cursor < 0 ? text.length : cursor;
    final int? at = _findActiveAtSign(text, safeCursor);
    if (at == null) {
      _hideOverlay();
      return;
    }
    final String query = text.substring(at + 1, safeCursor);
    if (query.contains('\n') || query.contains(' ')) {
      _hideOverlay();
      return;
    }
    _mentionStart = at;
    _mentionQuery = query;
    _catalog = AiWorkspaceMentionCatalog.load();
    _suggestions = _catalog.search(query);
    _selectedIndex = 0;
    if (_suggestions.isEmpty) {
      _hideOverlay();
      return;
    }
    _showOverlay = true;
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollSelectedIntoView());
  }

  int? _findActiveAtSign(String text, int cursor) {
    if (text.isEmpty) {
      return null;
    }
    final int searchFrom = cursor <= 0 ? 0 : cursor - 1;
    for (int i = searchFrom; i >= 0; i--) {
      final String ch = text[i];
      if (ch == '@') {
        if (i == 0) {
          return 0;
        }
        final String prev = text[i - 1];
        if (prev == ' ' || prev == '\n') {
          return i;
        }
        return null;
      }
      if (ch == ' ' || ch == '\n') {
        return null;
      }
    }
    return null;
  }

  void _hideOverlay() {
    _showOverlay = false;
    _mentionStart = null;
    _mentionQuery = '';
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectMention(AiWorkspaceMention mention) {
    final int? start = _mentionStart;
    if (start == null) {
      return;
    }
    final String text = widget.controller.text;
    final int cursor = widget.controller.selection.baseOffset;
    final int end = cursor < 0 ? text.length : cursor;
    final String insert = '${mention.insertText} ';
    final String next =
        '${text.substring(0, start)}$insert${text.substring(end)}';
    final int newCursor = start + insert.length;
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _hideOverlay();
    widget.focusNode.requestFocus();
  }

  void _scrollSelectedIntoView() {
    if (!_suggestionScrollController.hasClients || _suggestions.isEmpty) {
      return;
    }
    final double target = _selectedIndex * _kTileHeight;
    final double max = _suggestionScrollController.position.maxScrollExtent;
    _suggestionScrollController.animateTo(
      target.clamp(0, max),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  double _overlayWidth(BuildContext context) {
    final RenderBox? box =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.size.width;
    }
    return MediaQuery.sizeOf(context).width - 68;
  }

  double _listHeight() {
    final int visible = _suggestions.length.clamp(1, _kVisibleItemCap);
    final double content = visible * _kTileHeight;
    return content > _kMaxListHeight ? _kMaxListHeight : content;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_showOverlay || _suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
      _overlayEntry?.markNeedsBuild();
      _scrollSelectedIntoView();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectedIndex =
          (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
      _overlayEntry?.markNeedsBuild();
      _scrollSelectedIntoView();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _selectMention(_suggestions[_selectedIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _hideOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (BuildContext context) {
        if (!_showOverlay || _suggestions.isEmpty) {
          return const SizedBox.shrink();
        }
        final ThemeData theme = Theme.of(context);
        final ColorScheme scheme = theme.colorScheme;
        final double width = _overlayWidth(context);
        final double listHeight = _listHeight();
        final String headerQuery = _mentionQuery.trim();

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideOverlay,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(0, -6),
              child: SizedBox(
                width: width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Material(
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
                      surfaceTintColor: scheme.surfaceTint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(
                            height: _kHeaderHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.alternate_email_rounded,
                                    size: 16,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      headerQuery.isEmpty
                                          ? 'Reference workspace'
                                          : 'Matching "$headerQuery"',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${_suggestions.length}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                          SizedBox(
                            height: listHeight,
                            child: Scrollbar(
                              thumbVisibility: _suggestions.length > _kVisibleItemCap,
                              controller: _suggestionScrollController,
                              radius: const Radius.circular(4),
                              child: ListView.builder(
                                controller: _suggestionScrollController,
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                itemExtent: _kTileHeight,
                                itemBuilder: (BuildContext context, int index) {
                                  final AiWorkspaceMention m =
                                      _suggestions[index];
                                  return _MentionSuggestionTile(
                                    mention: m,
                                    query: _mentionQuery,
                                    selected: index == _selectedIndex,
                                    onTap: () => _selectMention(m),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        onKeyEvent: _handleKey,
        child: TextField(
          key: _anchorKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (String value) {
            if (_showOverlay && _suggestions.isNotEmpty) {
              _selectMention(_suggestions[_selectedIndex]);
              return;
            }
            widget.onSubmitted?.call(value);
          },
        ),
      ),
    );
  }
}

class _MentionSuggestionTile extends StatelessWidget {
  const _MentionSuggestionTile({
    required this.mention,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final AiWorkspaceMention mention;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color bg = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(mention.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _HighlightedLabel(
                      label: mention.displayLabel,
                      query: query,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                    ),
                    if (mention.subtitle.isNotEmpty)
                      Text(
                        mention.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.1,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _KindChip(label: mention.categoryLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _HighlightedLabel extends StatelessWidget {
  const _HighlightedLabel({
    required this.label,
    required this.query,
    this.style,
    this.maxLines = 1,
  });

  final String label;
  final String query;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return Text(
        label,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    final String lower = label.toLowerCase();
    final int idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(
        label,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: <TextSpan>[
          TextSpan(text: label.substring(0, idx)),
          TextSpan(
            text: label.substring(idx, idx + q.length),
            style: style?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          TextSpan(text: label.substring(idx + q.length)),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
