# 2. Riverpod for state management

- Status: accepted

## Context

This app has many small, independent async resources: the feed, one
conversation per listing, one details request per listing, favorites, and a
draft ad. Many of them are keyed by an id and should be created and disposed
on demand.

## Decision

Use **Riverpod 3** with plain `Notifier`/`FutureProvider` classes and no code
generation:

- **Families** model per-entity state naturally. `chatProvider(listingId)`
  owns exactly one conversation, and `listingProvider(id)` is auto-disposed
  when the details page closes.
- **Overrides** are the dependency injection mechanism. `main` overrides
  `sharedPreferencesProvider` and `feedCacheProvider`. Tests override the API,
  clock and photo source, and the integration test swaps the system photo
  picker for downloaded images.
- **Automatic retry is disabled** (`retry: (_, _) => null`). Failures are
  handled explicitly in controllers: offline fallback, rollback, and failed
  message states. Silent retries would hide them and double network traffic.

Controllers own the async rules that matter to users:

| Controller | Rule |
|---|---|
| `FeedController` | debounce typing; cancel the previous request when the query changes; append pages; fall back to cache offline |
| `FavoritesController` | optimistic toggle, roll back only the failed change |
| `ChatController` | optimistic send; retry with the same client id |
| `PostAdController` | parallel uploads with progress; per-photo retry; draft autosave; validate before publishing |

## Why not Bloc here?

The companion [fintech wallet](https://github.com/mokinan/flutter-fintech-wallet)
uses Bloc. There, event ordering, explicit state machines (session and lock)
and `bloc_concurrency` transformers fit the domain. Here, the dominant shape
is "many keyed async resources", which Riverpod families express with less
code. Choosing per project is deliberate.
