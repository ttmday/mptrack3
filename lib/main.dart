import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:mptrack3/src/routes/router.dart';

import 'package:mptrack3/src/service/notifications_service.dart';
import 'package:mptrack3/src/service/audio_query_request.dart';
import 'package:mptrack3/src/service/audio_handler.dart';
import 'package:mptrack3/src/service/audio_manager.dart';
import 'package:mptrack3/src/service/player_invoke.dart';

import 'package:mptrack3/src/constants/theme.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await NotificationsService.getInstance().init();
  MyAudioHandler audioHandler = await initAudioService();

  final audioQR = AudioQueryRequest();
  final List<SongModel> allSongs = [];
  if (await audioQR.checkAndRequestPermissions()) {
    List<SongModel> songs = await audioQR.getSongs();

    songs = audioQR.filterMusic(songs);
    songs.sort((a, b) {
      int? dateA = a.dateAdded;
      int? dateB = b.dateAdded;

      if (dateA != null && dateB != null) {
        return dateB.compareTo(dateA);
      }

      if (dateA == null) {
        return 1;
      }

      return -1;
    });
    allSongs.addAll(songs);
  }

  AudioManager audioManager = AudioManager(audioHandler);
  PlayerInvoke playerInvoke = PlayerInvoke(audioManager, audioQR);
  audioManager.managerNotifier.value = ManagerState.loading;

  await playerInvoke.init(songsList: allSongs, index: 0);

  FlutterNativeSplash.remove();
  runApp(MyApp(
    audioManager: audioManager,
    playerInvoke: playerInvoke,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp(
      {super.key, required this.audioManager, required this.playerInvoke});

  final AudioManager audioManager;
  final PlayerInvoke playerInvoke;

  @override
  Widget build(BuildContext context) {
    // ThemeHelper.setStatusBarAndNavigationBarTheme(
    //     color: Palette.dark, brightness: Brightness.light);
    return MultiProvider(
        providers: [
          Provider<RouterProvider>(create: (context) => const RouterProvider()),
          Provider<AudioManager>(
              create: (context) => audioManager,
              dispose: (_, manager) => manager.dispose()),
          Provider<PlayerInvoke>(create: (context) => playerInvoke)
        ],
        builder: (context, _) {
          GoRouter router = context.read<RouterProvider>().router;
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(),
            routeInformationParser: router.routeInformationParser,
            routeInformationProvider: router.routeInformationProvider,
            routerDelegate: router.routerDelegate,
          );
        });
  }
}
