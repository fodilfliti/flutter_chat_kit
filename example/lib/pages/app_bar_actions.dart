import 'package:flutter/material.dart';

/// App bar buttons drawn smaller than Material's 48 px, so the demo's many
/// switches fit next to the title on a phone.
class AppBarActions extends StatelessWidget {
  const AppBarActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 20,
          padding: const EdgeInsets.all(6),
          minimumSize: const Size.square(34),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(size: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
