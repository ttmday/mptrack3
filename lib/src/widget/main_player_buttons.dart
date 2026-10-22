import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/player/play_order.dart';
import 'package:mptrack3/src/player/player_controller.dart';
import 'package:mptrack3/src/widget/button_action.dart';

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

class PrevButtonAction extends StatelessWidget {
  const PrevButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return ValueListenableBuilder<bool>(
      valueListenable: player.hasPrevious,
      builder: (context, enabled, _) => ButtonAction(
        minWidth: minWidth,
        icon: Icons.keyboard_double_arrow_left,
        isPressed: !enabled,
        onPressed: player.previous,
      ),
    );
  }
}

class NextButtonAction extends StatelessWidget {
  const NextButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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

class PlayButtonAction extends StatelessWidget {
  const PlayButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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

class StopButtonAction extends StatelessWidget {
  const StopButtonAction({super.key, this.minWidth = 54.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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

  void _toggle(BuildContext context, PlayerController player) {
    if (!shuffleVisibleList) {
      player.toggleShuffle();
      return;
    }
    final browser = context.read<BrowserController>();
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
    final player = context.read<PlayerController>();
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

class RepeatButtonAction extends StatelessWidget {
  const RepeatButtonAction({super.key, this.minWidth = 38.0});
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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
