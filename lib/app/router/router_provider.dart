import 'package:auto_route/auto_route.dart';
import 'package:pharma_scan/app/router/app_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router_provider.g.dart';

/// The global [AppRouter] instance.
///
/// Use this in `main.dart` to configure `MaterialApp.router`.
@riverpod
AppRouter appRouter(Ref ref) {
  return AppRouter();
}

/// Provides access to the [StackRouter] for navigation from Notifiers.
///
/// This enables navigation without `BuildContext`, treating navigation
/// as a side-effect service. Use `ref.read(routerProvider)` in Notifiers.
///
/// Example:
/// ```dart
/// class MyNotifier extends _$MyNotifier {
///   void logout() {
///     ref.read(routerProvider).replace(const LoginRoute());
///   }
/// }
/// ```
///
/// The `Raw<>` wrapper prevents Riverpod from tracking dispose on the router,
/// since it's a long-lived singleton managed by the app lifecycle.
@riverpod
Raw<StackRouter> router(Ref ref) {
  return ref.read(appRouterProvider);
}
