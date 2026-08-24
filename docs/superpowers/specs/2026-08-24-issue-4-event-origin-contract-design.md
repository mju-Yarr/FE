# Issue #4 Event Contract and Origin Fix Design

## Purpose

Fix the two remaining defects in GitHub issue #4 without adding a new user-facing feature:

1. Parse the backend `EventResponse.anchorMode` field instead of silently defaulting `depart_at` events to `arrive_by`.
2. Supply a registered default origin when the ordinary calendar form creates a physical event, so the backend can create its initial plan.

The `dwlBand: unknown` requirement is already implemented by PR #18 and is outside this change.

## Baseline and Scope

- Base revision: latest `origin/main` at design time, `935cb41`.
- Keep the legacy response key `anchor` readable for backward compatibility.
- Do not modify the time serialization work from PR #3.
- Do not add screens, endpoints, providers, dependencies, or eager place loading.
- Preserve existing map-draft and online-event behavior.

## Event Response Boundary

`Event.fromJson` is the shared boundary used by event detail, event list, next event, create response, and update response paths. It will normalize the response map before passing it to generated deserialization:

- If `anchorMode` is present, use it as the canonical value.
- Otherwise, fall back to the legacy `anchor` key.
- If neither exists, preserve the existing `EventAnchor.arriveBy` default.
- Keep `Event.toJson()` producing the existing Dart-side `anchor` key because `ApiEnsomRepository` already maps that value to the request field `anchorMode`.

This keeps compatibility logic centralized and avoids repeating response transformations in every repository method.

## Default Origin Resolution

The calendar form will resolve an origin immediately before calling `createEvent`, using the same `EnsomRepository` instance for both place lookup and event creation.

Resolution rules, in order:

1. If a map draft exists, return the draft's `originPlaceId` exactly as-is and do not call `fetchPlaces()`.
2. If the final event location state is not `requiredResolved`, return `null` and do not call `fetchPlaces()`.
3. For an ordinary physical event, call `fetchPlaces()` once.
4. Prefer the first place whose `isPrimary` is true.
5. If no place is primary, use the first returned place.
6. If the list is empty, return `null` and continue creating the event.
7. If place lookup fails, return `null` and continue creating the event so this enrichment does not turn an existing event-creation path into a new failure mode.

The resolver will be a small `@visibleForTesting` function near `EventFormScreen`. It is orchestration logic, not a new domain or repository abstraction.

## Data Flow

For an ordinary physical event:

`EventFormScreen._save` → construct final `Event(requiredResolved)` → lazy `fetchPlaces()` → choose primary/first ID → `createEvent(originPlaceId: ...)` → POST `/events` → backend initial-plan creation.

For map drafts and non-physical events, the existing path remains unchanged and does not perform a place lookup.

## Error Handling

- Malformed enum values continue to fail deserialization through the generated enum decoder; only the accepted key name changes.
- A place-list failure is treated as unavailable optional enrichment. Event creation still runs with `originPlaceId: null`.
- Existing event-create API errors continue through the current `EventFormScreen` error handling.

## Tests

Regression tests will prove:

- `anchorMode: depart_at` becomes `EventAnchor.departAt`.
- Legacy `anchor: depart_at` remains supported.
- When both keys exist, canonical `anchorMode` wins.
- Missing both keys preserves `arriveBy`.
- Ordinary physical events prefer a primary place.
- With no primary, the first place is used.
- Empty and failed place lookups return `null` without preventing creation.
- Online, undecided, and map-draft paths do not fetch places.
- A supplied `originPlaceId` reaches the POST `/events` request body.

The tests will use real model deserialization, a focused fake `EnsomRepository` for origin selection, and the existing HTTP-capturing repository test pattern for the wire payload.

## PR Completion Criteria

- All issue #4 completion criteria are either newly satisfied here or verified as already satisfied by PR #18.
- Focused regression tests pass after demonstrating RED against the unfixed baseline.
- Full Flutter tests pass.
- Flutter analyze introduces no new issue in changed files.
- Web release build succeeds.
- `git diff --check` succeeds.
- An independent code review reports no unresolved critical or important findings.
- The PR body uses `Closes #4`.
