import 'package:flutter/material.dart';

import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/widgets/player_controls/next_button.dart';
import 'package:mptrack3/src/widgets/player_controls/play_button.dart';
import 'package:mptrack3/src/widgets/player_controls/prev_button.dart';
import 'package:mptrack3/src/widgets/player_controls/repeat_button.dart';
import 'package:mptrack3/src/widgets/player_controls/shuffle_button.dart';
import 'package:mptrack3/src/widgets/player_controls/stop_button.dart';

class MainPlayerButtons extends StatelessWidget {
  const MainPlayerButtons({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: AppDesign.padding * .8);
    return const Row(
      children: [
        PrevButtonAction(),
        gap,
        NextButtonAction(),
        gap,
        PlayButtonAction(),
        gap,
        StopButtonAction(),
        Spacer(),
        ShuffleButtonAction(shuffleVisibleList: true),
        gap,
        RepeatButtonAction(),
      ],
    );
  }
}
