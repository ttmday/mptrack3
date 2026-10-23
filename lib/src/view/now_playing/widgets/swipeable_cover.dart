import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/widgets/cover_album.dart';

/// Cover that skips tracks with a horizontal swipe.
class SwipeableCover extends StatelessWidget {
  const SwipeableCover({super.key, required this.track, required this.side});

  final Track? track;
  final double side;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) player.next();
        if (velocity > 250) player.previous();
      },
      onDoubleTap: player.togglePlay,
      child: Hero(
        tag: 'cover',
        child: Container(
          width: side,
          height: side,
          padding: const EdgeInsets.all(AppDesign.padding * .6),
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
          ),
          child: CoverAlbum(track: track, size: 768),
        ),
      ),
    );
  }
}
