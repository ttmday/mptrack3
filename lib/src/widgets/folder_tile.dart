import 'package:flutter/material.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

/// "▸ Rock/" with the number of songs inside, or ".." for the parent.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.isParent = false,
    this.subtitle,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isParent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = AppDesign.textTheme(context);
    final style = theme.bodyMedium!.copyWith(
        fontSize: 15.0, color: AppColors.text, fontWeight: FontWeight.w500);
    return SizedBox(
      height: subtitle == null ? AppDesign.tileExtent : AppDesign.tileExtentWithSubtitle,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesign.padding / 2),
          child: Row(
            children: [
              Text(isParent ? '◂ ' : '▸ ', style: style.copyWith(color: AppColors.primary)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isParent ? '..' : '$name/',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall!
                              .copyWith(fontSize: 11.0, color: AppColors.foreground)),
                  ],
                ),
              ),
              if (!isParent)
                Text('$count',
                    style: theme.bodySmall!.copyWith(color: AppColors.foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
