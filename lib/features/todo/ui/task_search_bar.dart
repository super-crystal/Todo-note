import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import 'task_search_results.dart';

class TaskSearchHeader extends SliverPersistentHeaderDelegate {
  TaskSearchHeader({
    required this.controller,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final SearchController controller;
  final ValueChanged<Todo> onEdit;
  final ValueChanged<Todo> onToggle;
  final ValueChanged<Todo> onDelete;

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
      child: SearchAnchor(
        searchController: controller,
        isFullScreen: true,
        viewHintText: S.searchAll,
        viewTrailing: [
          IconButton(
            tooltip: S.clearSearch,
            onPressed: controller.clear,
            icon: const Icon(Icons.close),
          ),
        ],
        suggestionsBuilder: (_, _) => const [],
        viewBuilder: (_) => TaskSearchResults(
          controller: controller,
          onEdit: onEdit,
          onToggle: onToggle,
          onDelete: onDelete,
        ),
        builder: (context, search) => SearchBar(
          key: const ValueKey('all-task-search'),
          hintText: S.searchAll,
          leading: const Icon(Icons.search),
          onTap: search.openView,
          onChanged: (_) => search.openView(),
          controller: search,
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant TaskSearchHeader oldDelegate) => true;
}
