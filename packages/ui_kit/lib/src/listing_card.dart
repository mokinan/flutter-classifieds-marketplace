import 'package:flutter/material.dart';
import 'package:ui_kit/src/price_text.dart';
import 'package:ui_kit/src/tokens.dart';

/// Grid tile for a listing. The [image] is injected so this package does not
/// depend on any image-loading library.
class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.title,
    required this.priceHalalas,
    required this.subtitle,
    required this.image,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.favoriteTooltip,
    super.key,
  });

  final String title;
  final int priceHalalas;

  /// Typically "City · 2 h ago".
  final String subtitle;
  final Widget image;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final String? favoriteTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: theme.colorScheme.surfaceContainerHighest, child: image),
                  if (onFavoriteToggle != null)
                    PositionedDirectional(
                      top: Space.xs,
                      end: Space.xs,
                      child: IconButton.filledTonal(
                        tooltip: favoriteTooltip,
                        isSelected: isFavorite,
                        onPressed: onFavoriteToggle,
                        icon: const Icon(Icons.favorite_border),
                        selectedIcon: Icon(Icons.favorite, color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: Space.xs),
                  PriceText(priceHalalas),
                  const SizedBox(height: Space.xs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
