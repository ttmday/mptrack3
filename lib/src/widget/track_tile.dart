import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/player/player_controller.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onLongPress,
    this.subtitle,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Optional second line (e.g. the folder in search results).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final theme = AppDesign.textTheme(context);
    final titleStyle = theme.bodyMedium!.copyWith(fontSize: 15.0, color: AppColors.accent);
    return ValueListenableBuilder<Track?>(
      valueListenable: player.currentTrack,
      builder: (context, current, _) {
        final isCurrent = current?.id == track.id;
        return InkWell(
          onTap: isCurrent ? player.togglePlay : onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDesign.padding * .45),
            child: ColoredBox(
              color: isCurrent ? AppColors.accent.withValues(alpha: .25) : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesign.padding / 2, vertical: 5.0),
                child: Row(
                  children: [
                    if (isCurrent) ...[
                      ValueListenableBuilder<PlayState>(
                        valueListenable: player.playState,
                        builder: (context, state, _) => Icon(
                            state == PlayState.playing ? Icons.pause : Icons.play_arrow),
                      ),
                      Text(':~\$ ', style: titleStyle.copyWith(color: AppColors.text)),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(track.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                          if (subtitle != null)
                            Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodySmall!.copyWith(
                                    fontSize: 11.0, color: AppColors.foreground)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDesign.padding),
                    Text(
                      track.duration == Duration.zero ? '' : track.duration.formatStr,
                      style: theme.bodyMedium!.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A folder row: "▸ Rock/" with the number of songs inside.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.isParent = false,
    this.subtitle,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isParent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    final style = theme.bodyMedium!.copyWith(
        fontSize: 15.0, color: AppColors.text, fontWeight: FontWeight.w500);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.padding / 2, vertical: AppDesign.padding * .9),
        child: Row(
          children: [
            Text(isParent ? '◂ ' : '▸ ', style: style.copyWith(color: AppColors.primary)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isParent ? '..' : '$name/',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall!
                            .copyWith(fontSize: 11.0, color: AppColors.foreground)),
                ],
              ),
            ),
            if (!isParent)
              Text('$count', style: theme.bodySmall!.copyWith(color: AppColors.foreground)),
          ],
        ),
      ),
    );
  }
}
