// lib/features/explorer/widgets/filters/administration_route_filter_tile.dart

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/providers/pharmaceutical_forms_provider.dart';

FTileMixin buildAdministrationRouteFilterTile(
  BuildContext context,
  WidgetRef ref,
  SearchFilters currentFilters,
) {
  final routesAsync = ref.watch(administrationRoutesProvider);

  return routesAsync.when(
    data: (routes) {
      if (routes.isEmpty) {
        return FTile(
          title: const Text(Strings.administrationRouteFilter),
          subtitle: Text(
            Strings.noRoutesAvailable,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        );
      }

      final menu = [
        FSelectTile<String?>(
          title: Text(Strings.allRoutes, style: context.theme.typography.base),
          value: null,
        ),
        ...routes.map(
          (route) => FSelectTile<String?>(
            title: Text(route, style: context.theme.typography.base),
            value: route,
          ),
        ),
      ];

      // Forui widgets automatically provide accessibility from title/details properties
      // No need for explicit Semantics wrapper - it would break FTileMixin type anyway
      return FSelectMenuTile<String?>(
        initialValue: currentFilters.voieAdministration,
        title: Text(
          Strings.administrationRouteFilter,
          style: context.theme.typography.base,
        ),
        detailsBuilder: (tileContext, values, _) {
          final value = values.isNotEmpty ? values.first : null;
          return Text(
            value ?? Strings.allRoutes,
            style: tileContext.theme.typography.sm.copyWith(
              color: tileContext.theme.colors.mutedForeground,
            ),
          );
        },
        maxHeight: 320,
        menu: menu,
        onChange: (values) {
          final value = values.isNotEmpty ? values.first : null;
          ref
              .read(searchFiltersProvider.notifier)
              .updateFilters(
                currentFilters.copyWith(voieAdministration: value),
              );
          Navigator.of(context).maybePop();
        },
      );
    },
    loading: () => FTile(
      title: const Text(Strings.administrationRouteFilter),
      suffix: const SizedBox(
        width: AppDimens.iconSm,
        height: AppDimens.iconSm,
        child: FCircularProgress.loader(),
      ),
    ),
    error: (error, _) => FTile(
      title: const Text(Strings.errorLoadingRoutes),
      subtitle: Text(
        '$error',
        style: context.theme.typography.sm.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    ),
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
