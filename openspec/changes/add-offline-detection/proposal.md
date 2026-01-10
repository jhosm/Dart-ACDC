# Change: Add Offline Detection

## Why
Mobile apps frequently encounter unstable network conditions. The library should provide a unified way to detect offline state and potentially queue or fail fast, rather than waiting for timeouts.

## What Changes
- Add `NetworkInfo` interface and implementation
- Integrate `connectivity_plus` or similar package
- Expose current network state stream
- Optional: Interceptor to block requests when offline (unless cache available)

## Impact
- Affected specs: `network-info` (new)
- Affected code: New `NetworkInfo` class, `AcdcClientBuilder`
