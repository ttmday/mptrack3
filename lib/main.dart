import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mptrack3/src/provider/browser.dart';
import 'package:mptrack3/src/constants/theme.dart';
import 'package:mptrack3/src/provider/library.dart';
import 'package:mptrack3/src/service/player/player.dart';
import 'package:mptrack3/src/provider/player.dart';
import 'package:mptrack3/src/routes/router.dart';
import 'package:mptrack3/src/provider/terminal.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  final prefs = await SharedPreferences.getInstance();
  final library = LibraryProvider(prefs);
  final handler = await initPlayerService((track) => library.artwork(track));
  final player = PlayerProvider(handler, library, prefs);
  final browser = BrowserProvider(library, prefs);
  final terminal = TerminalProvider(
    library: library,
    browser: browser,
    player: player,
  );

  await library.init();
  if (library.status == LibraryStatus.ready) {
    await player.restoreSession();
  }

  FlutterNativeSplash.remove();
  runApp(Mptrack3App(
    library: library,
    player: player,
    browser: browser,
    terminal: terminal,
  ));
}

class Mptrack3App extends StatefulWidget {
  const Mptrack3App({
    super.key,
    required this.library,
    required this.player,
    required this.browser,
    required this.terminal,
  });

  final LibraryProvider library;
  final PlayerProvider player;
  final BrowserProvider browser;
  final TerminalProvider terminal;

  @override
  State<Mptrack3App> createState() => _Mptrack3AppState();
}

class _Mptrack3AppState extends State<Mptrack3App> with WidgetsBindingObserver {
  final _router = AppRouter.create();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Catches files added while the app was in the background (and is
        // the only change signal on iOS, where the Files app adds music).
        if (widget.library.status == LibraryStatus.ready) {
          widget.library.scheduleReload();
        }
      case AppLifecycleState.paused:
        widget.player.saveSession();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.library),
        ChangeNotifierProvider.value(value: widget.browser),
        ChangeNotifierProvider.value(value: widget.terminal),
        Provider.value(value: widget.player),
      ],
      child: MaterialApp.router(
        title: 'Mptrack3',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(),
        routerConfig: _router,
      ),
    );
  }
}
