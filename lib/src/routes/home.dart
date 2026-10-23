import 'package:go_router/go_router.dart';

import 'package:mptrack3/src/routes/now_playing.dart';
import 'package:mptrack3/src/view/home/home.dart';

class HomeRoute {
  const HomeRoute._();

  static const path = '/';
  static const name = 'home';

  static GoRoute get route => GoRoute(
        path: path,
        name: name,
        builder: (context, _) => const HomeView(),
        routes: [NowPlayingRoute.route],
      );
}
