import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mptrack3/src/view/now_playing/now_playing.dart';

class NowPlayingRoute {
  const NowPlayingRoute._();

  /// Nested under the home route.
  static const path = 'now-playing';
  static const name = 'now-playing';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NowPlayingView(),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
}
