import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/provider/terminal.dart';

/// Output of the last command; tap to see the history, long press to clear.
class TerminalOutput extends StatefulWidget {
  const TerminalOutput({super.key});

  @override
  State<TerminalOutput> createState() => _TerminalOutputState();
}

class _TerminalOutputState extends State<TerminalOutput> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final terminal = context.watch<TerminalProvider>();
    final lines = terminal.lines;
    if (lines.isEmpty) return const SizedBox.shrink();
    // Fits the whole output of the last command (3 to 10 lines).
    final raw = terminal.lastBlockLength;
    final block = raw < 3 ? 3 : (raw > 10 ? 10 : raw);
    final count = _expanded || lines.length < block ? lines.length : block;
    final visible = lines.sublist(lines.length - count);
    final style = AppDesign.textTheme(context).bodySmall!.copyWith(fontSize: 12.0, height: 1.3);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onLongPress: terminal.clear,
      child: Container(
        constraints: BoxConstraints(maxHeight: _expanded ? 260 : 18.0 * count + 10),
        margin: const EdgeInsets.only(top: AppDesign.padding / 2),
        padding: const EdgeInsets.symmetric(horizontal: AppDesign.padding / 2, vertical: 4),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in visible)
                Text(
                  line.text,
                  style: style.copyWith(
                    color: switch (line.kind) {
                      LineKind.input => AppColors.foreground,
                      LineKind.info => AppColors.text,
                      LineKind.success => AppColors.accent,
                      LineKind.error => AppColors.destructive,
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
