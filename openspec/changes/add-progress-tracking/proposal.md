# Change: Add Progress Tracking

## Why
Users need feedback during large implementations like file uploads or downloads.

## What Changes
- Expose `onSendProgress` and `onReceiveProgress` callbacks in `AcdcClient` methods
- Ensure callbacks propagate from Dio

## Impact
- Affected specs: `http-client`
- Affected code: `AcdcClient` methods
