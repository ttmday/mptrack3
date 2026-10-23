import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/view/now_playing/widgets/controls.dart';
import 'package:mptrack3/src/view/now_playing/widgets/swipeable_cover.dart';
import 'package:mptrack3/src/view/now_playing/widgets/top_bar.dart';
import 'package:mptrack3/src/view/now_playing/widgets/track_titles.dart';
import 'package:mptrack3/src/view/now_playing/widgets/up_next.dart';
import 'package:mptrack3/src/widgets/track_progress.dart';

/// Full screen player: big cover, controls and what plays next.
class NowPlayingView extends StatelessWidget {
  const NowPlayingView({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final insets = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final coverSide = math.max(120.0, math.min(size.width - 48, size.height * .38));

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) context.pop();
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, insets.top + 4, 16, insets.bottom + 8),
          child: ValueListenableBuilder<Track?>(
            valueListenable: player.currentTrack,
            builder: (context, track, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NowPlayingTopBar(),
                  const SizedBox(height: 12),
                  Center(
                    child: SwipeableCover(track: track, side: coverSide),
                  ),
                  const SizedBox(height: 16),
                  TrackTitles(track: track),
                  const SizedBox(height: 12),
                  const TrackProgress(compact: false),
                  const SizedBox(height: 8),
                  const NowPlayingControls(),
                  const SizedBox(height: 8),
                  const Expanded(child: UpNextList()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
