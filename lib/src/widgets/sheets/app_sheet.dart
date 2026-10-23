import 'package:flutter/material.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

/// Bottom sheet that always fits the screen width and stays above the
/// system bars.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  final width = MediaQuery.sizeOf(context).width;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesign.padding)),
    ),
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

/// A header followed by actions that scroll when they do not fit.
Widget actionSheet(Widget header, List<Widget> actions) {
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
