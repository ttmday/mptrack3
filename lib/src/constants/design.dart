import 'package:flutter/material.dart';

import 'package:mptrack3/src/constants/color.dart';

class AppDesign {
  const AppDesign._();

  static const double padding = 8.0;
  static const double radius = 24.0;

  /// Fixed row heights let lists compute where a row is to scroll to it.
  static const double tileExtent = 44.0;
  static const double tileExtentWithSubtitle = 56.0;

  static TextTheme textTheme(BuildContext context) =>
      Theme.of(context).textTheme;

  static TextStyle sheetText(
    BuildContext context, {
    Color color = AppColors.text,
    double size = 15,
  }) =>
      textTheme(context).bodyMedium!.copyWith(color: color, fontSize: size);
}
