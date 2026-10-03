# ui_kit

Design tokens and presentational widgets for the marketplace app.

- `Space`, `Radii`, `MarketplaceTheme` (light/dark from one seed colour).
- `ListingCard`: the image is injected as a widget, so the kit does not
  depend on an image library.
- `PriceText` / `formatSar`: locale-aware riyal formatting from integer
  halalas, always rendered left-to-right.
- `StatusView`, `OfflineBanner`, `Skeleton`, `StepProgress`.

Widgets take data and callbacks only. They never read app state.
