import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/terminal.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/widgets/sheets/app_sheet.dart';
import 'package:mptrack3/src/widgets/sheets/folder_picker.dart';
import 'package:mptrack3/src/widgets/sheets/sheet_action.dart';
import 'package:mptrack3/src/widgets/sheets/sheet_header.dart';

/// Long-press menu for a song.
Future<void> showTrackActions(
  BuildContext context,
  Track track, {
  required VoidCallback onPlay,
}) {
  final terminal = context.read<TerminalProvider>();
  final tree = context.read<BrowserProvider>().tree;
  final node = tree.find(FolderRef(track.volume, track.folder));
  final location = node == null ? track.folder : tree.displayPath(node);
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => actionSheet(
      SheetHeader(title: track.title, subtitle: '${Strings.location}: $location'),
      [
        SheetAction(
          icon: Icons.play_arrow,
          label: Strings.play,
          onTap: () {
            Navigator.pop(sheetContext);
            onPlay();
          },
        ),
        SheetAction(
          icon: Icons.drive_file_move_outline,
          label: Strings.moveTo,
          onTap: () async {
            Navigator.pop(sheetContext);
            if (!context.mounted) return;
            final target = await showFolderPicker(context, track);
            if (target != null) await terminal.moveTracks([track], target);
          },
        ),
        SheetAction(
          icon: Icons.delete_outline,
          label: Strings.delete,
          color: AppColors.destructive,
          onTap: () {
            Navigator.pop(sheetContext);
            terminal.deleteTracks([track]);
          },
        ),
      ],
    ),
  );
}
