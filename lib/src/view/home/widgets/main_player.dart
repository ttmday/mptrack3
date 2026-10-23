import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/routes/now_playing.dart';
import 'package:mptrack3/src/widgets/cover_album.dart';
import 'package:mptrack3/src/widgets/track_progress.dart';

/// Compact player header on the home screen. Tapping it (or swiping it
/// up) opens the Now Playing screen.
class MainPlayer extends StatelessWidget {
  const MainPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return ValueListenableBuilder<Track?>(
      valueListenable: player.currentTrack,
      builder: (context, track, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: track == null ? null : () => context.pushNamed(NowPlayingRoute.name),
          onVerticalDragEnd: (details) {
            if (track != null && (details.primaryVelocity ?? 0) < -200) {
              context.pushNamed(NowPlayingRoute.name);
            }
          },
          child: SizedBox(
            height: 138.0,
            child: Row(
              children: [
                Hero(
                  tag: 'cover',
                  child: Container(
                    width: 100,
                    height: 120.0,
                    padding: const EdgeInsets.all(AppDesign.padding * .5),
                    decoration: const BoxDecoration(
                      border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
                    ),
                    child: CoverAlbum(track: track),
                  ),
                ),
                const SizedBox(width: AppDesign.padding),
                Expanded(child: _TrackInfo(track: track)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    final heading = track == null
        ? 'mptrack3'
        : (track!.folderName.isNotEmpty ? track!.folderName : (track!.album ?? ''));
    return Padding(
      padding: const EdgeInsets.only(right: AppDesign.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.displayLarge!.copyWith(color: AppColors.accent, fontSize: 20.0),
          ),
          const SizedBox(height: AppDesign.padding),
          Text(
            track?.title ?? '--',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall,
          ),
          const SizedBox(height: AppDesign.padding * .6),
          Text(
            (track?.displayArtist.isNotEmpty ?? false)
                ? track!.displayArtist
                : (track == null ? '' : Strings.unknown),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall!.copyWith(fontSize: 10.0),
          ),
          const Spacer(),
          const TrackProgress(),
          const SizedBox(height: AppDesign.padding * .5),
        ],
      ),
    );
  }
}
