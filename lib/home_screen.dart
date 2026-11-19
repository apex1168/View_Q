import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_ui/material_ui.dart';

import 'detail_screen.dart';
import 'library.dart';
import 'app_motion.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.library, this.onToggleTheme});
  final Library library;
  final VoidCallback? onToggleTheme;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  final search = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  Timer? poll, debounce;
  List<Screenshot> rows = [];
  Set<String> favorites = {};
  List<String> searchHistory = [];
  Map<String, int> status = {};
  DateTimeRange? dates;
  int filter = 0, tab = 0, request = 0;
  bool loading = true, saving = false, failed = false;
  bool backingUp = false;
  bool requestInFlight = false;
  bool queuedRefresh = false;
  bool listLayout = false;
  bool hasMore = false, loadingMore = false;
  int nextOffset = 0;
  String? openingId;
  String displayedQuery = '';
  Library get library => widget.library;
  static const labels = [
    'All',
    'Receipts',
    'Links',
    'Codes/OTPs',
    'Notes',
    'Travel',
    'Deliveries',
    'Payments',
    'Events',
    'Conversations',
    'Documents',
    'Favorites',
  ];
  static final urls = RegExp(r'https?://', caseSensitive: false);
  static final codes = RegExp(
    r'\b(otp|verification code|security code|one.time (?:password|code))\b',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.extentAfter < 600) {
        unawaited(loadMore());
      }
    });
    Library.channel.setMethodCallHandler((call) async {
      if (call.method == 'saveError') notify('Could not save screenshot.');
      await refresh();
      await refreshStatus();
    });
    resumeLibrary();
  }

  Future<void> resumeLibrary() async {
    try {
      await library.resume();
    } catch (_) {
      /* Refresh reports a library error. */
    }
    if (!mounted) return;
    unawaited(refresh());
    unawaited(refreshStatus());
    unawaited(loadFavorites());
    unawaited(loadSearchHistory());
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final changed = await refreshStatus();
      if (changed && mounted && !(debounce?.isActive ?? false)) {
        await refresh();
      }
    });
  }

  Future<void> loadSearchHistory([String? openedId]) async {
    try {
      final next = await library.searchHistory(openedId);
      if (mounted) {
        setState(() => searchHistory = next);
        if (tab == 2 && search.text.trim().isEmpty) unawaited(refresh());
      }
    } catch (_) {
      // Search remains available if local history is unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeLibrary();
    } else {
      poll?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Library.channel.setMethodCallHandler(null);
    poll?.cancel();
    debounce?.cancel();
    search.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (requestInFlight) {
      queuedRefresh = true;
      return;
    }
    requestInFlight = true;
    final ticket = ++request;
    final query = search.text.trim();
    try {
      final page = await browsePage(query);
      if (!mounted || ticket != request) return;
      setState(() {
        rows = page.items;
        hasMore = page.hasMore && !(tab == 1 && query.isEmpty);
        nextOffset = page.next;
        displayedQuery = query;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted && ticket == request) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    } finally {
      requestInFlight = false;
      if (mounted && queuedRefresh) {
        queuedRefresh = false;
        unawaited(refresh());
      }
    }
  }

  Future<LibraryPageResult> browsePage(String query, [int offset = 0]) {
    final category = switch (filter) {
      1 => 'Receipt',
      2 => 'Link',
      3 => 'OTP',
      4 => 'Note',
      0 || 11 => '',
      _ => labels[filter],
    };
    return library.browse(
      query,
      offset: offset,
      category: category,
      from: dates?.start,
      until: dates == null
          ? null
          : DateTime(dates!.end.year, dates!.end.month, dates!.end.day + 1),
      ids: tab == 2 && query.isEmpty
          ? searchHistory
          : filter == 11
          ? favorites.toList()
          : null,
    );
  }

  Future<void> loadMore() async {
    if (!mounted ||
        loading ||
        loadingMore ||
        !hasMore ||
        requestInFlight ||
        (debounce?.isActive ?? false) ||
        search.text.trim() != displayedQuery) {
      return;
    }
    final ticket = request;
    setState(() => loadingMore = true);
    try {
      final page = await browsePage(displayedQuery, nextOffset);
      if (!mounted || request != ticket) return;
      setState(() {
        final known = rows.map((item) => item.id).toSet();
        rows.addAll(page.items.where((item) => known.add(item.id)));
        hasMore = page.hasMore;
        nextOffset = page.next;
      });
    } catch (_) {
      notify('Could not load more screenshots. Please try again.');
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void changeCollection(int index) {
    request++;
    setState(() {
      filter = index;
      loading = true;
    });
    unawaited(refresh());
  }

  Future<bool> refreshStatus() async {
    try {
      final next = await library.indexStatus();
      if (mounted &&
          (next['total'] != status['total'] ||
              next['pending'] != status['pending'] ||
              next['indexed'] != status['indexed'])) {
        setState(() => status = next);
        return true;
      }
    } catch (_) {
      /* Counters are optional. */
    }
    return false;
  }

  Future<void> loadFavorites([String? id]) async {
    try {
      final next = await library.favorites(id);
      if (mounted) {
        setState(() => favorites = next);
        if (filter == 11) unawaited(refresh());
      }
    } catch (_) {
      if (id != null) notify('Could not update Favorites.');
    }
  }

  void notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> runBackup({required bool restore}) async {
    focus.unfocus();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(restore ? 'Restore a backup?' : 'Export a backup?'),
        content: Text(
          restore
              ? 'View Q adds missing screenshots and keeps the versions already in your library.'
              : 'The ZIP file contains your original images, searchable text, and Favorites. It is unencrypted. Choose a private folder you control.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(restore ? 'Choose file' : 'Choose folder'),
          ),
        ],
      ),
    );
    if (!mounted || proceed != true) return;
    setState(() => backingUp = true);
    try {
      final count = await library.backup(restore: restore);
      if (count == null || !mounted) return;
      if (restore) {
        notify(
          count == 0
              ? 'No new screenshots to restore'
              : 'Restored $count screenshots',
        );
        await loadFavorites();
        await refresh();
        await refreshStatus();
      } else {
        notify('Saved backup with $count screenshots');
      }
    } on PlatformException catch (error) {
      notify(error.message ?? 'Could not complete the backup operation.');
    } catch (_) {
      notify('Could not complete the backup operation.');
    } finally {
      if (mounted) setState(() => backingUp = false);
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      if (await library.pick()) notify('Screenshot saved');
      await refresh();
      await refreshStatus();
    } on PlatformException catch (error) {
      notify(error.message ?? 'Could not save screenshot.');
    } catch (_) {
      notify('Could not save screenshot.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: dates,
    );
    if (mounted && range != null) {
      request++;
      setState(() {
        dates = range;
        loading = true;
      });
      unawaited(refresh());
    }
  }

  Future<void> openScreenshot(Screenshot preview, String query) async {
    if (openingId != null) return;
    setState(() => openingId = preview.id);
    Screenshot? full;
    try {
      full = await library.screenshot(preview.id);
    } catch (_) {
      // The card stays in the gallery and can be opened again.
    } finally {
      if (mounted) setState(() => openingId = null);
    }
    if (!mounted) return;
    if (full == null) {
      notify('Could not open screenshot. Please try again.');
      return;
    }
    final item = full;
    focus.unfocus();
    if (query.isNotEmpty) unawaited(loadSearchHistory(item.id));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailPage(
          item: item,
          library: library,
          searchQuery: query,
          matchedWords: preview.approximate,
          matchSnippet: query.isEmpty ? '' : preview.snippet,
        ),
      ),
    );
    if (mounted) {
      unawaited(refresh());
      unawaited(refreshStatus());
    }
  }

  Future<void> chooseCollection() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Text(
                  'Collections',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final (index, label) in labels.indexed)
                ListTile(
                  title: Text(label),
                  selected: filter == index,
                  leading: Icon(collectionIcon(index)),
                  trailing: filter == index ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, index),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) changeCollection(selected);
  }

  IconData collectionIcon(int index) => switch (index) {
    0 => Icons.grid_view_rounded,
    1 => Icons.receipt_long_outlined,
    2 => Icons.link,
    3 => Icons.password_rounded,
    5 => Icons.flight_takeoff,
    6 => Icons.local_shipping_outlined,
    7 => Icons.account_balance_wallet_outlined,
    8 => Icons.event_outlined,
    9 => Icons.chat_bubble_outline,
    10 => Icons.description_outlined,
    11 => Icons.star_border_rounded,
    _ => Icons.notes_rounded,
  };

  String category(Screenshot item) {
    if (item.category.isNotEmpty) return item.category;
    if (codes.hasMatch(item.text)) return 'OTP';
    if (urls.hasMatch(item.text)) return 'Link';
    return item.hasText || item.text.trim().isNotEmpty ? 'Note' : '';
  }

  bool matchesFilter(Screenshot item) {
    final range = dates;
    final day = DateUtils.dateOnly(item.created);
    if (range != null &&
        (day.isBefore(range.start) || day.isAfter(range.end))) {
      return false;
    }
    final kind = category(item);
    return switch (filter) {
      1 => kind == 'Receipt',
      2 => kind == 'Link' || item.hasLink || urls.hasMatch(item.text),
      3 => kind == 'OTP',
      4 => kind == 'Note',
      0 => true,
      _ =>
        labels[filter] == 'Favorites'
            ? favorites.contains(item.id)
            : kind == labels[filter],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final results = rows.where(matchesFilter);
    final historyMode = tab == 2 && search.text.trim().isEmpty;
    final byId = historyMode
        ? {for (final item in results) item.id: item}
        : <String, Screenshot>{};
    final visible = historyMode
        ? [
            for (final id in searchHistory)
              if (byId[id] case final Screenshot item) item,
          ]
        : (tab == 1 && displayedQuery.isEmpty ? results.take(20) : results)
              .toList();
    final columns =
        listLayout ||
            MediaQuery.sizeOf(context).width < 340 ||
            MediaQuery.textScalerOf(context).scale(16) > 25
        ? 1
        : 2;
    final total = status['total'] ?? 0;
    final indexed = status['indexed'] ?? 0;
    final indexing = (status['pending'] ?? 0) > 0;
    final querying = search.text.trim() != displayedQuery;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(26) > 36
            ? MediaQuery.textScalerOf(context).scale(26) * 2 + 16
            : 64,
        title: Row(
          children: [
            if (MediaQuery.textScalerOf(context).scale(26) <= 36) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/branding/logo.png',
                  width: 36,
                  height: 36,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                'View Q',
                maxLines: 2,
                style: TextStyle(
                  fontFamily: 'ArchivoBlack',
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -1,
                  height: 1.08,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (Platform.isAndroid)
            PopupMenuButton<bool>(
              tooltip: 'Library backup',
              enabled: !backingUp && !saving,
              icon: const Icon(Icons.more_vert),
              onSelected: (restore) => runBackup(restore: restore),
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Export backup')),
                PopupMenuItem(value: true, child: Text('Restore backup')),
              ],
            ),
          IconButton(
            tooltip: theme.brightness == Brightness.dark
                ? 'Use light theme'
                : 'Use dark theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Save screenshot',
        onPressed: saving || backingUp ? null : save,
        elevation: 0,
        highlightElevation: 0,
        child: saving
            ? const CircularProgressIndicator(
                semanticsLabel: 'Saving screenshot',
              )
            : const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        animationDuration: motionDuration(context, 240),
        selectedIndex: tab,
        onDestinationSelected: (next) {
          if (next != tab) {
            debounce?.cancel();
            final needsRefresh =
                search.text.isNotEmpty || displayedQuery.isNotEmpty;
            search.clear();
            setState(() {
              tab = next;
              filter = 0;
              dates = null;
              if (needsRefresh) {
                rows = [];
                displayedQuery = '';
                loading = true;
              }
            });
            unawaited(refresh());
          }
          if (next == 2) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || tab != 2) return;
              focus.requestFocus();
              unawaited(
                SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
              );
            });
          } else {
            focus.unfocus();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            label: 'Library',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recent'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (backingUp)
              const LinearProgressIndicator(
                semanticsLabel: 'Working with library backup',
              ),
            if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
                MediaQuery.textScalerOf(context).scale(16) <= 24)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    header: true,
                    child: AnimatedSwitcher(
                      duration: motionDuration(context),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text(
                        tab == 2
                            ? 'Find it again.'
                            : tab == 1
                            ? 'Freshly saved.'
                            : 'Your screenshots,\nwithin reach.',
                        style: theme.textTheme.headlineLarge,
                        key: ValueKey(tab),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              key: const ValueKey('persistent-search-field'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: search,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search words in screenshots',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (search.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            search.clear();
                            debounce?.cancel();
                            setState(() {});
                            refresh();
                          },
                        ),
                      IconButton(
                        tooltip: 'Filter by date',
                        icon: Icon(
                          dates == null ? Icons.tune : Icons.filter_alt,
                        ),
                        onPressed: pickDates,
                      ),
                    ],
                  ),
                ),
                onChanged: (_) {
                  request++;
                  setState(() {});
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 110), refresh);
                },
                onSubmitted: (_) {
                  debounce?.cancel();
                  refresh();
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final index in const [0, 11, 1, 2])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(labels[index]),
                        selected: filter == index,
                        showCheckmark: false,
                        selectedColor: colors.primaryContainer,
                        onSelected: (_) => changeCollection(index),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(collectionIcon(filter), size: 17),
                      label: Text(
                        const [0, 11, 1, 2].contains(filter)
                            ? 'Collections'
                            : labels[filter],
                      ),
                      onPressed: chooseCollection,
                    ),
                  ),
                  if (dates != null)
                    InputChip(
                      label: const Text('Date range'),
                      onDeleted: () {
                        setState(() => dates = null);
                        refresh();
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 8,
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              historyMode
                                  ? 'Opened from search'
                                  : displayedQuery.isNotEmpty
                                  ? 'Search results'
                                  : tab == 1
                                  ? 'Recently saved'
                                  : 'Screenshots',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          if (!loading && !failed && !querying)
                            Text(
                              displayedQuery.isNotEmpty
                                  ? '${visible.length}${hasMore ? '+' : ''} ${visible.length == 1 ? 'match' : 'matches'}'
                                  : '${visible.length}${hasMore ? '+' : ''} saved',
                              style: theme.textTheme.bodySmall,
                            ),
                          IconButton(
                            tooltip: listLayout
                                ? 'Switch to gallery'
                                : 'Switch to list',
                            onPressed: () =>
                                setState(() => listLayout = !listLayout),
                            icon: Icon(
                              listLayout
                                  ? Icons.grid_view_rounded
                                  : Icons.view_agenda_outlined,
                            ),
                          ),
                          if (total > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  indexing
                                      ? Icons.sync
                                      : Icons.check_circle_outline,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  indexing
                                      ? 'Reading $indexed/$total'
                                      : '$indexed indexed',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (loading)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childCount: 6,
                        itemBuilder: (_, index) =>
                            _Skeleton(height: index.isEven ? 176 : 224),
                      ),
                    )
                  else if (querying && !failed)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(
                          semanticsLabel: 'Searching screenshots',
                        ),
                      ),
                    )
                  else if (failed || visible.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                failed
                                    ? Icons.error_outline
                                    : Icons.photo_library_outlined,
                                size: 40,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                failed
                                    ? 'Could not open your library.'
                                    : historyMode
                                    ? 'Search for text, then open a result to find it here later.'
                                    : displayedQuery.isNotEmpty ||
                                          filter != 0 ||
                                          dates != null
                                    ? 'No matching screenshots'
                                    : 'To save a screenshot, tap Share on the image and choose View Q.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge,
                              ),
                              if (failed)
                                TextButton(
                                  onPressed: refresh,
                                  child: const Text('Try again'),
                                ),
                              if (!failed && total == 0 && !historyMode) ...[
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: saving || backingUp ? null : save,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                  label: const Text('Save screenshot'),
                                ),
                              ],
                              if (!failed &&
                                  total > 0 &&
                                  (filter != 0 || dates != null)) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => setState(() {
                                    filter = 0;
                                    dates = null;
                                    unawaited(refresh());
                                  }),
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return GalleryEntrance(
                            key: ValueKey(
                              '${item.id}-$filter-$tab-$listLayout-$displayedQuery',
                            ),
                            index: index,
                            child: _GalleryCard(
                              item: item,
                              kind: category(item),
                              query: displayedQuery,
                              favorite: favorites.contains(item.id),
                              listLayout: listLayout,
                              opening: openingId == item.id,
                              onFavorite: () => loadFavorites(item.id),
                              onOpen: () async {
                                await openScreenshot(item, displayedQuery);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  if (hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton(
                          onPressed: loadingMore ? null : loadMore,
                          child: Text(
                            loadingMore ? 'Loading…' : 'Load more screenshots',
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.item,
    required this.kind,
    required this.query,
    required this.favorite,
    required this.listLayout,
    required this.opening,
    required this.onFavorite,
    required this.onOpen,
  });
  final Screenshot item;
  final String kind, query;
  final bool favorite, listLayout, opening;
  final VoidCallback onFavorite, onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final category = item.pending ? 'Reading text' : kind;
    final image = Hero(
      tag: 'screenshot-${item.id}',
      child: Image.file(
        File(item.thumbnail.isEmpty ? item.path : item.thumbnail),
        cacheWidth: 300,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.image_outlined)),
      ),
    );
    final star = IconButton(
      tooltip: favorite ? 'Remove from Favorites' : 'Add to Favorites',
      color: favorite ? colors.primary : colors.onSurfaceVariant,
      onPressed: onFavorite,
      icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded),
    );
    final details = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (category.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(item.created),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          if (query.isNotEmpty && item.snippet.isNotEmpty) ...[
            const SizedBox(height: 6),
            if (item.approximate.isNotEmpty)
              Text(
                'Approximate match',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            _Snippet(item: item, query: query),
          ] else if (listLayout && item.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.summary.replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
    final film = ColoredBox(
      color: colors.surfaceContainer,
      child: listLayout
          ? SizedBox(width: 80, height: 96, child: image)
          : ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 88,
                maxHeight: 172,
                minWidth: double.infinity,
              ),
              child: image,
            ),
    );
    return Material(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: opening ? null : onOpen,
        child: Stack(
          children: [
            if (listLayout)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: film,
                    ),
                    Expanded(child: details),
                    star,
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: film,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: IconButton.filledTonal(
                          tooltip: favorite
                              ? 'Remove from Favorites'
                              : 'Add to Favorites',
                          onPressed: onFavorite,
                          icon: Icon(
                            favorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  details,
                ],
              ),
            if (opening)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  semanticsLabel: 'Opening screenshot',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Snippet extends StatelessWidget {
  const _Snippet({required this.item, required this.query});
  final Screenshot item;
  final String query;

  @override
  Widget build(BuildContext context) {
    final terms =
        RegExp(r'[\p{L}\p{N}]+', unicode: true)
            .allMatches(query)
            .take(32)
            .map((m) => m.group(0)!)
            .followedBy(item.approximate)
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    if (terms.isEmpty) {
      return Text(item.snippet, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final pattern = RegExp(
      terms.map(RegExp.escape).join('|'),
      caseSensitive: false,
      unicode: true,
    );
    var snippet = item.snippet;
    if (!pattern.hasMatch(snippet)) {
      snippet = item.text.replaceAll(RegExp(r'\s+'), ' ');
    }
    final first = pattern.firstMatch(snippet);
    if (first != null && first.start > 16) {
      snippet = '…${snippet.substring(first.start - 16)}';
    }
    final spans = <InlineSpan>[];
    var end = 0;
    for (final match in pattern.allMatches(snippet)) {
      spans.add(TextSpan(text: snippet.substring(end, match.start)));
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      end = match.end;
    }
    spans.add(TextSpan(text: snippet.substring(end)));
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton({required this.height});
  final double height;
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
    } else if (!animation.isAnimating) {
      animation.repeat();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final position = animation.value * 3 - 1.5;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
              gradient: LinearGradient(
                colors: [
                  colors.surfaceContainer,
                  colors.surfaceContainerHighest,
                  colors.surfaceContainer,
                ],
                begin: Alignment(position - 1, 0),
                end: Alignment(position + 1, 0),
              ),
            ),
            child: SizedBox(height: widget.height),
          );
        },
      ),
    );
  }
}
