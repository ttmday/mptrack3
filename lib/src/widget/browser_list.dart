import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:provider/provider.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/library/library_repository.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/player/player_controller.dart';
import 'package:mptrack3/src/widget/jersey_message.dart';
import 'package:mptrack3/src/widget/sheets.dart';
import 'package:mptrack3/src/widget/track_tile.dart';

/// The folder browser (or search results while typing).
class BrowserList extends StatelessWidget {
  const BrowserList({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryRepository>();
    switch (library.status) {
      case LibraryStatus.loading:
        return const Center(child: JerseyMessage(message: Strings.loading));
      case LibraryStatus.noPermission:
      case LibraryStatus.permanentlyDenied:
        return _PermissionPrompt(permanent: library.status == LibraryStatus.permanentlyDenied);
      case LibraryStatus.error:
        return _ErrorPrompt(message: library.error ?? '');
      case LibraryStatus.ready:
        break;
    }
    final browser = context.watch<BrowserController>();
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.background,
      onRefresh: library.reload,
      child: browser.searching ? const _SearchResults() : const _FolderView(),
    );
  }
}

class _FolderView extends StatelessWidget {
  const _FolderView();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    // Rebuild when the play order changes so a shuffled queue is shown in
    // the order it will play.
    return ListenableBuilder(
      listenable: Listenable.merge([player.queueVersion, player.shuffle]),
      builder: (context, _) => _buildList(context, player),
    );
  }

  Widget _buildList(BuildContext context, PlayerController player) {
    final browser = context.watch<BrowserController>();
    final folder = browser.cwd;
    final baseTracks = browser.tracksOf(folder);
    final tracks = player.displayOrder(baseTracks);
    final children = folder.children;
    final label = browser.cwdLabel;

    void playTrack(Track track) {
      player.playFrom(baseTracks, track, label: label, context: folder.ref);
    }

    final itemCount = (browser.canGoUp ? 1 : 0) + children.length + tracks.length;
    if (itemCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 24),
          Center(child: JerseyMessage(message: Strings.empty)),
          Center(child: Text(Strings.emptyHint, textAlign: TextAlign.center)),
        ],
      );
    }

    return ListView.builder(
      key: PageStorageKey(label),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        var i = index;
        if (browser.canGoUp) {
          if (i == 0) {
            return FolderTile(
              name: '..',
              count: 0,
              isParent: true,
              onTap: browser.up,
            );
          }
          i--;
        }
        if (i < children.length) {
          final child = children[i];
          return FolderTile(
            name: child.name,
            count: child.totalTracks,
            onTap: () => browser.enter(child),
            onLongPress: () => showFolderActions(context, child),
          );
        }
        final track = tracks[i - children.length];
        return TrackTile(
          track: track,
          onTap: () => playTrack(track),
          onLongPress: () =>
              showTrackActions(context, track, onPlay: () => playTrack(track)),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return ListenableBuilder(
      listenable: Listenable.merge([player.queueVersion, player.shuffle]),
      builder: (context, _) => _buildList(context, player),
    );
  }

  Widget _buildList(BuildContext context, PlayerController player) {
    final browser = context.watch<BrowserController>();
    final matches = browser.results;
    final results = player.displayOrder(matches);
    final folders = browser.folderResults();
    final theme = AppDesign.textTheme(context);
    final label = 'find: ${browser.query.trim()}';

    if (results.isEmpty && folders.isEmpty) {
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

    final header = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.padding / 2, vertical: AppDesign.padding / 2),
      child: Text(
        '${results.length} ${Strings.resultsFor}'
        '${folders.isEmpty ? '' : ' · ${folders.length} ${Strings.folders}'}',
        style: theme.bodySmall!.copyWith(color: AppColors.foreground),
      ),
    );

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 1 + folders.length + results.length,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final i = index - 1;
        if (i < folders.length) {
          final folder = folders[i];
          return FolderTile(
            name: folder.name,
            count: folder.totalTracks,
            subtitle: browser.tree.displayPath(folder),
            onTap: () {
              browser.clearQuery();
              browser.enter(folder);
              FocusScope.of(context).unfocus();
            },
            onLongPress: () => showFolderActions(context, folder),
          );
        }
        final track = results[i - folders.length];
        // Always start a fresh order from the tapped song: in shuffle mode
        // it plays first and the other matches follow in random order.
        void play() =>
            player.playFrom(matches, track, label: label, restart: true);
        return TrackTile(
          track: track,
          subtitle: _folderLabel(browser.tree, track),
          onTap: play,
          onLongPress: () => showTrackActions(context, track, onPlay: play),
        );
      },
    );
  }

  static String _folderLabel(FolderTree tree, Track track) {
    final node = tree.find(FolderRef(track.volume, track.folder));
    final artist = track.displayArtist;
    final where = node == null ? track.folder : tree.displayPath(node);
    return artist.isEmpty ? where : '$artist · $where';
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.permanent});
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Strings.permissionTitle,
                style: theme.headlineSmall!.copyWith(color: AppColors.accent)),
            const SizedBox(height: 8),
            const Text(Strings.permissionBody, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: AppColors.secondary),
              onPressed: () {
                if (permanent) {
                  openAppSettings();
                } else {
                  context.read<LibraryRepository>().retryPermission();
                }
              },
              child: Text(permanent ? Strings.permissionSettings : Strings.permissionGrant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPrompt extends StatelessWidget {
  const _ErrorPrompt({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const JerseyMessage(),
          const Text(Strings.loadError),
          Text(message,
              maxLines: 3,
              style: const TextStyle(color: AppColors.foreground, fontSize: 11)),
          TextButton(
            onPressed: context.read<LibraryRepository>().reload,
            child: const Text(Strings.retry, style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
