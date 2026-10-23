import 'package:flutter/material.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';

const _dialogShape = RoundedRectangleBorder(
  side: BorderSide(color: AppColors.accent),
  borderRadius: BorderRadius.all(Radius.circular(AppDesign.padding)),
);

Future<bool> showConfirmDialog(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.background,
      shape: _dialogShape,
      title: Text('mptrack3:~\$ rm',
          style: AppDesign.sheetText(context, color: AppColors.accent)),
      content: Text(message, style: AppDesign.sheetText(context)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(Strings.cancel,
              style: AppDesign.sheetText(context, color: AppColors.foreground)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(Strings.delete,
              style: AppDesign.sheetText(context, color: AppColors.destructive)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showTextInputDialog(BuildContext context, String hint) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.background,
      shape: _dialogShape,
      title: Text('mptrack3:~\$ mkdir',
          style: AppDesign.sheetText(context, color: AppColors.accent)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: AppDesign.sheetText(context),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: hint,
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
          child: Text(Strings.cancel,
              style: AppDesign.sheetText(context, color: AppColors.foreground)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(Strings.create,
              style: AppDesign.sheetText(context, color: AppColors.accent)),
        ),
      ],
    ),
  );
}
