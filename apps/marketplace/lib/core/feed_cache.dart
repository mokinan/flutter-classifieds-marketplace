import 'dart:convert';
import 'dart:io';

import 'package:marketplace_api/marketplace_api.dart';

/// A first page of results saved for offline use.
typedef CachedPage = ({ListingPage page, DateTime savedAt});

/// Stores the first page of each feed query on disk, so reopening the app
/// without a connection still shows something useful
/// (stale-while-revalidate).
class FeedCache {
  FeedCache(this.directory, {this.maxEntries = 20});

  final Directory directory;

  /// Least-recently-written entries beyond this are deleted.
  final int maxEntries;

  File _file(ListingQuery query) =>
      File('${directory.path}/feed_${base64Url.encode(utf8.encode(query.cacheKey)).replaceAll('=', '')}.json');

  Future<void> write(ListingQuery query, ListingPage page, {DateTime? now}) async {
    await directory.create(recursive: true);
    final file = _file(query);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'savedAt': (now ?? DateTime.now()).toIso8601String(),
        'total': page.total,
        'items': [for (final l in page.items) l.toJson()],
      }),
    );
    await tmp.rename(file.path);
    await _evict();
  }

  Future<CachedPage?> read(ListingQuery query) async {
    final file = _file(query);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final items = (json['items']! as List<Object?>).cast<Map<String, Object?>>().map(Listing.fromJson).toList();
      return (
        page: ListingPage(items: items, total: json['total']! as int, offset: 0),
        savedAt: DateTime.parse(json['savedAt']! as String),
      );
    } on FormatException {
      // A corrupt cache entry is not worth crashing over.
      await file.delete();
      return null;
    }
  }

  Future<void> _evict() async {
    final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final stale in files.skip(maxEntries)) {
      await stale.delete();
    }
  }
}
