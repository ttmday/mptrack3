import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/player/player_controller.dart';
import 'package:mptrack3/src/widget/cover_album.dart';
import 'package:mptrack3/src/widget/main_player_buttons.dart';
import 'package:mptrack3/src/widget/track_progress.dart';

/// Full screen player: big cover, controls and what plays next.
class NowPlayingView extends StatelessWidget {
  const NowPlayingView({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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
                  const _TopBar(),
                  const SizedBox(height: 12),
                  Center(
                    child: _SwipeableCover(track: track, side: coverSide),
                  ),
                  const SizedBox(height: 16),
                  _Titles(track: track),
                  const SizedBox(height: 12),
                  const TrackProgress(compact: false),
                  const SizedBox(height: 8),
                  const _Controls(),
                  const SizedBox(height: 8),
                  const Expanded(child: _UpNext()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final theme = AppDesign.textTheme(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 28),
          onPressed: () => context.pop(),
        ),
        Expanded(
          child: Column(
            children: [
              Text('_${Strings.nowPlaying}_',
                  style: theme.bodyMedium!.copyWith(
                      color: AppColors.accent, fontWeight: FontWeight.w700)),
              ValueListenableBuilder<String>(
                valueListenable: player.queueLabel,
                builder: (context, label, _) => Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall!.copyWith(color: AppColors.foreground, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        // Keeps the title centered against the close button.
        const SizedBox(width: 48),
      ],
    );
  }
}

/// Cover that skips tracks with a horizontal swipe.
class _SwipeableCover extends StatelessWidget {
  const _SwipeableCover({required this.track, required this.side});

  final Track? track;
  final double side;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
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

class _Titles extends StatelessWidget {
  const _Titles({required this.track});
  final Track? track;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    final tree = context.select<BrowserController, FolderTree>((b) => b.tree);
    final t = track;
    final node = t == null ? null : tree.find(FolderRef(t.volume, t.folder));
    final where = t == null ? '' : (node == null ? t.folder : tree.displayPath(node));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t?.title ?? '--',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.displayLarge!.copyWith(color: AppColors.accent, fontSize: 22),
        ),
        const SizedBox(height: 6),
        Text(
          (t?.displayArtist.isNotEmpty ?? false) ? t!.displayArtist : Strings.unknown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.bodyLarge,
        ),
        const SizedBox(height: 2),
        Text(
          where,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.bodySmall!.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShuffleButtonAction(minWidth: 44),
        PrevButtonAction(minWidth: 60),
        PlayButtonAction(minWidth: 84),
        NextButtonAction(minWidth: 60),
        RepeatButtonAction(minWidth: 44),
      ],
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final theme = AppDesign.textTheme(context);
    return ValueListenableBuilder<int>(
      valueListenable: player.queueVersion,
      builder: (context, _, __) {
        final upcoming = player.upcoming(limit: 30);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${Strings.upNext} (${upcoming.length})',
                style: theme.bodySmall!.copyWith(color: AppColors.foreground)),
            const Divider(color: AppColors.border, height: 12),
            Expanded(
              child: upcoming.isEmpty
                  ? Center(
                      child: Text(Strings.queueEmpty,
                          style: theme.bodySmall!.copyWith(color: AppColors.foreground)))
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: upcoming.length,
                      itemBuilder: (context, index) {
                        final track = upcoming[index];
                        return InkWell(
                          onTap: () {
                            final queueIndex =
                                player.queue.indexWhere((t) => t.id == track.id);
                            if (queueIndex >= 0) player.playQueueIndex(queueIndex);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text('${index + 1}',
                                      style: theme.bodySmall!
                                          .copyWith(color: AppColors.foreground)),
                                ),
                                Expanded(
                                  child: Text(track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.bodyMedium!
                                          .copyWith(color: AppColors.accent)),
                                ),
                                Text(
                                  track.duration == Duration.zero
                                      ? ''
                                      : track.duration.formatStr,
                                  style: theme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
