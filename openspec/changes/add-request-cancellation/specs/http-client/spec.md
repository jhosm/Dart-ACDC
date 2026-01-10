## ADDED Requirements
### Requirement: Request Cancellation
The library SHALL support cancellation of in-flight HTTP requests.

#### Scenario: Cancel a specific request
- **WHEN** a developer passes a `CancelToken` to a request
- **AND** calls `token.cancel()` while the request is pending
- **THEN** the request is aborted immediately
- **AND** the `Future` completes with an error of type `DioExceptionType.cancel`
- **AND** resources associated with the connection are released

#### Scenario: Cancel triggers interceptor cleanup
- **WHEN** a request is canceled
- **THEN** any active interceptors stop processing the request
- **AND** logging indicates the request was canceled (not failed)

#### Scenario: Cancel all requests
- **WHEN** a developer needs to cancel all pending requests (e.g., user logout)
- **THEN** `dio.cancelAll()` (extension method) is available
#### Scenario: Internal Request Tracking
- **WHEN** a request is started
- **THEN** its `CancelToken` is registered in an internal tracker
- **AND** when the request completes (success or error), the token is unregistered
- **AND** this enables `cancelAll()` to locate active tokens

#### Scenario: Shared Request Cancellation (Deduplication)
- **WHEN** a request is deduplicated (multiple callers await the same future)
- **AND** one caller cancels their request
- **THEN** the underlying network request is **NOT** cancelled if other callers are still waiting
- **AND** the cancelling caller receives a cancellation error immediately
- **AND** if **ALL** callers cancel, the underlying network request IS cancelled
- **AND** resources are released only when no observers remain
