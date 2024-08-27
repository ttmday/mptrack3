import 'package:go_router/go_router.dart';
import 'package:mptrack3/src/view/home/home.dart';

class HomeRoute {
  static String path = '/';
  static String name = 'home';

  static GoRoute get route => GoRoute(
      path: path, name: name, builder: (context, _) => const HomeView());
}
