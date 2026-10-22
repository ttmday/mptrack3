import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/help_content.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/library/library_repository.dart';
import 'package:mptrack3/src/model/folder_tree.dart';
import 'package:mptrack3/src/model/track.dart';
import 'package:mptrack3/src/terminal/terminal_controller.dart';
import 'package:mptrack3/src/widget/track_tile.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesign.padding)),
);

/// Bottom sheet that always fits the screen width and stays above the
/// system bars. Content is laid out full width (left aligned).
Future<T?> _showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  final width = MediaQuery.sizeOf(context).width;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: AppColors.background,
    shape: _sheetShape,
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(minWidth: width, maxWidth: width),
    builder: (sheetContext) {
      Widget content = DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(top: false, child: builder(sheetContext)),
      );
      if (heightFactor != null) {
        content = FractionallySizedBox(heightFactor: heightFactor, child: content);
      }
      return SizedBox(width: width, child: content);
    },
  );
}

/// Column of sheet actions under a header; scrolls if it does not fit.
Widget _actionSheet(BuildContext context, Widget header, List<Widget> actions) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

TextStyle _mono(BuildContext context, {Color color = AppColors.text, double size = 15}) =>
    AppDesign.textTheme(context).bodyMedium!.copyWith(color: color, fontSize: size);

Future<bool> showConfirmDialog(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.accent),
        borderRadius: BorderRadius.all(Radius.circular(AppDesign.padding)),
      ),
      title: Text('mptrack3:~\$ rm', style: _mono(context, color: AppColors.accent)),
      content: Text(message, style: _mono(context)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(Strings.cancel, style: _mono(context, color: AppColors.foreground)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(Strings.delete, style: _mono(context, color: AppColors.destructive)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showTextInputDialog(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.accent),
        borderRadius: BorderRadius.all(Radius.circular(AppDesign.padding)),
      ),
      title: Text('mptrack3:~\$ mkdir', style: _mono(context, color: AppColors.accent)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: _mono(context),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: title,
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent)),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(Strings.cancel, style: _mono(context, color: AppColors.foreground)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(Strings.create, style: _mono(context, color: AppColors.accent)),
        ),
      ],
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.accent),
      title: Text(label, style: _mono(context, color: color ?? AppColors.text)),
      onTap: onTap,
    );
  }
}

Widget _sheetHeader(BuildContext context, String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _mono(context, color: AppColors.accent, size: 16)),
        const SizedBox(height: 4),
        Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mono(context, color: AppColors.foreground, size: 12)),
      ],
    ),
  );
}

/// Long-press menu for a song.
Future<void> showTrackActions(
  BuildContext context,
  Track track, {
  required VoidCallback onPlay,
}) {
  final terminal = context.read<TerminalController>();
  final tree = context.read<BrowserController>().tree;
  final node = tree.find(FolderRef(track.volume, track.folder));
  final location = node == null ? track.folder : tree.displayPath(node);
  return _showAppSheet<void>(
    context,
    builder: (sheetContext) => _actionSheet(
      sheetContext,
      _sheetHeader(sheetContext, track.title, '${Strings.location}: $location'),
      [
        _SheetAction(Icons.play_arrow, Strings.play, () {
          Navigator.pop(sheetContext);
          onPlay();
        }),
        _SheetAction(Icons.drive_file_move_outline, Strings.moveTo, () async {
          Navigator.pop(sheetContext);
          if (!context.mounted) return;
          final target = await showFolderPicker(context, track);
          if (target != null) await terminal.moveTracks([track], target);
        }),
        _SheetAction(Icons.delete_outline, Strings.delete, () async {
          Navigator.pop(sheetContext);
          await terminal.deleteTracks([track]);
        }, color: AppColors.destructive),
      ],
    ),
  );
}

/// Asks for a name and creates a folder inside [parent].
Future<void> promptNewFolder(BuildContext context, FolderNode parent) async {
  final terminal = context.read<TerminalController>();
  final name = await showTextInputDialog(context, Strings.folderName);
  if (name == null || name.trim().isEmpty) return;
  await terminal.createFolder(parent, name);
}

/// Long-press menu for a folder.
Future<void> showFolderActions(BuildContext context, FolderNode folder) {
  final terminal = context.read<TerminalController>();
  final tree = context.read<BrowserController>().tree;
  final deletable = !folder.isVolume && !folder.isRoot;
  return _showAppSheet<void>(
    context,
    builder: (sheetContext) => _actionSheet(
      sheetContext,
      _sheetHeader(sheetContext, '${folder.name}/',
          '${tree.displayPath(folder)}  ·  ${folder.totalTracks} ${Strings.tracks}'),
      [
        if (folder.totalTracks > 0) ...[
          _SheetAction(Icons.play_arrow, Strings.play, () {
            Navigator.pop(sheetContext);
            terminal.playFolder(folder, false);
          }),
          _SheetAction(Icons.shuffle, Strings.playShuffled, () {
            Navigator.pop(sheetContext);
            terminal.playFolder(folder, true);
          }),
        ],
        if (!folder.isRoot)
          _SheetAction(Icons.create_new_folder_outlined, Strings.newFolderHere, () {
            Navigator.pop(sheetContext);
            if (context.mounted) promptNewFolder(context, folder);
          }),
        if (deletable)
          _SheetAction(Icons.visibility_off_outlined, Strings.hideFolder, () {
            Navigator.pop(sheetContext);
            terminal.hideFolder(folder);
          }),
        if (deletable)
          _SheetAction(Icons.folder_delete_outlined, Strings.deleteFolder, () {
            Navigator.pop(sheetContext);
            terminal.deleteFolder(folder);
          }, color: AppColors.destructive),
      ],
    ),
  );
}

/// Lets the user browse to a destination folder for [track].
Future<FolderNode?> showFolderPicker(BuildContext context, Track track) {
  return _showAppSheet<FolderNode>(
    context,
    heightFactor: .75,
    builder: (_) => _FolderPicker(track: track),
  );
}

/// Command reference. Tapping a command puts it in the prompt.
Future<void> showHelpSheet(BuildContext context) {
  final terminal = context.read<TerminalController>();
  final theme = AppDesign.textTheme(context);
  return _showAppSheet<void>(
    context,
    heightFactor: .85,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetHeader(sheetContext, 'mptrack3:~\$ help', Strings.helpHint),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final group in commandHelp.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(group.key.toUpperCase(),
                      style: theme.bodySmall!.copyWith(
                          color: AppColors.primary, letterSpacing: 1.2)),
                ),
                for (final item in group.value)
                  InkWell(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      terminal.suggest(item.example ?? item.usage);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.usage, style: _mono(sheetContext, color: AppColors.accent)),
                          const SizedBox(height: 2),
                          Text(item.description,
                              style: _mono(sheetContext, color: AppColors.text, size: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _FolderPicker extends StatefulWidget {
  const _FolderPicker({required this.track});
  final Track track;

  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  /// Current location as a ref so it survives tree rebuilds (mkdir).
  late FolderRef _ref;

  @override
  void initState() {
    super.initState();
    final volume = widget.track.volume;
    // Start next to Music/ when the song lives outside an allowed place.
    final library = context.read<LibraryRepository>();
    final current = FolderRef(volume, widget.track.folder);
    _ref = library.source.writeRestriction(current) == null
        ? current
        : FolderRef(volume, '');
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryRepository>();
    final terminal = context.read<TerminalController>();
    final tree = library.tree;
    final node = tree.find(_ref) ?? tree.find(FolderRef(_ref.volume, '')) ?? tree.home;
    final restriction = node.ref == null ? 'select a folder' : library.source.writeRestriction(node.ref!);
    final isCurrent = node.ref == FolderRef(widget.track.volume, widget.track.folder);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(context, Strings.moveTo, widget.track.title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('mptrack3:${tree.displayPath(node)}\$',
                style: _mono(context, color: AppColors.primary, size: 13)),
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
                  style: _mono(context, color: AppColors.destructive, size: 12)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.create_new_folder_outlined, color: AppColors.accent),
                  label: Text(Strings.newFolder, style: _mono(context, color: AppColors.accent)),
                  onPressed: () async {
                    final name = await showTextInputDialog(context, Strings.folderName);
                    if (name == null || name.trim().isEmpty || !mounted) return;
                    final created = await terminal.createFolder(node, name);
                    final ref = created?.ref;
                    if (ref != null && mounted) setState(() => _ref = ref);
                  },
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
      ),
    );
  }
}
