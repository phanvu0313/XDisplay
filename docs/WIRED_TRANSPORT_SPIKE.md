# Wired Transport Spike

## Current Direction

The real product path needs a cable-first bridge between the macOS host app and the iPhone client app.

The repo now treats that bridge as a separate runtime module:

- `WiredTransport`
- `WiredTransportBridge`
- `WiredTransportBridgeFactory`

## What Exists Now

### macOS Host

- uses `CoreDeviceWiredTransportBridge`
- probes attached devices via `xcrun devicectl list devices --json-output -`
- confirms whether a paired iPhone or iPad is visible over cable
- fails with a specific message describing the detected device and the missing tunnel

### iPhone Client

- uses `IOSAppWiredTransportBridge`
- fails immediately with a specific message that the real USB app-side runtime is not implemented

## Why This Matters

This is the first honest cable path:

- the host no longer claims wired is ready
- the repo can distinguish `no device attached` from `device attached but no app tunnel`
- the eventual USB implementation can plug into `WiredTransportBridge` without changing app UI or session code

## Remaining Work

1. Choose and prove a real app-to-app USB transport path.
2. Implement control-plane framing over that bridge.
3. Add sustained video packet delivery over the same bridge.
4. Replace development `network` preview with the cable path.
