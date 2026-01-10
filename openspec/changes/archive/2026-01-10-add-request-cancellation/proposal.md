# Change: Add Request Cancellation

## Why
Users need the ability to cancel long-running requests (e.g., large file uploads, slow queries) to free up resources or navigate away from a screen without side effects.

## What Changes
- Add support for Dio `CancelToken`
- Expose cancellation mechanism via `AcdcClient` or return `CancelToken` from requests if wrapping
- Actually, Dio requests already take a `CancelToken`. This spec formalizes its usage and provides a simplified API if needed.
- Implement **Internal Request Tracker** to manage active `CancelToken`s for `cancelAll()` support
- Handle **Shared Request Cancellation** when combined with deduplication
- Ensure cancellation propagates to interceptors and network layer

## Impact
- Affected specs: `http-client`
- Affected code: Documentation, potentially wrapper methods
