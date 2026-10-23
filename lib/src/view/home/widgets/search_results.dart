import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/widgets/play_order_list.dart';
import 'package:mptrack3/src/widgets/folder_tile.dart';
import 'package:mptrack3/src/widgets/sheets/folder_actions.dart';
import 'package:mptrack3/src/widgets/sheets/track_actions.dart';
import 'package:mptrack3/src/widgets/track_tile.dart';

/// Folders and songs matching the prompt text.
class SearchResults extends StatelessWidget {
  const SearchResults({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final browser = context.watch<BrowserProvider>();
    final matches = browser.results;
    final folders = browser.folderResults();
    final theme = AppDesign.textTheme(context);
    final label = 'find: ${browser.query.trim()}';

    if (matches.isEmpty && folders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Text(Strings.noResults,
                style: theme.headlineSmall!.copyWith(color: AppColors.foreground)),
          ),
        ],
      );
    }

    // A fresh order always starts at the tapped song, so in shuffle mode it
    // plays first and the other matches follow in random order.
    void play(Track track) =>
        player.playFrom(matches, track, label: label, restart: true);

    final leading = [
      for (final folder in folders)
        FolderTile(
          name: folder.name,
          count: folder.totalTracks,
          subtitle: browser.tree.displayPath(folder),
          onTap: () {
            browser.clearQuery();
            browser.enter(folder);
            FocusScope.of(context).unfocus();
          },
          onLongPress: () => showFolderActions(context, folder),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.padding / 2, vertical: AppDesign.padding / 2),
          child: Text(
            '${matches.length} ${Strings.resultsFor}'
            '${folders.isEmpty ? '' : ' · ${folders.length} ${Strings.folders}'}',
            style: theme.bodySmall!.copyWith(color: AppColors.foreground),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge(
                [player.queueVersion, player.shuffle, player.currentTrack]),
            builder: (context, _) => PlayOrderList(
              key: ValueKey(label),
              itemExtent: AppDesign.tileExtentWithSubtitle,
              leading: leading,
              tracks: player.displayOrder(matches),
              trackBuilder: (context, track) => TrackTile(
                track: track,
                subtitle: _subtitle(browser.tree, track),
                onTap: () => play(track),
                onLongPress: () =>
                    showTrackActions(context, track, onPlay: () => play(track)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _subtitle(FolderTree tree, Track track) {
    final node = tree.find(FolderRef(track.volume, track.folder));
    final where = node == null ? track.folder : tree.displayPath(node);
    final artist = track.displayArtist;
    return artist.isEmpty ? where : '$artist · $where';
  }
}
