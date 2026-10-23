import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/constants/extensions.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

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
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final theme = AppDesign.textTheme(context);
    final titleStyle = theme.bodyMedium!.copyWith(fontSize: 15.0, color: AppColors.accent);
    return ValueListenableBuilder<Track?>(
      valueListenable: player.currentTrack,
      builder: (context, current, _) {
        final isCurrent = current?.id == track.id;
        return SizedBox(
          height: subtitle == null
              ? AppDesign.tileExtent
              : AppDesign.tileExtentWithSubtitle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDesign.padding * .3),
            child: Material(
              color: isCurrent
                  ? AppColors.accent.withValues(alpha: .25)
                  : Colors.transparent,
              child: InkWell(
                onTap: isCurrent ? player.togglePlay : onTap,
                onLongPress: onLongPress,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDesign.padding / 2),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle),
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
          ),
        );
      },
    );
  }
}
