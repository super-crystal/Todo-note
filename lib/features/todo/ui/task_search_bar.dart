import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';

class TaskSearchHeader extends SliverPersistentHeaderDelegate {
  TaskSearchHeader({
    required this.controller,
    required this.filterCount,
    required this.onChanged,
    required this.onFilters,
  });

  final TextEditingController controller;
  final int filterCount;
  final VoidCallback onChanged;
  final VoidCallback onFilters;

  @override
  double get minExtent => AppSize.searchHeaderHeight;
  @override
  double get maxExtent => AppSize.searchHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('all-task-search'),
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                hintText: S.searchAll,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: S.clearSearch,
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Semantics(
            label: S.filters,
            button: true,
            onTap: onFilters,
            child: ExcludeSemantics(
              child: IconButton.filledTonal(
                tooltip: S.filters,
                onPressed: onFilters,
                icon: Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant TaskSearchHeader oldDelegate) => true;
}
