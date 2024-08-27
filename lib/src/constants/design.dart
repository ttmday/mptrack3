import 'package:flutter/material.dart';

class AppDesign {
  const AppDesign._();

  static const double padding = 8.0;
  static const double radius = 24.0;

  static TextTheme textTheme(BuildContext context) =>
      Theme.of(context).textTheme;
}
