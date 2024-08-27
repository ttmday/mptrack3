import 'package:go_router/go_router.dart';
import 'package:mptrack3/src/routes/home.dart';

class RouterProvider {
  const RouterProvider();

  GoRouter get router =>
      GoRouter(initialLocation: HomeRoute.path, routes: [HomeRoute.route]);
}
