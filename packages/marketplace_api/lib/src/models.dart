import 'package:meta/meta.dart';

/// A listing category.
@immutable
class Category {
  const Category({required this.slug, required this.name});

  factory Category.fromJson(Map<String, Object?> json) =>
      Category(slug: json['slug']! as String, name: json['name']! as String);

  final String slug;
  final String name;

  @override
  bool operator ==(Object other) => other is Category && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

/// An item for sale.
@immutable
class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.priceHalalas,
    required this.category,
    required this.city,
    required this.sellerName,
    required this.thumbnailUrl,
    required this.imageUrls,
    required this.postedAt,
  });

  /// Maps the demo backend's product shape to a classified listing.
  ///
  /// The demo API has no seller location, so a city is assigned
  /// deterministically from the id; prices are converted from USD and rounded
  /// to whole riyals.
  factory Listing.fromJson(Map<String, Object?> json) {
    final id = json['id']! as int;
    final meta = json['meta'] as Map<String, Object?>?;
    return Listing(
      id: id,
      title: json['title']! as String,
      description: json['description'] as String? ?? '',
      // Classified prices are quoted in whole riyals.
      priceHalalas: ((json['price']! as num) * 3.75).round() * 100,
      category: json['category']! as String,
      city: demoCities[id % demoCities.length],
      sellerName: json['brand'] as String? ?? 'Private seller',
      thumbnailUrl: json['thumbnail']! as String,
      imageUrls: (json['images'] as List<Object?>? ?? const []).cast<String>(),
      postedAt: DateTime.tryParse(meta?['createdAt'] as String? ?? '') ?? DateTime(2026),
    );
  }

  static const demoCities = ['Riyadh', 'Jeddah', 'Dammam', 'Makkah', 'Madinah', 'Khobar', 'Abha', 'Tabuk'];

  final int id;
  final String title;
  final String description;

  /// Price in halalas (1 SAR = 100 halalas) — integers, never doubles.
  final int priceHalalas;
  final String category;
  final String city;
  final String sellerName;
  final String thumbnailUrl;
  final List<String> imageUrls;
  final DateTime postedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'price': priceHalalas / 375,
    'category': category,
    'brand': sellerName,
    'thumbnail': thumbnailUrl,
    'images': imageUrls,
    'meta': {'createdAt': postedAt.toIso8601String()},
  };

  @override
  bool operator ==(Object other) => other is Listing && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum ListingSort { relevance, priceLowToHigh, priceHighToLow, newest }

/// What the feed is showing. A search and a category are mutually exclusive
/// because the backend cannot combine them.
@immutable
class ListingQuery {
  const ListingQuery({this.search = '', this.category, this.sort = ListingSort.relevance});

  final String search;
  final String? category;
  final ListingSort sort;

  bool get isSearch => search.trim().isNotEmpty;

  ListingQuery withSearch(String value) => ListingQuery(search: value, sort: sort);
  ListingQuery withCategory(String? value) => ListingQuery(category: value, sort: sort);
  ListingQuery withSort(ListingSort value) => ListingQuery(search: search, category: category, sort: value);

  /// Stable key for caching.
  String get cacheKey => 'q=${search.trim().toLowerCase()}|c=${category ?? ''}|s=${sort.name}';

  @override
  bool operator ==(Object other) =>
      other is ListingQuery && other.search == search && other.category == category && other.sort == sort;

  @override
  int get hashCode => Object.hash(search, category, sort);
}

/// One page of results with an offset cursor.
@immutable
class ListingPage {
  const ListingPage({required this.items, required this.total, required this.offset});

  final List<Listing> items;
  final int total;
  final int offset;

  int get nextOffset => offset + items.length;
  bool get hasMore => nextOffset < total;
}

/// A new listing being published.
@immutable
class ListingDraft {
  const ListingDraft({
    required this.title,
    required this.description,
    required this.priceHalalas,
    required this.category,
    required this.city,
    required this.imageIds,
  });

  final String title;
  final String description;
  final int priceHalalas;
  final String category;
  final String city;

  /// Ids returned by `MarketplaceApi.uploadImage`, in display order.
  final List<String> imageIds;
}
