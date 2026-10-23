import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/service/library/models/index.dart';

class TrackTitles extends StatelessWidget {
  const TrackTitles({super.key, required this.track});
  final Track? track;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    final tree = context.select<BrowserProvider, FolderTree>((b) => b.tree);
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
