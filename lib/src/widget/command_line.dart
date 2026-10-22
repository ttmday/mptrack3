import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/l10n/strings.dart';
import 'package:mptrack3/src/terminal/command_parser.dart';
import 'package:mptrack3/src/terminal/terminal_controller.dart';

/// Terminal output (last lines) plus the "mptrack3:~/path$" prompt.
class CommandLine extends StatelessWidget {
  const CommandLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalOutput(),
        _Prompt(),
      ],
    );
  }
}

class TerminalOutput extends StatefulWidget {
  const TerminalOutput({super.key});

  @override
  State<TerminalOutput> createState() => _TerminalOutputState();
}

class _TerminalOutputState extends State<TerminalOutput> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final terminal = context.watch<TerminalController>();
    final lines = terminal.lines;
    if (lines.isEmpty) return const SizedBox.shrink();
    // Show the whole output of the last command (e.g. "ls"), at least 3
    // lines; tap to see the full history.
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

class _Prompt extends StatefulWidget {
  const _Prompt();

  @override
  State<_Prompt> createState() => _PromptState();
}

class _PromptState extends State<_Prompt> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final BrowserController _browser;

  @override
  void initState() {
    super.initState();
    _browser = context.read<BrowserController>();
    _browser.addListener(_onBrowserChanged);
    _terminal = context.read<TerminalController>();
    _terminal.suggestion.addListener(_onSuggestion);
  }

  late final TerminalController _terminal;

  /// Fills the prompt with a command picked in the help sheet.
  void _onSuggestion() {
    final text = _terminal.suggestion.value;
    if (text == null) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _terminal.onTyping(text);
    _focus.requestFocus();
  }

  /// Clears a leftover search text when the search was closed elsewhere
  /// (e.g. tapping a folder result).
  void _onBrowserChanged() {
    if (_browser.searching || _controller.text.isEmpty) return;
    if (parseInput(_controller.text) is SearchInput) _controller.clear();
  }

  @override
  void dispose() {
    _browser.removeListener(_onBrowserChanged);
    _terminal.suggestion.removeListener(_onSuggestion);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    final terminal = context.read<TerminalController>();
    final clear = await terminal.submit(text);
    if (!mounted) return;
    if (clear) {
      _controller.clear();
      terminal.onTyping('');
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserController>();
    final theme = AppDesign.textTheme(context);
    final base = theme.bodyMedium!.copyWith(fontSize: 15.0, fontWeight: FontWeight.w700);

    return SizedBox(
      height: 52.0,
      child: Row(
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .45),
              child: Text.rich(
                TextSpan(
                  style: base.copyWith(color: AppColors.accent),
                  children: [
                    const TextSpan(text: 'mptrack3:'),
                    TextSpan(
                      text: browser.cwdLabel,
                      style: base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w400),
                    ),
                    TextSpan(
                      text: '\$',
                      style: base.copyWith(color: AppColors.text, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.padding / 2),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              cursorWidth: 10.0,
              cursorColor: AppColors.text,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.send,
              style: theme.bodyMedium!.copyWith(fontSize: 15.0),
              decoration: const InputDecoration(
                hintText: Strings.searchHint,
                hintMaxLines: 1,
                hintStyle: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w300,
                  overflow: TextOverflow.ellipsis,
                ),
                border: InputBorder.none,
              ),
              onChanged: context.read<TerminalController>().onTyping,
              onSubmitted: _submit,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _controller.clear();
                      context.read<TerminalController>().onTyping('');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
