import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PharmaSearchInput extends StatelessWidget {
  const PharmaSearchInput({
    super.key,
    required this.controller,
    required this.onChanged,
    this.placeholder = Strings.searchPlaceholder,
    this.onClear,
    this.autoFocus = false,
    this.keyboardType,
    this.isLoading = false,
    this.loadingLabel,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final VoidCallback? onClear;
  final bool autoFocus;
  final TextInputType? keyboardType;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    // On utilise ValueListenableBuilder pour réagir aux changements du texte
    // sans forcer un rebuild du parent entier (optimisation).
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;

        return ShadInput(
          controller: controller,
          placeholder: Text(placeholder),
          onChanged: onChanged,
          autofocus: autoFocus,
          keyboardType: keyboardType,
          leading: Icon(
            LucideIcons.search,
            size: AppDimens.iconSm,
            color: theme.colorScheme.mutedForeground,
          ),
          trailing: isLoading
              ? Semantics(
                  label: loadingLabel ?? Strings.searchingInProgress,
                  liveRegion: true,
                  child: SizedBox(
                    width: AppDimens.iconSm,
                    height: AppDimens.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                )
              : hasText
              ? Semantics(
                  button: true,
                  label: Strings.clearSearch,
                  child: ShadButton.ghost(
                    onPressed: () {
                      controller.clear();
                      onChanged(''); // Notifie le parent que c'est vide
                      onClear?.call();
                    },
                    width: AppDimens.iconLg,
                    height: AppDimens.iconLg,
                    padding: EdgeInsets.zero,
                    child: Icon(
                      LucideIcons.x,
                      size: AppDimens.iconSm,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
