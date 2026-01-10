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
