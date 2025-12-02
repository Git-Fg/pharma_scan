
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/pharmaceutical_forms_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget buildAdministrationRouteFilterTile(
  BuildContext context,
  WidgetRef ref,
  SearchFilters currentFilters,
) {
  final routesAsync = ref.watch(administrationRoutesProvider);

  return routesAsync.when(
    data: (routes) {
      if (routes.isEmpty) {
        return _buildTile(
          context: context,
          title: Strings.administrationRouteFilter,
          subtitle: Strings.noRoutesAvailable,
        );
      }

      final selectedValue = currentFilters.voieAdministration;
      final selectedText = selectedValue ?? Strings.allRoutes;

      return _buildSelectTile(
        context: context,
        title: Strings.administrationRouteFilter,
        selectedText: selectedText,
        routes: routes,
        selectedValue: selectedValue,
        onChanged: (value) {
          ref
              .read(searchFiltersProvider.notifier)
              .updateFilters(
                currentFilters.copyWith(voieAdministration: value),
              );
          unawaited(Navigator.of(context).maybePop());
        },
      );
    },
    loading: () => _buildTile(
      context: context,
      title: Strings.administrationRouteFilter,
      trailing: const SizedBox(
        width: AppDimens.iconSm,
        height: AppDimens.iconSm,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    error: (error, _) => _buildTile(
      context: context,
      title: Strings.errorLoadingRoutes,
      subtitle: '$error',
    ),
  );
}

Widget _buildTile({
  required BuildContext context,
  required String title,
  String? subtitle,
  Widget? trailing,
}) {
  final theme = ShadTheme.of(context);
  return InkWell(
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.p),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppDimens.spacingSm),
            trailing,
          ],
          const SizedBox(width: AppDimens.spacingXs),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
      ),
    ),
  );
}

class _SelectTileWithSearch extends HookWidget {
  const _SelectTileWithSearch({
    required this.title,
    required this.selectedText,
    required this.routes,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final String selectedText;
  final List<String> routes;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final searchValue = useState('');

    final filteredRoutes = routes.where((route) {
      if (searchValue.value.isEmpty) return true;
      return route.toLowerCase().contains(searchValue.value.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      child: ShadSelect<String?>.withSearch(
        minWidth: 300,
        initialValue: selectedValue,
        maxHeight: 320,
        placeholder: const Text(Strings.allRoutes),
        searchPlaceholder: const Text('Rechercher une voie...'),
        onSearchChanged: (value) => searchValue.value = value,
        options: [
          const ShadOption<String?>(
            value: null,
            child: Text(Strings.allRoutes),
          ),
          if (filteredRoutes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Aucune voie trouvée'),
            ),
          ...filteredRoutes.map(
            (route) => ShadOption<String?>(
              value: route,
              child: Text(route),
            ),
          ),
        ],
        selectedOptionBuilder: (context, value) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.p),
                  const SizedBox(height: 4),
                  Text(
                    selectedText,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        onChanged: (value) {
          onChanged(value);
          unawaited(Navigator.of(context).maybePop());
        },
      ),
    );
  }
}

Widget _buildSelectTile({
  required BuildContext context,
  required String title,
  required String selectedText,
  required List<String> routes,
  required String? selectedValue,
  required ValueChanged<String?> onChanged,
}) {
  return _SelectTileWithSearch(
    title: title,
    selectedText: selectedText,
    routes: routes,
    selectedValue: selectedValue,
    onChanged: onChanged,
  );
}

class AdministrationRouteFilterTile extends ConsumerWidget {
  const AdministrationRouteFilterTile({
    required this.currentFilters,
    super.key,
  });

  final SearchFilters currentFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return buildAdministrationRouteFilterTile(context, ref, currentFilters);
  }
}
