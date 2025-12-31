# Error Handling Specification

## ADDED Requirements

### Requirement: Exception Hierarchy

The library SHALL define a custom exception hierarchy that categorizes HTTP errors into user-friendly types.

#### Scenario: Base exception type

- **WHEN** any HTTP error occurs
- **THEN** the thrown exception is a subtype of `AcdcException`
- **AND** the exception contains the original DioException for debugging

#### Scenario: Exception type categorization

- **WHEN** different HTTP errors occur
- **THEN** they are mapped to appropriate exception types:
  - Network errors (no connection, DNS failure) → `AcdcNetworkException`
  - Authentication errors (401, 403) → `AcdcAuthException`
  - Server errors (500, 502, 503, 504) → `AcdcServerException`
  - Client errors (400, 404, 422, etc.) → `AcdcClientException`
  - Cache errors → `AcdcCacheException`

### Requirement: HTTP Status Code Mapping

The library SHALL map HTTP status codes to specific exception types based on error category.

#### Scenario: 4xx client error mapping

- **WHEN** the server returns a 4xx status code (except 401/403)
- **THEN** an `AcdcClientException` is thrown
- **AND** the exception message includes the status code and response body

#### Scenario: 5xx server error mapping

- **WHEN** the server returns a 5xx status code
- **THEN** an `AcdcServerException` is thrown
- **AND** the exception message indicates a server-side problem

#### Scenario: 401/403 authentication error mapping

- **WHEN** the server returns a 401 or 403 status code
- **THEN** an `AcdcAuthException` is thrown
- **AND** the auth interceptor is notified for potential token refresh

### Requirement: Network Error Handling

The library SHALL detect and categorize network connectivity issues separately from HTTP errors.

#### Scenario: Connection timeout

- **WHEN** a request times out during connection
- **THEN** an `AcdcNetworkException` is thrown with type `connectionTimeout`
- **AND** the error message explains the timeout

#### Scenario: Receive timeout

- **WHEN** a request times out while receiving data
- **THEN** an `AcdcNetworkException` is thrown with type `receiveTimeout`
- **AND** the error message explains the timeout

#### Scenario: No internet connection

- **WHEN** the device has no internet connectivity
- **THEN** an `AcdcNetworkException` is thrown with type `connectionError`
- **AND** the error message suggests checking internet connection

### Requirement: User-Friendly Error Messages

The library SHALL provide actionable, user-friendly error messages for all exception types.

#### Scenario: Client error message

- **WHEN** a 400 Bad Request error occurs
- **THEN** the exception message includes "Invalid request"
- **AND** includes the response body for debugging

#### Scenario: Server error message

- **WHEN** a 500 Internal Server Error occurs
- **THEN** the exception message includes "Server error occurred"
- **AND** suggests retrying the request

#### Scenario: Network error message

- **WHEN** a connection timeout occurs
- **THEN** the exception message includes "Request timed out"
- **AND** suggests checking internet connection

### Requirement: Error Interceptor

The library SHALL provide an error interceptor that automatically converts DioException to ACDC exception types.

#### Scenario: Automatic error conversion

- **WHEN** Dio throws a DioException during a request
- **THEN** the error interceptor catches it
- **AND** converts it to the appropriate AcdcException subtype
- **AND** rethrows the ACDC exception
