import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' as hooks;
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/utils/hooks/use_async_feedback.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:riverpod/riverpod.dart' as riverpod;
import 'package:shadcn_ui/shadcn_ui.dart';

class _MockFeedback extends Mock implements HapticService {}

class _TestAsyncNotifier extends riverpod.Notifier<riverpod.AsyncValue<int>> {
  @override
  riverpod.AsyncValue<int> build() => const riverpod.AsyncLoading<int>();

  void setError(Object error) {
    state = riverpod.AsyncError<int>(error, StackTrace.empty);
  }

  void setData(int value) {
    state = riverpod.AsyncData<int>(value);
  }
}

final _testAsyncProvider =
    riverpod.NotifierProvider<_TestAsyncNotifier, riverpod.AsyncValue<int>>(
      _TestAsyncNotifier.new,
    );

class _HookHarness extends hooks.HookConsumerWidget {
  const _HookHarness();

  @override
  Widget build(BuildContext context, hooks.WidgetRef ref) {
    final notifier = ref.read(_testAsyncProvider.notifier);
    final isLoading = useAsyncFeedback<int>(
      ref,
      _testAsyncProvider,
      hapticSuccess: true,
      errorMessage: 'boom',
    );

    return Column(
      children: [
        Text(isLoading ? 'loading' : 'idle', key: const Key('state')),
        ShadButton(
          key: const Key('fail'),
          onPressed: () => notifier.setError(Exception('fail')),
          child: const Text('fail'),
        ),
        ShadButton(
          key: const Key('succeed'),
          onPressed: () => notifier.setData(1),
          child: const Text('succeed'),
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Exception('fallback'));
  });

  group('useAsyncFeedback', () {
    late _MockFeedback mockFeedback;

    setUp(() {
      mockFeedback = _MockFeedback();
      when(() => mockFeedback.error()).thenAnswer((_) async {});
      when(() => mockFeedback.success()).thenAnswer((_) async {});
    });

    Future<void> pumpHarness(WidgetTester tester) async {
      await tester.pumpWidget(
        hooks.ProviderScope(
          overrides: [
            hapticServiceProvider.overrideWithValue(mockFeedback),
          ],
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadSlateColorScheme.light(),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadSlateColorScheme.dark(),
            ),
            appBuilder: (context) => MaterialApp(
              builder: (context, child) =>
                  ShadAppBuilder(child: child ?? const SizedBox.shrink()),
              home: const Scaffold(
                body: _HookHarness(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows destructive toast on error and triggers haptic error', (
      tester,
    ) async {
      await pumpHarness(tester);

      expect(find.text('loading'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fail')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.error), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
      verify(() => mockFeedback.error()).called(1);
    });

    testWidgets('fires success haptic when transitioning to AsyncData', (
      tester,
    ) async {
      await pumpHarness(tester);

      await tester.tap(find.byKey(const Key('succeed')));
      await tester.pumpAndSettle();

      expect(find.text('idle'), findsOneWidget);
      verify(() => mockFeedback.success()).called(1);
    });
  });
}
