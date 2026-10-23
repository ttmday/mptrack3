import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/terminal.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/widgets/sheets/app_sheet.dart';
import 'package:mptrack3/src/widgets/sheets/dialogs.dart';
import 'package:mptrack3/src/widgets/sheets/sheet_action.dart';
import 'package:mptrack3/src/widgets/sheets/sheet_header.dart';

Future<void> promptNewFolder(BuildContext context, FolderNode parent) async {
  final terminal = context.read<TerminalProvider>();
  final name = await showTextInputDialog(context, Strings.folderName);
  if (name == null || name.trim().isEmpty) return;
  await terminal.createFolder(parent, name);
}

/// Long-press menu for a folder.
Future<void> showFolderActions(BuildContext context, FolderNode folder) {
  final terminal = context.read<TerminalProvider>();
  final tree = context.read<BrowserProvider>().tree;
  final deletable = !folder.isVolume && !folder.isRoot;
  return showAppSheet<void>(
    context,
    builder: (sheetContext) {
      void run(VoidCallback action) {
        Navigator.pop(sheetContext);
        action();
      }

      return actionSheet(
        SheetHeader(
          title: '${folder.name}/',
          subtitle:
              '${tree.displayPath(folder)}  ·  ${folder.totalTracks} ${Strings.tracks}',
        ),
        [
          if (folder.totalTracks > 0) ...[
            SheetAction(
              icon: Icons.play_arrow,
              label: Strings.play,
              onTap: () => run(() => terminal.playFolder(folder, false)),
            ),
            SheetAction(
              icon: Icons.shuffle,
              label: Strings.playShuffled,
              onTap: () => run(() => terminal.playFolder(folder, true)),
            ),
          ],
          if (!folder.isRoot)
            SheetAction(
              icon: Icons.create_new_folder_outlined,
              label: Strings.newFolderHere,
              onTap: () => run(() {
                if (context.mounted) promptNewFolder(context, folder);
              }),
            ),
          if (deletable)
            SheetAction(
              icon: Icons.visibility_off_outlined,
              label: Strings.hideFolder,
              onTap: () => run(() => terminal.hideFolder(folder)),
            ),
          if (deletable)
            SheetAction(
              icon: Icons.folder_delete_outlined,
              label: Strings.deleteFolder,
              color: AppColors.destructive,
              onTap: () => run(() => terminal.deleteFolder(folder)),
            ),
        ],
      );
    },
  );
}
