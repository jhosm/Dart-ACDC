## 1. Implementation
- [x] 1.1 Implement `ActiveRequestTracker` to store CancelTokens <!-- id: 5 -->
- [x] 1.2 Verify CancelToken propagation in existing interceptors <!-- id: 1 -->
- [x] 1.3 Add `cancelAll()` extension method <!-- id: 2 -->
- [x] 1.4 Test cancellation with active network requests <!-- id: 3 -->
- [x] 1.5 Test cancellation cleanup (resources released) <!-- id: 4 -->

## Scenario Coverage

### ✅ Scenario: Cancel a specific request
- Dio's native `CancelToken` support is leveraged
- Requests can be cancelled by calling `token.cancel()`
- Returns `DioExceptionType.cancel` error
- Resources released via `CancellationInterceptor`

### ✅ Scenario: Cancel triggers interceptor cleanup
- `CancellationInterceptor` removes tokens from tracker on cancel
- Verified in unit tests

### ✅ Scenario: Cancel all requests
- `dio.cancelAll()` extension method implemented
- Uses `ActiveRequestTracker.cancelAll()`
- Tested in integration tests

### ✅ Scenario: Internal Request Tracking
- `ActiveRequestTracker` registers tokens on request start
- Unregisters on completion (response or error)
- Enables `cancelAll()` functionality
- Verified in unit and integration tests
