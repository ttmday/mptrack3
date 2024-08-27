import 'package:flutter/material.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';

import 'package:mptrack3/src/service/audio_manager.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

class SongTile extends StatelessWidget {
  const SongTile(
      {super.key,
      required this.manager,
      required this.song,
      required this.position});

  final MediaItem song;
  final int position;
  final AudioManager manager;

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
        valueListenable: provider.currentSongNotifier,
        builder: (context, currentSong, child) {
          bool isCurrentSong = currentSong?.id == song.id;
          return GestureDetector(
            onTap: () {
              if (isCurrentSong) {
                manager.playPause();
                return;
              }
              manager.skipToQueueItem(position);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppDesign.padding * .45),
              child: ColoredBox(
                  color: isCurrentSong
                      ? AppColors.accent.withOpacity(.25)
                      : Colors.transparent,
                  child: SizedBox(
                    height: 30.0,
                    child: Row(
                      children: [
                        if (isCurrentSong)
                          Row(
                            children: [
                              ValueListenableBuilder(
                                  valueListenable: provider.playButtonNotifier,
                                  builder: (context, state, _) {
                                    return Icon(state == ButtonState.playing
                                        ? Icons.pause
                                        : Icons.play_arrow);
                                  }),
                              RichText(
                                  text: TextSpan(
                                children: [
                                  const TextSpan(text: ":"),
                                  TextSpan(
                                    text: "~",
                                    style: AppDesign.textTheme(context)
                                        .bodyMedium!
                                        .copyWith(
                                            fontSize: 15.0,
                                            color: AppColors.primary),
                                  ),
                                  TextSpan(
                                    text: "\$",
                                    style: AppDesign.textTheme(context)
                                        .bodyMedium!
                                        .copyWith(
                                            fontSize: 15.0,
                                            color: AppColors.text),
                                  )
                                ],
                                style: AppDesign.textTheme(context)
                                    .bodyMedium!
                                    .copyWith(
                                        fontSize: 15.0,
                                        color: AppColors.accent),
                              )),
                            ],
                          ),
                        Expanded(child: child!),
                      ],
                    ),
                  )),
            ),
          );
        },
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppDesign.padding / 2),
          minTileHeight: 10.0,
          minVerticalPadding: 2.5,
          title: Text(
            song.title,
            maxLines: 1,
            style: AppDesign.textTheme(context).bodyMedium!.copyWith(
                fontSize: 15.0,
                color: AppColors.accent,
                overflow: TextOverflow.ellipsis),
          ),
          trailing: Text(
            song.duration?.formatStr ?? "",
            style: AppDesign.textTheme(context).bodyMedium!.copyWith(
                  color: AppColors.accent,
                ),
          ),
        ),
      );
    });
  }
}
