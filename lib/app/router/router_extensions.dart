import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/app/router/router_provider.dart';

/// Extension on [Ref] for convenient router access in Notifiers.
///
/// Provides `ref.router` shorthand for `ref.read(routerProvider)`.
/// This enables navigation as a side-effect from business logic:
///
/// ```dart
/// class AuthNotifier extends _$AuthNotifier {
///   void logout() {
///     state = AsyncData(null);
///     ref.router.replace(const LoginRoute());
///   }
/// }
/// ```
extension RefRouter on Ref {
  StackRouter get router => read(routerProvider);
}
