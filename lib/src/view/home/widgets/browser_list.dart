import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/library.dart';
import 'package:mptrack3/src/view/home/widgets/folder_view.dart';
import 'package:mptrack3/src/view/home/widgets/search_results.dart';
import 'package:mptrack3/src/widgets/design_system/jersey_message.dart';

/// Folder browser, or search results while typing.
class BrowserList extends StatelessWidget {
  const BrowserList({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    switch (library.status) {
      case LibraryStatus.loading:
        return const Center(child: JerseyMessage(message: Strings.loading));
      case LibraryStatus.noPermission:
      case LibraryStatus.permanentlyDenied:
        return _PermissionPrompt(permanent: library.status == LibraryStatus.permanentlyDenied);
      case LibraryStatus.error:
        return _ErrorPrompt(message: library.error ?? '');
      case LibraryStatus.ready:
        break;
    }
    final browser = context.watch<BrowserProvider>();
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.background,
      onRefresh: library.reload,
      child: browser.searching ? const SearchResults() : const FolderView(),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.permanent});
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Strings.permissionTitle,
                style: theme.headlineSmall!.copyWith(color: AppColors.accent)),
            const SizedBox(height: 8),
            const Text(Strings.permissionBody, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: AppColors.secondary),
              onPressed: () {
                if (permanent) {
                  openAppSettings();
                } else {
                  context.read<LibraryProvider>().retryPermission();
                }
              },
              child: Text(permanent ? Strings.permissionSettings : Strings.permissionGrant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPrompt extends StatelessWidget {
  const _ErrorPrompt({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const JerseyMessage(),
          const Text(Strings.loadError),
          Text(message,
              maxLines: 3,
              style: const TextStyle(color: AppColors.foreground, fontSize: 11)),
          TextButton(
            onPressed: context.read<LibraryProvider>().reload,
            child: const Text(Strings.retry, style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
