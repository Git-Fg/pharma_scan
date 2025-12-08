import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Reduces boilerplate for handling AsyncValue state changes.
/// Returns true when the provider is loading.
bool useAsyncFeedback<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> provider, {
  bool hapticSuccess = false,
  String? errorMessage,
}) {
  final context = useContext();
  final feedback = ref.watch(hapticServiceProvider);
  final state = ref.watch(provider);

  ref
    // Error Listener
    ..listen<AsyncValue<T>>(provider, (prev, next) {
      if (next is AsyncError) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.error),
            description: Text(errorMessage ?? next.error.toString()),
          ),
        );
        unawaited(feedback.error());
      }
    })
    // Success Listener
    ..listen<AsyncValue<T>>(provider, (prev, next) {
      if (hapticSuccess && next is AsyncData && prev is! AsyncData) {
        unawaited(feedback.success());
      }
    });

  return state.isLoading;
}
