import 'package:flutter/material.dart';

import 'common.dart';
import '../models/models.dart';

/// Charge une liste page après page (curseur) et notifie l'écran.
class Pager<T> extends ChangeNotifier {
  final Future<PageResult<T>> Function(int cursor) fetch;
  Pager(this.fetch);

  final List<T> items = [];
  int _cursor = 0;
  bool hasMore = true;
  bool loading = false;
  String? error;
  bool _disposed = false;

  Future<void> refresh() async {
    _cursor = 0;
    hasMore = true;
    await _load(replace: true);
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    await _load(replace: false);
  }

  Future<void> _load({required bool replace}) async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      final page = await fetch(replace ? 0 : _cursor);
      if (replace) items.clear();
      items.addAll(page.items);
      hasMore = page.nextCursor != null;
      _cursor = page.nextCursor ?? _cursor;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    _notify();
  }

  void removeWhere(bool Function(T) test) {
    items.removeWhere(test);
    _notify();
  }

  void replaceWhere(bool Function(T) test, T value) {
    final i = items.indexWhere(test);
    if (i >= 0) {
      items[i] = value;
      _notify();
    }
  }

  void insertFirst(T value) {
    items.insert(0, value);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Liste à défilement infini, avec « tirer pour rafraîchir ».
class PagedListView<T> extends StatefulWidget {
  final Pager<T> pager;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? header;
  final EdgeInsets padding;
  final bool separated;

  const PagedListView({
    super.key,
    required this.pager,
    required this.itemBuilder,
    this.emptyMessage = 'Rien à afficher pour le moment.',
    this.emptyIcon = Icons.inbox_outlined,
    this.header,
    this.padding = const EdgeInsets.all(12),
    this.separated = true,
  });

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        widget.pager.loadMore();
      }
    });
    if (widget.pager.items.isEmpty && !widget.pager.loading) widget.pager.refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pager,
      builder: (context, _) {
        final pager = widget.pager;
        final hasHeader = widget.header != null;

        if (pager.items.isEmpty) {
          Widget body;
          if (pager.loading) {
            body = const Center(child: CircularProgressIndicator());
          } else if (pager.error != null) {
            body = ErrorState(message: pager.error!, onRetry: pager.refresh);
          } else {
            body = EmptyState(icon: widget.emptyIcon, message: widget.emptyMessage);
          }
          return RefreshIndicator(
            onRefresh: pager.refresh,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (hasHeader) Padding(padding: widget.padding, child: widget.header!),
                SizedBox(height: 360, child: body),
              ],
            ),
          );
        }

        final extra = (hasHeader ? 1 : 0);
        final count = pager.items.length + extra + 1; // +1 : pied de liste
        return RefreshIndicator(
          onRefresh: pager.refresh,
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: count,
            separatorBuilder: (_, __) => SizedBox(height: widget.separated ? 10 : 0),
            itemBuilder: (context, i) {
              if (hasHeader && i == 0) return widget.header!;
              final index = i - extra;
              if (index == pager.items.length) {
                if (pager.loading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (pager.error != null) {
                  return TextButton(onPressed: pager.loadMore, child: Text('${pager.error}\nRéessayer'));
                }
                return const SizedBox(height: 8);
              }
              return widget.itemBuilder(context, pager.items[index]);
            },
          ),
        );
      },
    );
  }
}
