import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/widgets/design_system/button_action.dart';

class PlayButtonAction extends StatelessWidget {
  const PlayButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return ValueListenableBuilder<PlayState>(
      valueListenable: player.playState,
      builder: (context, state, _) {
        final playing = state == PlayState.playing;
        return ButtonAction(
          minWidth: minWidth,
          icon: state == PlayState.loading
              ? Icons.hourglass_empty
              : (playing ? Icons.pause : Icons.play_arrow),
          color: playing ? AppColors.accent : null,
          iconColor: playing ? AppColors.tertiary : null,
          onPressed: player.togglePlay,
        );
      },
    );
  }
}
