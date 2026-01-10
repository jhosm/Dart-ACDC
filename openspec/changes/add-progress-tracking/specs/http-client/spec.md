## ADDED Requirements
### Requirement: Progress Tracking
The library SHALL provide progress updates for request sending (uploads) and response receiving (downloads).

#### Scenario: Upload progress
- **WHEN** making a request with a body (e.g., POST file upload)
- **AND** an `onSendProgress` callback is provided
- **THEN** the callback is invoked periodically with `count` and `total` bytes sent
- **AND** this allows updating UI progress bars

#### Scenario: Download progress
- **WHEN** receiving a response body
- **AND** an `onReceiveProgress` callback is provided
- **THEN** the callback is invoked periodically with `count` and `total` bytes received
- **AND** this allows updating UI progress bars
