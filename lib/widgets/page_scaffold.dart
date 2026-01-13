import 'package:flutter/material.dart';

class PageScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool fillRemaining;
  final Widget child;
  const PageScaffold({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.fillRemaining = false,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(title),
          actions: actions,
          bottom: bottom,
        ),
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        if (!fillRemaining)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: child),
          )
        else
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
      ],
    );
  }
}
