# 3. Read-path caching and optimistic writes

- Status: accepted

## Context

Marketplace users browse on the move and expect the app to respond
instantly. Unlike a wallet, almost all traffic is **reads**. Writes (saving,
messaging, posting) are few, user-initiated, and tolerant of a short delay.

## Decision

### Reads: stale-while-revalidate for the first page

- The first page of every feed query is written to a small JSON cache
  (atomic temp-file and rename, LRU eviction after 20 queries).
- On a network failure, the cached page is shown with an **offline banner**
  that says how old it is. Paging is disabled on stale data rather than
  mixing stale and fresh pages.
- Images go through `cached_network_image`, decoded at display size
  (`memCacheWidth`) to keep grid memory low.
- GET requests are retried twice with backoff by a Dio interceptor. Writes
  are never retried blindly.

### Writes: optimistic, with an honest failure path

| Write | Optimistic? | On failure |
|---|---|---|
| Save / unsave | yes | revert only that change; snackbar |
| Chat message | yes ("sending…") | bubble turns red; tap to retry with the **same client id**, so the server deduplicates |
| Photo upload | progress per photo | that photo shows retry; others continue |
| Publish ad | no (explicit spinner) | form kept; error shown; the draft is safe on disk |

Saved listings store a full snapshot, so the *Saved* tab works offline.

## Why not a full offline database (as in the wallet)?

A local DB with sync would mean modelling server-side ranking, search and
inventory changes locally, which is a large cost for little benefit when
listings change constantly. The wallet needs offline **writes** with
exactly-once delivery. The marketplace needs fast, honest **reads**.
Different problems, different tools.
