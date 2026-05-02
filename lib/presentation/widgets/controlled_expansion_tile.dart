import 'package:flutter/material.dart';

/// [ExpansionTile] whose expanded state is driven by [expanded] so parents can
/// enforce a single open tile (accordion) while keeping Material expand/collapse animation.
class ControlledExpansionTile extends StatefulWidget {
  const ControlledExpansionTile({
    super.key,
    required this.expanded,
    required this.onExpansionChanged,
    required this.title,
    this.leading,
    this.trailing,
    this.childrenPadding,
    required this.children,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry? childrenPadding;
  final List<Widget> children;

  @override
  State<ControlledExpansionTile> createState() =>
      _ControlledExpansionTileState();
}

class _ControlledExpansionTileState extends State<ControlledExpansionTile> {
  final ExpansionTileController _controller = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    if (widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _controller.expand();
      });
    }
  }

  @override
  void didUpdateWidget(ControlledExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller.expand();
      } else {
        _controller.collapse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      controller: _controller,
      title: widget.title,
      leading: widget.leading,
      trailing: widget.trailing,
      childrenPadding:
          widget.childrenPadding ?? const EdgeInsets.fromLTRB(12, 0, 12, 12),
      onExpansionChanged: widget.onExpansionChanged,
      children: widget.children,
    );
  }
}
