# USB Transport Options

## Summary

The product target requires a Mac app and an iPhone app to exchange control and video data over cable.

With public Apple APIs alone, that path is blocked.

## Confirmed Platform Constraints

### 1. iOS has no general-purpose USB API for apps

Apple DTS has stated that iOS does not provide general USB access for apps.

Impact:

- the iPhone app cannot just open a raw USB channel to the Mac app
- there is no public equivalent of a generic `USB socket` for app-to-app transport

### 2. External Accessory is for MFi accessories

Apple documents `ExternalAccessory` as the framework for communication with an MFi accessory over Lightning or Bluetooth Classic.

Impact:

- a normal Mac app is not an MFi accessory
- `ExternalAccessory` is not the correct public path for Mac app <-> iPhone app cable transport

### 3. CoreDevice can see attached iPhones, but not expose an app data tunnel directly

`xcrun devicectl` proves the host can detect paired iPhones over cable.

Impact:

- host-side cable presence can be detected
- this does not solve the app-to-app data plane

## Practical Options

### Option A: Private tunnel path

Use an experimental private path based on the same lower-level device transport stack that Apple uses for device services.

Examples of the area to investigate:

- CoreDevice transport behavior
- usbmux/usbmuxd style tunneling
- app companion process on macOS

Tradeoffs:

- not App Store safe
- higher maintenance risk
- technically the most direct route to a Duet-style wired product

### Option B: Accessory path

Use a real MFi hardware accessory between Mac and iPhone.

Tradeoffs:

- changes the product fundamentally
- adds hardware dependency
- not suitable for the current goal

### Option C: Abandon cable-only for public APIs

Use local network transport and keep cable only as charging / physical attachment.

Tradeoffs:

- easiest public implementation
- does not satisfy the product goal

## Current Decision

The repo will continue under `Option A`.

That means:

1. Keep `WiredTransportBridge` as the abstraction boundary.
2. Use `CoreDevice` probing on macOS to confirm real device presence.
3. Build the next spike around a private or experimental Mac-side tunnel.
4. Do not pretend that `ExternalAccessory` solves the Mac <-> iPhone app transport problem.
