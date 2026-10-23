import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/help_content.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/terminal.dart';
import 'package:mptrack3/src/widgets/sheets/app_sheet.dart';
import 'package:mptrack3/src/widgets/sheets/sheet_header.dart';

/// Command reference; tapping a command writes it in the prompt.
Future<void> showHelpSheet(BuildContext context) {
  final terminal = context.read<TerminalProvider>();
  return showAppSheet<void>(
    context,
    heightFactor: .85,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'mptrack3:~\$ help', subtitle: Strings.helpHint),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final group in commandHelp.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    group.key.toUpperCase(),
                    style: AppDesign.textTheme(sheetContext)
                        .bodySmall!
                        .copyWith(color: AppColors.primary, letterSpacing: 1.2),
                  ),
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
                          Text(item.usage,
                              style: AppDesign.sheetText(sheetContext,
                                  color: AppColors.accent)),
                          const SizedBox(height: 2),
                          Text(item.description,
                              style: AppDesign.sheetText(sheetContext, size: 13)),
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
