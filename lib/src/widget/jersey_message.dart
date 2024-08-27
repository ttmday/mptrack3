import 'package:flutter/material.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

class JerseyMessage extends StatelessWidget {
  const JerseyMessage({super.key, this.message = 'Error!'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppDesign.textTheme(context).displayLarge!.copyWith(
          fontFamily: 'Jersey10',
          fontWeight: FontWeight.w600,
          fontSize: 72.0,
          color: AppColors.accent),
    );
  }
}
