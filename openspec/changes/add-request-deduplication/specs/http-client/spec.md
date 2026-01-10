## ADDED Requirements
### Requirement: Request Deduplication
The library SHALL deduplicate simultaneous identical idempotent requests (GET, HEAD).

#### Definition: Identical Request
A request is considered identical if it shares the:
- HTTP Method
- URI (including query parameters)
- Request Body (data)
- Request Headers
- Request Options (timeouts, responseType, etc.)
  - **Excluding**: `CancelToken` (unique per request)

#### Scenario: Concurrent GET requests
- **WHEN** two identical GET requests are made simultaneously (before the first completes)
- **THEN** only one actual network request is sent
- **AND** both callers receive the same `Response` object
- **AND** this reduces network traffic and server load

#### Scenario: Sequential requests
- **WHEN** a request completes
- **AND** another identical request is made
- **THEN** a new network request is sent (unless cached)
- **AND** deduplication only applies to in-flight requests

#### Scenario: Non-idempotent requests
- **WHEN** multiple POST/PUT/DELETE requests are made
- **THEN** they are NOT deduplicated
- **AND** each request results in a separate network call
- **AND** this preserves side effects

#### Scenario: Stream Requests
- **WHEN** a request uses `responseType: stream`
- **THEN** it is NOT deduplicated
- **AND** each request results in a separate network connection

#### Scenario: Primary Cancellation
- **WHEN** the primary request (the one that triggered the network call) is cancelled via its `CancelToken`
- **THEN** the network request is cancelled
- **AND** all secondary requests fail with a cancellation error (since the shared future throws)

#### Scenario: Secondary Cancellation
- **WHEN** a secondary request is cancelled via its `CancelToken`
- **THEN** the secondary request fails/completes with a cancellation error
- **AND** the primary network request CONTINUES
- **AND** other observers continue to wait for the result

#### Scenario: Configuration
- **WHEN** the user sets `deduplication: false` in `AcdcClientBuilder`
- **THEN** no deduplication occurs for any request
- **WHEN** the user passes `extra: {'deduplicate': false}` in request options
- **THEN** that specific request is not deduplicated and does not join any existing in-flight request
