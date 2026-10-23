import 'package:go_router/go_router.dart';

import 'package:mptrack3/src/routes/home.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter create() => GoRouter(
        initialLocation: HomeRoute.path,
        routes: [HomeRoute.route],
      );
}
