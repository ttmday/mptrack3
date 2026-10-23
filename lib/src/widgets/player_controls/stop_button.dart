import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/widgets/design_system/button_action.dart';

class StopButtonAction extends StatelessWidget {
  const StopButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return ValueListenableBuilder<PlayState>(
      valueListenable: player.playState,
      builder: (context, state, _) => ButtonAction(
        minWidth: minWidth,
        icon: Icons.stop,
        isPressed: state == PlayState.stopped,
        onPressed: player.stop,
      ),
    );
  }
}
