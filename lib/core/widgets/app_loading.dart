import 'package:flutter/material.dart';

/// Shared loading indicator for full-screen or inline use.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        // Determinate so tests can `pumpAndSettle` without hanging on animation.
        value: 0.4,
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
