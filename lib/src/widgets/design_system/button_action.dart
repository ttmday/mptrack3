import 'package:flutter/material.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

class ButtonAction extends StatelessWidget {
  const ButtonAction(
      {super.key,
      required this.icon,
      required this.onPressed,
      this.onDoublePressed,
      this.onLongPress,
      this.color,
      this.iconColor,
      this.minWidth = 54.0,
      this.isPressed = false});

  final IconData icon;
  final void Function() onPressed;
  final void Function()? onDoublePressed;
  final void Function()? onLongPress;
  final double minWidth;
  final bool isPressed;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPressed ? null : onPressed,
      onDoubleTap: onDoublePressed,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDesign.padding),
        child: Container(
          height: 36.0,
          width: minWidth,
          decoration: BoxDecoration(
              color: !isPressed
                  ? (color ?? AppColors.secondary.withValues(alpha: .42))
                  : null,
              borderRadius: const BorderRadius.all(
                  Radius.circular(AppDesign.padding * .6))),
          child: Icon(
            icon,
            color:
                isPressed ? AppColors.tertiary : (iconColor ?? AppColors.field),
          ),
        ),
      ),
    );
  }
}
