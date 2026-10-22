import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/browser/browser_controller.dart';
import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/routes/router.dart';
import 'package:mptrack3/src/terminal/terminal_controller.dart';
import 'package:mptrack3/src/widget/browser_list.dart';
import 'package:mptrack3/src/widget/browser_toolbar.dart';
import 'package:mptrack3/src/widget/command_line.dart';
import 'package:mptrack3/src/widget/main_player.dart';
import 'package:mptrack3/src/widget/main_player_buttons.dart';
import 'package:mptrack3/src/widget/sheets.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> implements TerminalHost {
  late final TerminalController _terminal;

  @override
  void initState() {
    super.initState();
    _terminal = context.read<TerminalController>()..host = this;
  }

  @override
  void dispose() {
    if (identical(_terminal.host, this)) _terminal.host = null;
    super.dispose();
  }

  @override
  Future<bool> confirm(String message) {
    if (!mounted) return Future.value(false);
    return showConfirmDialog(context, message);
  }

  @override
  void openNowPlaying() {
    if (mounted) context.push(AppRouter.nowPlaying);
  }

  @override
  void showHelp() {
    if (mounted) showHelpSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserController>();
    final insets = MediaQuery.paddingOf(context);
    // Android back: close search, then go up a folder, then leave the app.
    return PopScope(
      canPop: !browser.searching && !browser.canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (browser.searching) {
          browser.clearQuery();
        } else {
          browser.up();
        }
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              top: insets.top + 10.0,
              left: AppDesign.padding,
              right: AppDesign.padding,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MainPlayer(),
                SizedBox(height: AppDesign.padding * .25),
                MainPlayerButtons(),
                SizedBox(height: AppDesign.padding * .35),
                BrowserToolbar(),
                Expanded(child: BrowserList()),
                CommandLine(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
