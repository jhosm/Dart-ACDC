# Change: Add Request Deduplication

## Why
Prevents redundant network calls when multiple components request the same resource simultaneously (e.g., fetching user profile on startup).

## What Changes
- Implement `DeduplicationInterceptor`
- Add deduplication logic based on request key (Method + URI + Options + Headers + Data)
- Exclude `CancelToken` from key
- Disable deduplication for `ResponseType.stream`
- Return `Future` that resolves to the result of the in-flight request for duplicates
- Add configuration to `AcdcClientBuilder` to enable/disable (default enabled)
- Support per-request disable via `Options`

## Impact
- New file: `lib/src/interceptors/deduplication_interceptor.dart`
- Modified: `lib/src/builder/acdc_client_builder.dart`

