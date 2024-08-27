import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:audio_service/audio_service.dart';
import 'package:mptrack3/src/service/audio_manager.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

import 'package:mptrack3/src/widget/ButtonAction.dart';

class MainPlayerButtons extends StatelessWidget {
  const MainPlayerButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        PrevButtonAction(),
        SizedBox(
          width: AppDesign.padding * .8,
        ),
        NextButtonAction(),
        SizedBox(
          width: AppDesign.padding * .8,
        ),
        PlayButtonAction(),
        SizedBox(
          width: AppDesign.padding * .8,
        ),
        StopButtonAction(),
        Spacer(),
        ShuffleButtonAction(),
        SizedBox(
          width: AppDesign.padding * .8,
        ),
        RepeatButtonAction()
      ],
    );
  }
}

class PrevButtonAction extends StatelessWidget {
  const PrevButtonAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.isFirstSongNotifier,
          builder: (context, isFirst, _) {
            return ButtonAction(
              icon: Icons.keyboard_double_arrow_left,
              isPressed: isFirst,
              onPressed: () {
                provider.seek(Duration.zero);
              },
              onDoublePressed: () {
                provider.previous();
              },
            );
          });
    });
  }
}

class NextButtonAction extends StatelessWidget {
  const NextButtonAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.isLastSongNotifier,
          builder: (context, isLast, _) {
            return ButtonAction(
                icon: Icons.keyboard_double_arrow_right,
                isPressed: isLast,
                onPressed: () {
                  provider.next();
                });
          });
    });
  }
}

class PlayButtonAction extends StatelessWidget {
  const PlayButtonAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.playButtonNotifier,
          builder: (context, playing, _) {
            return ButtonAction(
                icon: playing == ButtonState.playing
                    ? Icons.pause
                    : Icons.play_arrow,
                color: playing == ButtonState.playing ? AppColors.accent : null,
                iconColor:
                    playing == ButtonState.playing ? AppColors.tertiary : null,
                onPressed: () {
                  provider.playPause();
                });
          });
    });
  }
}

class StopButtonAction extends StatelessWidget {
  const StopButtonAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.playbackStatNotifier,
          builder: (context, state, _) {
            return ButtonAction(
                icon: Icons.stop,
                isPressed: state == AudioProcessingState.idle,
                onPressed: () {
                  provider.stop();
                });
          });
    });
  }
}

class ShuffleButtonAction extends StatelessWidget {
  const ShuffleButtonAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.isShuffleModeEnabledNotifier,
          builder: (context, isShuffle, _) {
            return ButtonAction(
                minWidth: 38.0,
                icon: Icons.shuffle,
                color: isShuffle ? AppColors.accent : null,
                iconColor: isShuffle ? AppColors.secondary : null,
                onPressed: () {
                  if (isShuffle) {
                    provider.setShuffleMode(AudioServiceShuffleMode.none);
                  } else {
                    provider.setShuffleMode(AudioServiceShuffleMode.all);
                  }
                });
          });
    });
  }
}

class RepeatButtonAction extends StatelessWidget {
  const RepeatButtonAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.repeatButtonNotifier,
          builder: (context, repeatState, _) {
            return ButtonAction(
                minWidth: 38.0,
                icon: repeatState == RepeatState.repeatSong
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: repeatState != RepeatState.off ? AppColors.accent : null,
                iconColor:
                    repeatState != RepeatState.off ? AppColors.secondary : null,
                onPressed: () {
                  switch (repeatState) {
                    case RepeatState.off:
                      provider.setRepeatMode(AudioServiceRepeatMode.one);
                    case RepeatState.repeatSong:
                      provider.setRepeatMode(AudioServiceRepeatMode.all);
                    case _:
                      provider.setRepeatMode(AudioServiceRepeatMode.none);
                  }
                });
          });
    });
  }
}
