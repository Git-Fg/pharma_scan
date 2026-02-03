import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/cluster_provider.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AddRestockItemSheet extends HookConsumerWidget {
  const AddRestockItemSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final spacing = context.spacing;

    return Padding(
      padding: viewInsets,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, spacing.sm),
              child: Text(Strings.restockAddItemTitle, style: context.typo.h3),
            ),
            SizedBox(
              height: 480,
              child: ShadTabs<String>(
                value: 'cip',
                tabs: [
                  ShadTab(
                    value: 'cip',
                    content: const _CipAddTab(),
                    child: Text(Strings.restockAddByCip),
                  ),
                  ShadTab(
                    value: 'search',
                    content: const _SearchAddTab(),
                    child: Text(Strings.restockAddBySearch),
                  ),
                  ShadTab(
                    value: 'manual',
                    content: const _ManualAddTab(),
                    child: Text(Strings.restockAddManual),
                  ),
                ],
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}

class _CipAddTab extends HookConsumerWidget {
  const _CipAddTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final isSubmitting = useState(false);
    final spacing = context.spacing;

    Future<void> submit() async {
      if (isSubmitting.value) return;
      final cipStr = controller.text.trim();
      if (cipStr.length != 13) {
        return;
      }

      isSubmitting.value = true;
      try {
        await ref
            .read(restockProvider.notifier)
            .addByCip(Cip13.validated(cipStr));
        if (context.mounted) Navigator.pop(context);
      } finally {
        isSubmitting.value = false;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadInput(
            controller: controller,
            placeholder: const Text(Strings.cipPlaceholder),
            keyboardType: TextInputType.number,
            maxLength: 13,
            onSubmitted: (_) => submit(),
          ),
          Gap(spacing.lg),
          ShadButton(
            width: double.infinity,
            onPressed: submit,
            child: isSubmitting.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(Strings.restockAddButton),
          ),
        ],
      ),
    );
  }
}

class _SearchAddTab extends HookConsumerWidget {
  const _SearchAddTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final results = ref.watch(clusterSearchProvider(query.value));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ShadInput(
            placeholder: const Text(Strings.searchPlaceholder),
            leading: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(LucideIcons.search, size: 18),
            ),
            onChanged: (val) => query.value = val,
          ),
        ),
        Expanded(
          child: results.when(
            data: (clusters) => ListView.builder(
              itemCount: clusters.length,
              itemBuilder: (context, index) {
                final cluster = clusters[index];
                return ListTile(
                  title: Text(cluster.title),
                  subtitle: Text(cluster.subtitle),
                  trailing: const Icon(LucideIcons.plus, size: 18),
                  onTap: () async {
                    // Get products of this cluster and pick one (e.g. princeps)
                    final content = await ref.read(
                      clusterContentProvider(cluster.id).future,
                    );
                    if (content.isNotEmpty) {
                      // Try to find princeps, otherwise first product
                      final product = content.firstWhere(
                        (p) => p.isPrinceps,
                        orElse: () => content.first,
                      );
                      await ref
                          .read(restockProvider.notifier)
                          .addByCip(Cip13.validated(product.cipCode ?? ''));
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erreur: $err')),
          ),
        ),
      ],
    );
  }
}

class _ManualAddTab extends HookConsumerWidget {
  const _ManualAddTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final princepsController = useTextEditingController();
    final genericController = useTextEditingController();
    final spacing = context.spacing;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadInput(
            controller: princepsController,
            placeholder: const Text(Strings.restockPrincepsField),
          ),
          Gap(spacing.md),
          ShadInput(
            controller: genericController,
            placeholder: const Text(Strings.restockGenericField),
          ),
          Gap(spacing.lg),
          ShadButton(
            width: double.infinity,
            onPressed: () async {
              final princeps = princepsController.text.trim();
              if (princeps.isEmpty) return;

              await ref
                  .read(restockProvider.notifier)
                  .addManual(
                    princeps: princeps,
                    generic: genericController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(Strings.restockAddButton),
          ),
        ],
      ),
    );
  }
}
