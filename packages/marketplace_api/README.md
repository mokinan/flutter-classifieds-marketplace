# marketplace_api

Pure-Dart client for the marketplace backend.

- **Typed models**: `Listing` (prices as integer halalas), `Category`,
  `ListingQuery`, `ListingPage`, `ListingDraft`.
- **`MarketplaceApi`**: listings with search, category, sort and offset
  paging; `CancelToken` support so the app can abort superseded requests;
  image upload with progress; publishing.
- **Typed errors**: `ApiException` → `NetworkUnavailable`, `NotFound`,
  `ServerError`, `BadRequest`, `RequestCancelled`.
- **`ChatGateway`**: a realtime chat contract, plus `SimulatedChatGateway`
  (ack delay, typing indicator, replies, failure injection, idempotent
  `clientId`).

No Flutter dependency, so it is tested with `dart test`.
