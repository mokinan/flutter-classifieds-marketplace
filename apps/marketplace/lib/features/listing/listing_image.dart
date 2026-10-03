import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// Network image with disk caching, a skeleton while loading and a quiet
/// fallback on failure. Decodes at display size to save memory in grids.
class ListingImage extends StatelessWidget {
  const ListingImage(this.url, {this.fit = BoxFit.cover, this.cacheWidth, super.key});

  final String url;
  final BoxFit fit;

  /// Logical width the image is shown at; decoding is sized to match.
  final double? cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || !url.startsWith('http')) return const _Fallback();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: cacheWidth == null ? null : (cacheWidth! * dpr).round(),
      placeholder: (_, _) => const Skeleton(radius: 0),
      errorWidget: (_, _, _) => const _Fallback(),
      fadeInDuration: const Duration(milliseconds: 150),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(Icons.image_not_supported_outlined, color: Theme.of(context).colorScheme.outline));
}
