# Connecting a real backend later

The application uses `DemoRecyclingRepository` and `DemoAuthRepository`, in-memory implementations of `RecyclingRepository` and `AuthRepository`. Login and registration work with static accounts and passwords held in memory only. There are no EasyScrap backend requests, JWTs, database connections or upload requests yet. Maps make online provider requests; administrative dropdowns read the four Philippine JSON files packaged within `app-side/assets/data/`.

## Replacement boundary

1. Implement `RecyclingRepository` in a new `data/api_recycling_repository.dart` file. Keep request/response DTO parsing and API error translation in that data layer.
2. Inject that implementation in `main.dart` instead of `DemoRecyclingRepository`. The screens and controller call the interface, so the UI workflow can remain intact. Use `AppConfig.endpoint(...)` from `lib/core/app_config.dart` for all URLs. The hosted default can be overridden with `--dart-define=API_URL=.../api/v1`.
3. Implement `AuthRepository` with real login and registration requests, inject it in `main.dart`, and return the server's user identity and role. `AppController.currentUser` already drives the session and navigation. Remove the demo credential buttons when enabling real authentication. Store tokens using a platform secure-storage package; enforce ownership and roles again on the server. Hash passwords on the backend; never adapt the demo's in-memory plaintext credential list into production storage.
4. Load each role's authorized records. The demo loads shared records in memory only to allow testing both roles on one device. The production API must filter responses and never rely on UI filtering for authorization.
5. Add real asynchronous loading, retries, cancellation, pagination, and user-facing request errors when implementing the network adapter. Do not add artificial loading delays to demo actions.

The existing backend users module alone does not implement this mobile workflow. Pickups, offers, collection confirmation, messages, and notifications need actual backend contracts before an API adapter can be functional. No assumed endpoint has been wired into the app.

## Data contracts to agree on

| Domain | Required server behavior |
| --- | --- |
| Account | Household or verified buyer role, account status, authorized profile |
| Pickup | Category, estimated weight, owner, location codes, street/purok, time window, status, optional photo URL |
| Offer | Pickup, buyer, price/kg; household accepts exactly one atomically |
| Collection | Assigned buyer records actual weight, final agreed price and cash acknowledgement; owner confirms or disputes |
| Conversation | Authorized participants only; separate conversation per household/buyer pair |
| Notifications | Authorized in-app records and Socket.IO real-time delivery |

`Pickup.toJson()` is a proposed domain serialization for planning, not a guarantee of the current backend schema. The app retains both display names and PSGC codes selected from its bundled Bohol snapshot. `AppUser.locationPayload` has the four location code fields used by the users schema; new pickups also retain the selected codes. Send these codes to the real API and use names only for display. Region VII and Bohol defaults should be enforced consistently in the API and app. Current backend location routes require an LGU admin; add suitable public registration lookups or retain the bundled snapshot rather than embedding admin credentials in Flutter.

## Workflow and integrity

```text
Open -> Accepted -> On the way -> Arrived -> Awaiting confirmation -> Completed
  |        |                                        |
  +--------+-> Cancelled                             +-> Disputed
```

Use atomic server-side offer acceptance to prevent two assigned buyers. Validate ownership, transitions, positive finite amounts, and duplicate submissions. Use a decimal representation for stored prices and computed totals on the server; client totals are a preview.

Photos are currently optional bytes in memory. The real adapter should upload to an authenticated storage endpoint, persist only its returned path/URL, and validate file size/type server-side. Do not store large base64 images in the users or pickups tables.

The demo conversation is grouped per pickup, appropriate only for this single-device preview. Before production, introduce a conversation ID per buyer/household pair and isolate its messages. Implement the existing backend's JWT authorization scheme rather than exposing database credentials in Flutter.

Maps render with Google Maps. Photon supplies locality/reverse-address estimates and OSRM supplies road routes; an Android SDK key does not authorize Google Geocoding or Routes web services. Saved pins continue through the existing authenticated profile/pickup API. See [map configuration](maps.md) for provider separation and platform keys.
