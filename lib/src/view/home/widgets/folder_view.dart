import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/widgets/play_order_list.dart';
import 'package:mptrack3/src/widgets/design_system/jersey_message.dart';
import 'package:mptrack3/src/widgets/folder_tile.dart';
import 'package:mptrack3/src/widgets/sheets/folder_actions.dart';
import 'package:mptrack3/src/widgets/sheets/track_actions.dart';
import 'package:mptrack3/src/widgets/track_tile.dart';

/// Contents of the current folder: "..", subfolders, then its songs (in
/// play order when it is the shuffled queue).
class FolderView extends StatelessWidget {
  const FolderView({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final browser = context.watch<BrowserProvider>();
    final folder = browser.cwd;
    final baseTracks = browser.tracksOf(folder);
    final label = browser.cwdLabel;

    void play(Track track) =>
        player.playFrom(baseTracks, track, label: label, context: folder.ref);

    final leading = [
      if (browser.canGoUp)
        FolderTile(name: '..', count: 0, isParent: true, onTap: browser.up),
      for (final child in folder.children)
        FolderTile(
          name: child.name,
          count: child.totalTracks,
          onTap: () => browser.enter(child),
          onLongPress: () => showFolderActions(context, child),
        ),
    ];

    if (leading.isEmpty && baseTracks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 24),
          Center(child: JerseyMessage(message: Strings.empty)),
          Center(child: Text(Strings.emptyHint, textAlign: TextAlign.center)),
        ],
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge(
          [player.queueVersion, player.shuffle, player.currentTrack]),
      builder: (context, _) => PlayOrderList(
        key: ValueKey(label),
        itemExtent: AppDesign.tileExtent,
        leading: leading,
        tracks: player.displayOrder(baseTracks),
        trackBuilder: (context, track) => TrackTile(
          track: track,
          onTap: () => play(track),
          onLongPress: () => showTrackActions(context, track, onPlay: () => play(track)),
        ),
      ),
    );
  }
}
