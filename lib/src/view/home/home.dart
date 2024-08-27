import 'package:flutter/material.dart';

import 'package:mptrack3/src/widget/command_line.dart';
import 'package:mptrack3/src/widget/main_player.dart';
import 'package:mptrack3/src/widget/main_player_buttons.dart';
import 'package:mptrack3/src/widget/song_list.dart';

import 'package:mptrack3/src/constants/design.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    EdgeInsets insets = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(top: insets.top + 10.0),
        child: const SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDesign.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MainPlayer(),
                SizedBox(
                  height: AppDesign.padding * .25,
                ),
                MainPlayerButtons(),
                SizedBox(
                  height: AppDesign.padding * .35,
                ),
                Expanded(child: SongList()),
                CommandLine(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
