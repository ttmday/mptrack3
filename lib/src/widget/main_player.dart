import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/service/audio_manager.dart';
import 'package:audio_service/audio_service.dart';

import 'package:mptrack3/src/widget/cover_album.dart';
import 'package:mptrack3/src/widget/track_progress.dart';

import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/color.dart';

class MainPlayer extends StatelessWidget {
  const MainPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioManager>(builder: (context, provider, _) {
      return ValueListenableBuilder(
          valueListenable: provider.currentSongNotifier,
          builder: (context, song, _) {
            return SizedBox(
              height: 138.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 120.0,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppDesign.padding * .5),
                    decoration: const BoxDecoration(
                        border: Border.fromBorderSide(
                            BorderSide(color: AppColors.border))),
                    child: CoverAlbum(
                      song: song,
                    ),
                  ),
                  const SizedBox(
                    width: AppDesign.padding,
                  ),
                  Expanded(child: TrackInfo(song: song))
                ],
              ),
            );
          });
    });
  }
}

class TrackInfo extends StatelessWidget {
  const TrackInfo({super.key, required this.song});

  final MediaItem? song;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: AppDesign.padding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song?.album ?? "Unknow",
            maxLines: 1,
            style: AppDesign.textTheme(context).displayLarge!.copyWith(
                color: AppColors.accent,
                fontSize: 20.0,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(
            height: AppDesign.padding,
          ),
          Text(
            song?.title ?? "Unknow",
            maxLines: 2,
            style: AppDesign.textTheme(context)
                .bodySmall!
                .copyWith(overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(
            height: AppDesign.padding + 5,
          ),
          Text(
            song?.artist ?? "Unknow",
            maxLines: 1,
            style: AppDesign.textTheme(context)
                .bodySmall!
                .copyWith(fontSize: 10.0, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(
            height: AppDesign.padding * .8,
          ),
          const Spacer(),
          const TrackProgress(),
          const SizedBox(
            height: AppDesign.padding * .5,
          ),
        ],
      ),
    );
  }
}
