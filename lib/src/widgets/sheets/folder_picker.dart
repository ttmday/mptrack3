import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/library.dart';
import 'package:mptrack3/src/provider/terminal.dart';
import 'package:mptrack3/src/service/library/models/index.dart';
import 'package:mptrack3/src/widgets/folder_tile.dart';
import 'package:mptrack3/src/widgets/sheets/app_sheet.dart';
import 'package:mptrack3/src/widgets/sheets/dialogs.dart';
import 'package:mptrack3/src/widgets/sheets/sheet_header.dart';

/// Lets the user browse to a destination folder for [track].
Future<FolderNode?> showFolderPicker(BuildContext context, Track track) {
  return showAppSheet<FolderNode>(
    context,
    heightFactor: .75,
    builder: (_) => FolderPicker(track: track),
  );
}

class FolderPicker extends StatefulWidget {
  const FolderPicker({super.key, required this.track});

  final Track track;

  @override
  State<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<FolderPicker> {
  /// Kept as a ref so it survives tree rebuilds after mkdir.
  late FolderRef _ref;

  @override
  void initState() {
    super.initState();
    final volume = widget.track.volume;
    final current = FolderRef(volume, widget.track.folder);
    final allowed =
        context.read<LibraryProvider>().source.writeRestriction(current) == null;
    _ref = allowed ? current : FolderRef(volume, '');
  }

  Future<void> _createFolder(FolderNode parent) async {
    final terminal = context.read<TerminalProvider>();
    final name = await showTextInputDialog(context, Strings.folderName);
    if (name == null || name.trim().isEmpty || !mounted) return;
    final ref = (await terminal.createFolder(parent, name))?.ref;
    if (ref != null && mounted) setState(() => _ref = ref);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final tree = library.tree;
    final node = tree.find(_ref) ?? tree.find(FolderRef(_ref.volume, '')) ?? tree.home;
    final nodeRef = node.ref;
    final restriction =
        nodeRef == null ? 'select a folder' : library.source.writeRestriction(nodeRef);
    final isCurrent = nodeRef == FolderRef(widget.track.volume, widget.track.folder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: Strings.moveTo, subtitle: widget.track.title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('mptrack3:${tree.displayPath(node)}\$',
              style: AppDesign.sheetText(context, color: AppColors.primary, size: 13)),
        ),
        const Divider(color: AppColors.border),
        Expanded(
          child: ListView(
            children: [
              if (!node.isVolume && !node.isRoot && node.parent != null)
                FolderTile(
                  name: '..',
                  count: 0,
                  isParent: true,
                  onTap: () => setState(() => _ref = node.parent!.ref ?? _ref),
                ),
              for (final child in node.children)
                FolderTile(
                  name: child.name,
                  count: child.totalTracks,
                  onTap: () {
                    final ref = child.ref;
                    if (ref != null) setState(() => _ref = ref);
                  },
                ),
            ],
          ),
        ),
        if (restriction != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(restriction,
                style: AppDesign.sheetText(context, color: AppColors.destructive, size: 12)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.create_new_folder_outlined, color: AppColors.accent),
                label: Text(Strings.newFolder,
                    style: AppDesign.sheetText(context, color: AppColors.accent)),
                onPressed: () => _createFolder(node),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.secondary,
                  disabledBackgroundColor: AppColors.secondary,
                ),
                onPressed: (restriction != null || isCurrent)
                    ? null
                    : () => Navigator.pop(context, node),
                child: const Text(Strings.moveHere),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
