import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'library.dart';
import 'app_motion.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.item,
    required this.library,
    this.searchQuery = '',
    this.matchedWords = const [],
    this.matchSnippet = '',
  });
  final Screenshot item;
  final Library library;
  final String searchQuery, matchSnippet;
  final List<String> matchedWords;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Screenshot item = widget.item;
  Timer? timer;
  final sheet = DraggableScrollableController();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (item.pending && !busy) await refreshItem();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    sheet.dispose();
    super.dispose();
  }

  Future<void> refreshItem() async {
    try {
      final updated = await widget.library.screenshot(item.id);
      if (updated != null && mounted && !busy) setState(() => item = updated);
    } catch (_) {
      // Keep the last visible content if refreshing fails.
    }
  }

  Future<void> retryReading() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-read screenshot?'),
        content: const Text(
          'A successful read replaces the current text, including any edits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-read'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    await widget.library.retry(item.id);
    await refreshItem();
    feedback('Reading screenshot again…');
  }

  Future<void> editText() async {
    setState(() => busy = true);
    try {
      final updated = await Navigator.of(context).push<Screenshot>(
        MaterialPageRoute(
          builder: (_) => _TextEditor(item: item, library: widget.library),
        ),
      );
      if (updated != null && mounted) {
        setState(() => item = updated);
        feedback('Text saved and searchable');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete screenshot?'),
        content: const Text(
          'This removes the saved image and its text from View Q.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.library.delete(item.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete screenshot. Please try again.'),
          ),
        );
      }
    }
  }

  bool showFullText = false;
  Future<void> chooseCategory() async {
    const categories = {
      '': 'Automatic',
      'Receipt': 'Receipts',
      'Link': 'Links',
      'OTP': 'Codes/OTPs',
      'Note': 'Notes',
      'Travel': 'Travel',
      'Deliveries': 'Deliveries',
      'Payments': 'Payments',
      'Events': 'Events',
      'Conversations': 'Conversations',
      'Documents': 'Documents',
    };
    final selected = await showModalBottomSheet<String>(
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
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Change category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final entry in categories.entries)
                ListTile(
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final updated = await widget.library.setCategory(item.id, selected);
    if (updated != null && mounted) setState(() => item = updated);
  }

  late final RegExp? matchPattern = makeMatchPattern();

  RegExp? makeMatchPattern() {
    final terms =
        RegExp(r'[\p{L}\p{N}]+', unicode: true)
            .allMatches(widget.searchQuery)
            .take(16)
            .map((match) => match.group(0)!)
            .followedBy(widget.matchedWords)
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    return terms.isEmpty
        ? null
        : RegExp(
            terms.map(RegExp.escape).join('|'),
            caseSensitive: false,
            unicode: true,
          );
  }

  TextSpan highlighted(String value, Color accent) {
    final pattern = matchPattern;
    if (pattern == null) return TextSpan(text: value);
    var end = 0;
    final children = <TextSpan>[];
    for (final match in pattern.allMatches(value)) {
      children.add(TextSpan(text: value.substring(end, match.start)));
      children.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: accent, fontWeight: FontWeight.w800),
        ),
      );
      end = match.end;
    }
    children.add(TextSpan(text: value.substring(end)));
    return TextSpan(children: children);
  }

  void toggleFullText() {
    setState(() => showFullText = !showFullText);
    if (showFullText && sheet.isAttached && sheet.size < .65) {
      unawaited(
        sheet.animateTo(
          .65,
          duration: motionDuration(context),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  Uri? get link {
    final candidate = RegExp(
      r'https?://[^\s<>]+',
      caseSensitive: false,
    ).firstMatch(item.text)?.group(0);
    if (candidate == null) return null;
    final uri = Uri.tryParse(candidate.replaceFirst(RegExp(r'[.,;)]+$'), ''));
    return uri != null && uri.host.isNotEmpty ? uri : null;
  }

  void feedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> act(Future<void> Function() action) async {
    unawaited(HapticFeedback.lightImpact());
    try {
      await action();
    } catch (_) {
      feedback('Could not complete the action.');
    }
  }

  Future<void> shareScreenshot() async {
    final image = File(item.path);
    final handle = await image.open();
    List<int> header;
    try {
      header = await handle.read(12);
    } finally {
      await handle.close();
    }
    final (extension, mime) = switch (header) {
      [137, 80, 78, 71, ...] => ('png', 'image/png'),
      [255, 216, 255, ...] => ('jpg', 'image/jpeg'),
      [71, 73, 70, ...] => ('gif', 'image/gif'),
      [82, 73, 70, 70, _, _, _, _, 87, 69, 66, 80] => ('webp', 'image/webp'),
      [_, _, _, _, 102, 116, 121, 112, ...] => ('heic', 'image/heic'),
      _ => ('img', 'image/*'),
    };
    if (!mounted) return;
    await Library.channel.invokeMethod<void>('shareScreenshot', {
      'path': item.path,
      'extension': extension,
      'mime': mime,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final target = link;
    final facts = item.facts
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(8);
    return Scaffold(
      appBar: AppBar(title: const Text('Screenshot')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, limits) => Stack(
            children: [
              Positioned.fill(
                bottom: limits.maxHeight * .34,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 6,
                  child: Center(
                    child: Hero(
                      tag: 'screenshot-${item.id}',
                      child: Image(
                        image: ResizeImage(
                          FileImage(File(item.path)),
                          width: 1600,
                          height: 2400,
                          policy: ResizeImagePolicy.fit,
                        ),
                        fit: BoxFit.contain,
                        semanticLabel:
                            'Saved screenshot. Pinch with two fingers to zoom.',
                        errorBuilder: (_, _, _) =>
                            const Text('Could not display this image.'),
                      ),
                    ),
                  ),
                ),
              ),
              DraggableScrollableSheet(
                controller: sheet,
                initialChildSize: .34,
                minChildSize: .22,
                maxChildSize: .92,
                snap: true,
                snapSizes: const [.34, .65],
                builder: (context, scroll) => Material(
                  color: colors.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outline,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(
                          'Screenshot text',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.matchSnippet.isNotEmpty &&
                          matchPattern?.hasMatch(item.text) == true) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.outlineVariant),
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.matchedWords.isEmpty
                                      ? 'Matched text'
                                      : 'Approximate match',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text.rich(
                                  highlighted(
                                    widget.matchSnippet,
                                    colors.primary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (item.pending) const Text('Reading text…'),
                      if (item.status == 'failed') ...[
                        const Text('Could not read text. Your image is saved.'),
                        TextButton(
                          onPressed: () => act(retryReading),
                          child: const Text('Try again'),
                        ),
                      ],
                      if (item.status == 'done' && item.text.isEmpty)
                        const Text('No readable text'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          label: Text(
                            item.category.isEmpty
                                ? 'Choose category'
                                : item.category,
                          ),
                          avatar: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: busy ? null : () => act(chooseCategory),
                        ),
                      ),
                      if (item.summary.isNotEmpty) ...[
                        Semantics(
                          header: true,
                          child: Text(
                            'Summary',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(item.summary, style: theme.textTheme.bodyLarge),
                      ],
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final fact in facts)
                              InputChip(
                                label: Text(
                                  fact,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () => act(() async {
                                  await Clipboard.setData(
                                    ClipboardData(text: fact),
                                  );
                                  feedback('Copied');
                                }),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit text'),
                            onPressed: busy ? null : () => act(editText),
                          ),
                          if (item.text.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy Text'),
                              onPressed: () => act(() async {
                                await Clipboard.setData(
                                  ClipboardData(text: item.text),
                                );
                                feedback('Screenshot text copied');
                              }),
                            ),
                          if (target != null)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open Link'),
                              onPressed: () => act(
                                () => Library.channel.invokeMethod<void>(
                                  'openLink',
                                  {'url': target.toString()},
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                            onPressed: () => act(shareScreenshot),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            onPressed: busy ? null : () => act(remove),
                          ),
                        ],
                      ),
                      if (item.text.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          icon: Icon(
                            showFullText ? Icons.expand_less : Icons.subject,
                          ),
                          label: Text(
                            showFullText ? 'Hide full text' : 'View full text',
                          ),
                          onPressed: () {
                            unawaited(HapticFeedback.lightImpact());
                            toggleFullText();
                          },
                        ),
                        AnimatedSize(
                          duration: motionDuration(context),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          child: showFullText
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: SelectableText.rich(
                                    highlighted(item.text, colors.primary),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                      if (item.status == 'done') ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Re-read screenshot'),
                          onPressed: busy ? null : () => act(retryReading),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({required this.item, required this.library});
  final Screenshot item;
  final Library library;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final text = TextEditingController(text: widget.item.text);
  bool saving = false;
  bool allowExit = false;
  bool confirmingExit = false;

  @override
  void initState() {
    super.initState();
    text.addListener(onEdited);
  }

  void onEdited() {
    setState(() {});
  }

  Future<void> confirmExit() async {
    if (saving || confirmingExit) return;
    if (text.text == widget.item.text) {
      setState(() => allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edited text has not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    confirmingExit = false;
    if (discard == true && mounted) {
      setState(() => allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    text.removeListener(onEdited);
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final updated = await widget.library.correctText(
        widget.item.id,
        text.text.trim(),
      );
      if (updated == null) throw StateError('Missing screenshot');
      if (mounted) {
        setState(() => allowExit = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, updated);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save text. Your edits are still here.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(confirmExit());
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Edit screenshot text')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, bounds) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bounds.maxHeight >= 310) ...[
                  Flexible(
                    flex: 1,
                    child: InteractiveViewer(
                      child: Center(
                        child: Image(
                          image: ResizeImage(
                            FileImage(File(widget.item.path)),
                            width: 1400,
                            height: 1600,
                            policy: ResizeImagePolicy.fit,
                          ),
                          fit: BoxFit.contain,
                          semanticLabel: 'Original screenshot',
                          errorBuilder: (_, _, _) =>
                              const Text('Preview unavailable'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: text,
                    enabled: !saving,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Searchable text',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save text'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
