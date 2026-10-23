import 'package:flutter/material.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.accent),
      title: Text(label, style: AppDesign.sheetText(context, color: color ?? AppColors.text)),
      onTap: onTap,
    );
  }
}
