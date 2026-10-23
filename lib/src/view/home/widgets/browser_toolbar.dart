import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/library.dart';
import 'package:mptrack3/src/widgets/sheets/folder_actions.dart';
import 'package:mptrack3/src/widgets/sheets/help_sheet.dart';

/// Row above the browser: back to the main menu, current path, new folder
/// and help.
class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    if (library.status != LibraryStatus.ready) return const SizedBox.shrink();
    final browser = context.watch<BrowserProvider>();
    final atHome = identical(browser.cwd, browser.tree.home) && !browser.searching;
    final theme = AppDesign.textTheme(context);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.home_outlined,
            tooltip: Strings.home,
            enabled: !atHome,
            onTap: () {
              browser.clearQuery();
              browser.enter(browser.tree.home);
            },
          ),
          const SizedBox(width: AppDesign.padding / 2),
          Expanded(
            child: Text(
              browser.searching ? 'find: ${browser.query.trim()}' : browser.cwdLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium!.copyWith(color: AppColors.primary),
            ),
          ),
          _ToolButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: Strings.newFolder,
            enabled: !browser.searching && !browser.cwd.isRoot,
            onTap: () => promptNewFolder(context, browser.cwd),
          ),
          _ToolButton(
            icon: Icons.help_outline,
            tooltip: Strings.help,
            onTap: () => showHelpSheet(context),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, color: enabled ? AppColors.accent : AppColors.tertiary),
    );
  }
}
