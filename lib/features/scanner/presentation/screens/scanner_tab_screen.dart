import 'package:auto_route/auto_route.dart';

@RoutePage(name: 'ScannerTabRoute')
class ScannerTabScreen extends AutoRouter {
  const ScannerTabScreen({super.key});
}

// Note: The scanner heading is implemented in the child route screens
// as this is a tab router outlet that displays nested routes.
