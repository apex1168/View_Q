import 'package:flutter/services.dart';

class Screenshot {
  const Screenshot({
    required this.id,
    required this.path,
    required this.created,
    required this.status,
    required this.text,
    required this.snippet,
    this.thumbnail = '',
    this.category = '',
    this.summary = '',
    this.facts = '',
    this.approximate = const [],
    this.hasText = false,
    this.hasLink = false,
  });
  factory Screenshot.fromMap(Map<Object?, Object?> value) => Screenshot(
    id: value['id']! as String,
    path: value['path']! as String,
    created: DateTime.fromMillisecondsSinceEpoch(value['created']! as int),
    status: value['status']! as String,
    text: value['text']! as String,
    snippet: value['snippet']! as String,
    thumbnail: value['thumbnail'] as String? ?? '',
    category: value['category'] as String? ?? '',
    summary: value['summary'] as String? ?? '',
    facts: value['facts'] as String? ?? '',
    hasText: value['hasText'] as bool? ?? false,
    hasLink: value['hasLink'] as bool? ?? false,
    approximate:
        (value['approximate'] as List?)?.whereType<String>().toList() ??
        const [],
  );
  final String id, path, status, text, snippet;
  final String thumbnail;
  final String category, summary, facts;
  final List<String> approximate;
  final bool hasText, hasLink;
  final DateTime created;
  bool get pending => status == 'pending';
}

/// Native implementations own durable storage, SQLite, and the OCR queue.
/// No image bytes cross the method channel.
class Library {
  static const channel = MethodChannel('org.viewq/library');
  Future<int?> backup({required bool restore}) =>
      channel.invokeMethod<int>(restore ? 'restoreBackup' : 'exportBackup');
  Future<bool> themeMode([bool? dark]) async =>
      await channel.invokeMethod<bool>(
        'themeMode',
        dark == null ? null : {'dark': dark},
      ) ??
      true;
  Future<List<String>> searchHistory([String? openedId]) async =>
      await channel.invokeListMethod<String>(
        openedId == null ? 'searchHistory' : 'recordSearchOpen',
        openedId == null ? null : {'id': openedId},
      ) ??
      [];
  Future<Set<String>> favorites([String? toggleId]) async =>
      (await channel.invokeListMethod<String>(
                toggleId == null ? 'favorites' : 'toggleFavorite',
                toggleId == null ? null : {'id': toggleId},
              ) ??
              [])
          .toSet();
  Future<Map<String, int>> indexStatus() async =>
      await channel.invokeMapMethod<String, int>('indexStatus') ?? {};
  Future<List<Screenshot>> list(String query) async {
    final rows = await channel.invokeListMethod<Object?>('list', {
      'query': query,
    });
    return (rows ?? []).map((e) => Screenshot.fromMap(e! as Map)).toList();
  }

  Future<List<Screenshot>> previews(String query) async {
    try {
      final rows = await channel.invokeListMethod<Object?>('previews', {
        'query': query,
      });
      return (rows ?? []).map((e) => Screenshot.fromMap(e! as Map)).toList();
    } on MissingPluginException {
      return list(query);
    }
  }

  Future<LibraryPageResult> browse(
    String query, {
    int offset = 0,
    String category = '',
    DateTime? from,
    DateTime? until,
    List<String>? ids,
  }) async {
    const limit = 60;
    try {
      final result = await channel.invokeMapMethod<Object?, Object?>('browse', {
        'query': query,
        'offset': offset,
        'limit': limit,
        'category': category,
        'from': from?.millisecondsSinceEpoch,
        'until': until?.millisecondsSinceEpoch,
        'ids': ids,
      });
      final rows = (result?['items'] as List? ?? []).cast<Map>();
      return LibraryPageResult(
        rows.map(Screenshot.fromMap).toList(),
        result?['hasMore'] == true,
        result?['next'] as int? ?? offset,
      );
    } on MissingPluginException {
      final rows = (await previews(query))
          .where(
            (item) =>
                (category.isEmpty ||
                    item.category == category ||
                    (category == 'Link' && item.hasLink)) &&
                (from == null || !item.created.isBefore(from)) &&
                (until == null || item.created.isBefore(until)) &&
                (ids == null || ids.contains(item.id)),
          )
          .toList();
      return LibraryPageResult(
        rows.skip(offset).take(limit).toList(),
        rows.length > offset + limit,
        (offset + limit).clamp(0, rows.length),
      );
    }
  }

  Future<bool> pick() async =>
      await channel.invokeMethod<bool>('pick') ?? false;
  Future<Screenshot?> screenshot(String id) async {
    final row = await channel.invokeMapMethod<Object?, Object?>('screenshot', {
      'id': id,
    });
    return row == null ? null : Screenshot.fromMap(row);
  }

  Future<Screenshot?> correctText(String id, String text) async {
    final row = await channel.invokeMapMethod<Object?, Object?>('correctText', {
      'id': id,
      'text': text,
    });
    return row == null ? null : Screenshot.fromMap(row);
  }

  Future<Screenshot?> setCategory(String id, String category) async {
    final row = await channel.invokeMapMethod<Object?, Object?>('setCategory', {
      'id': id,
      'category': category,
    });
    return row == null ? null : Screenshot.fromMap(row);
  }

  Future<void> resume() => channel.invokeMethod<void>('resume');
  Future<void> delete(String id) =>
      channel.invokeMethod<void>('delete', {'id': id});
  Future<void> retry(String id) =>
      channel.invokeMethod<void>('retry', {'id': id});
}

class LibraryPageResult {
  const LibraryPageResult(this.items, this.hasMore, this.next);
  final List<Screenshot> items;
  final bool hasMore;
  final int next;
}
