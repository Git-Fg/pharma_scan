import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/router/router_provider.dart';

extension RefRouter on Ref {
  StackRouter get router => read(appRouterProvider);
}
