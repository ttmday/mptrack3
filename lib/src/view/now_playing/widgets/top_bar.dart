import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/player.dart';

class NowPlayingTopBar extends StatelessWidget {
  const NowPlayingTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
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
