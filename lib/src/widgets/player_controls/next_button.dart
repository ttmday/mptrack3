import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/widgets/design_system/button_action.dart';

class NextButtonAction extends StatelessWidget {
  const NextButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return ValueListenableBuilder<bool>(
      valueListenable: player.hasNext,
      builder: (context, enabled, _) => ButtonAction(
        minWidth: minWidth,
        icon: Icons.keyboard_double_arrow_right,
        isPressed: !enabled,
        onPressed: player.next,
      ),
    );
  }
}
