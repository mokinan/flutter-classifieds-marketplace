# 1. Monorepo with Dart pub workspaces

- Status: accepted

## Context

A marketplace app grows by feature teams: search, posting, chat, payments.
Without hard boundaries, feature code reaches into networking internals and
UI components start depending on app state. That makes them impossible to
reuse or test in isolation.

## Decision

Use a single repository with **Dart pub workspaces** (Dart 3.6+) and three
members:

| Package | Depends on | Purpose |
|---|---|---|
| `packages/marketplace_api` | `dio` only (pure Dart) | Typed models, the HTTP client, typed exceptions, and the chat transport |
| `packages/ui_kit` | Flutter, `intl` | Design tokens, theme and presentational widgets. It knows nothing about the domain or app state |
| `apps/marketplace` | both packages | Features, state management and navigation |

Rules that keep the boundaries honest:

- `ui_kit` widgets receive data and callbacks, never providers. `ListingCard`
  takes its image as a `Widget`, so the kit does not depend on any image
  library.
- `marketplace_api` is pure Dart and tested with `dart test`, with no Flutter
  binding.
- The workspace has one lockfile, so all members always agree on dependency
  versions.

**Why not Melos?** Pub workspaces now cover the part that matters
(single resolution and IDE support) without an extra tool. Melos remains an
option for scripted multi-package releases.

## Consequences

- Each package has its own focused test suite, and CI runs all of them.
- Extracting a package for another app (for example a seller dashboard) is a
  move, not a rewrite.
- New contributors must understand the dependency direction. It is enforced
  by `pubspec.yaml`: a package cannot import what it does not declare.
