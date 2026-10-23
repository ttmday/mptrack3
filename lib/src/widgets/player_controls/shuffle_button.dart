import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/widgets/design_system/button_action.dart';

class ShuffleButtonAction extends StatelessWidget {
  const ShuffleButtonAction({
    super.key,
    this.minWidth = 38.0,
    this.shuffleVisibleList = false,
  });
  final double minWidth;

  /// On the home screen, turning shuffle on plays the list being viewed
  /// (folder or search results) in a fresh random order.
  final bool shuffleVisibleList;

  void _toggle(BuildContext context, PlayerProvider player) {
    if (!shuffleVisibleList) {
      player.toggleShuffle();
      return;
    }
    final browser = context.read<BrowserProvider>();
    if (browser.searching) {
      player.toggleShuffleFor(browser.results, label: 'find: ${browser.query.trim()}');
      return;
    }
    final folder = browser.cwd;
    final direct = browser.tracksOf(folder);
    final recursive = direct.isEmpty;
    player.toggleShuffleFor(
      recursive ? browser.playlistOf(folder) : direct,
      label: browser.cwdLabel,
      context: folder.ref,
      recursive: recursive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return ValueListenableBuilder<bool>(
      valueListenable: player.shuffle,
      builder: (context, isShuffle, _) => ButtonAction(
        minWidth: minWidth,
        icon: Icons.shuffle,
        color: isShuffle ? AppColors.accent : null,
        iconColor: isShuffle ? AppColors.secondary : null,
        onPressed: () => _toggle(context, player),
      ),
    );
  }
}
