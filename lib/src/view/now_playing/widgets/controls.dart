import 'package:flutter/material.dart';

import 'package:mptrack3/src/widgets/player_controls/next_button.dart';
import 'package:mptrack3/src/widgets/player_controls/play_button.dart';
import 'package:mptrack3/src/widgets/player_controls/prev_button.dart';
import 'package:mptrack3/src/widgets/player_controls/repeat_button.dart';
import 'package:mptrack3/src/widgets/player_controls/shuffle_button.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShuffleButtonAction(minWidth: 44),
        PrevButtonAction(minWidth: 60),
        PlayButtonAction(minWidth: 84),
        NextButtonAction(minWidth: 60),
        RepeatButtonAction(minWidth: 44),
      ],
    );
  }
}
