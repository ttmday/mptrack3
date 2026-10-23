import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/constants/design.dart';
import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/provider/terminal.dart';
import 'package:mptrack3/src/routes/now_playing.dart';
import 'package:mptrack3/src/view/home/widgets/browser_list.dart';
import 'package:mptrack3/src/view/home/widgets/browser_toolbar.dart';
import 'package:mptrack3/src/view/home/widgets/command_line.dart';
import 'package:mptrack3/src/view/home/widgets/main_player.dart';
import 'package:mptrack3/src/view/home/widgets/player_buttons.dart';
import 'package:mptrack3/src/widgets/sheets/dialogs.dart';
import 'package:mptrack3/src/widgets/sheets/help_sheet.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final StreamSubscription<TerminalEvent> _events;

  @override
  void initState() {
    super.initState();
    _events = context.read<TerminalProvider>().events.listen(_onTerminalEvent);
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }

  Future<void> _onTerminalEvent(TerminalEvent event) async {
    if (!mounted) {
      if (event is ConfirmEvent) event.answer(false);
      return;
    }
    switch (event) {
      case ShowHelpEvent():
        await showHelpSheet(context);
      case OpenNowPlayingEvent():
        context.pushNamed(NowPlayingRoute.name);
      case final ConfirmEvent confirm:
        confirm.answer(await showConfirmDialog(context, confirm.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final insets = MediaQuery.paddingOf(context);
    // Android back closes the search, then goes up a folder, then exits.
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
