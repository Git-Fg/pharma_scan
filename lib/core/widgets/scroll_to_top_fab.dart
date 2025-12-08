import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ScrollToTopFab extends HookWidget {
  const ScrollToTopFab({
    required this.controller,
    this.badgeCount,
    super.key,
  });

  final ScrollController controller;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final isVisible = useState(false);

    useEffect(() {
      void listener() {
        if (!controller.hasClients) return;
        final shouldShow = controller.offset > 500;
        if (shouldShow != isVisible.value) {
          isVisible.value = shouldShow;
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    Future<void> scrollToTop() async {
      if (!controller.hasClients) return;
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }

    final button = ShadIconButton.ghost(
      icon: const Icon(LucideIcons.arrowUp),
      onPressed: scrollToTop,
    );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: isVisible.value ? Offset.zero : const Offset(0, 0.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible.value ? 1 : 0,
        child: badgeCount != null
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  button,
                  Positioned(
                    top: -6,
                    right: -6,
                    child: ShadBadge(
                      child: Text(
                        '$badgeCount',
                        style: context.shadTextTheme.small,
                      ),
                    ),
                  ),
                ],
              )
            : button,
      ),
    );
  }
}
