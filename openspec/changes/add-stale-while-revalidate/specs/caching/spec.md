## ADDED Requirements
### Requirement: Stale-While-Revalidate Strategy
The library SHALL support the Stale-While-Revalidate caching strategy to improve perceived performance.

#### Scenario: Return stale data immediately
- **WHEN** a request matches a stale cache entry (expired but within stale window)
- **THEN** the cached response is returned immediately to the caller
- **AND** a background network request is triggered to refresh the data
- **AND** the cache is updated when the network request completes

#### Scenario: Standard Future behavior (Optimistic)
- **WHEN** a standard `dio.get()` request matches a stale cache entry
- **THEN** the `Future` completes IMMEDIATELY with the stale response
- **AND** a background network request is triggered to refresh the cache
- **AND** the caller sees the fast stale data and does not wait for the network
- **AND** if the background refresh fails, it is logged but does not throw to the caller (who already got data)

#### Scenario: Reactive Updates (Stream)
- **WHEN** using a `streamRequest()` method (new API)
- **THEN** the stream emits the stale value first (if available)
- **AND** emits the fresh value when the background request completes
- **AND** if background refresh fails, the stream emits an error event

#### Scenario: Cache-Control header support
- **WHEN** the server sends `Cache-Control: stale-while-revalidate=300`
- **THEN** the library respects the 300-second window for serving stale data
- **AND** updates the cache in the background
