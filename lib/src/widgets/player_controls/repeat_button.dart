import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/player/play_order.dart';
import 'package:mptrack3/src/widgets/design_system/button_action.dart';

class RepeatButtonAction extends StatelessWidget {
  const RepeatButtonAction({super.key, this.minWidth = 38.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return ValueListenableBuilder<RepeatMode>(
      valueListenable: player.repeat,
      builder: (context, mode, _) => ButtonAction(
        minWidth: minWidth,
        icon: mode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
        color: mode != RepeatMode.off ? AppColors.accent : null,
        iconColor: mode != RepeatMode.off ? AppColors.secondary : null,
        onPressed: player.cycleRepeat,
      ),
    );
  }
}
