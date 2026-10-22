import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mptrack3/src/view/home/home.dart';
import 'package:mptrack3/src/view/now_playing/now_playing.dart';

class AppRouter {
  const AppRouter._();

  static const home = '/';
  static const nowPlaying = '/now-playing';

  static GoRouter create() => GoRouter(
        initialLocation: home,
        routes: [
          GoRoute(
            path: home,
            builder: (context, _) => const HomeView(),
            routes: [
              GoRoute(
                path: 'now-playing',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const NowPlayingView(),
                  transitionsBuilder: (context, animation, _, child) {
                    final curved = CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic);
                    return SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
}
