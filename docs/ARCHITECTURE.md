# XDisplay Architecture

## Product Goal

XDisplay aims to turn an iPhone into a wired secondary display for macOS with a workflow close to Duet Display:

- User installs one macOS app and one iPhone app.
- User connects iPhone to Mac with a cable.
- macOS exposes a virtual display to the system.
- macOS renders desktop content into that virtual display.
- The virtual display frames are encoded and streamed to the iPhone.
- The iPhone decodes and presents the stream full-screen with high sharpness, low latency, and a target of 60 FPS or better.

## Product Constraints

- Phase 1 is wired only. No Wi-Fi, no Bluetooth pairing flow, no touch input.
- The UX must stay simple: install apps, grant permissions, connect cable, choose resolution, start.
- Latency matters more than feature count.
- The architecture must support a future upgrade to touch forwarding, Apple Pencil, audio, and wireless transport.

## Hard Technical Reality

Two parts of a true Duet-style product are high-risk:

1. True virtual display creation on modern macOS is not exposed through a clean, well-supported public app API.
2. Direct high-throughput wired app-to-app communication between a macOS app and an iPhone app over USB is not exposed through a simple public SDK path for normal App Store-style apps.

Because of that, the codebase must be built around replaceable interfaces:

- `VirtualDisplayProvider`
- `FrameCapturePipeline`
- `Transport`
- `DecoderRenderer`

That lets us build the host/client apps now while isolating the high-risk modules behind protocol boundaries.

## Recommended Distribution Strategy

Assume from day one that this product may require distribution outside the Mac App Store, likely with Developer ID signing for the macOS host. The iPhone app may also end up constrained by Apple platform rules depending on the final transport choice.

## Recommended Tech Stack

### macOS Host App

- Language: Swift 6.2
- UI: SwiftUI
- Capture: `ScreenCaptureKit`
- Encode: `VideoToolbox`
- Render/control loop: `CoreVideo` and `Metal` as needed
- Logging: `os.Logger`
- App lifecycle: SwiftUI app

### iPhone Client App

- Language: Swift 6.2
- UI: SwiftUI
- Decode: `VideoToolbox`
- Presentation: `AVSampleBufferDisplayLayer` first, `Metal` renderer later if needed
- Orientation: landscape-first full-screen viewer

### Shared Core

- Session model
- Device capability negotiation
- Control-plane messages
- Transport abstraction
- Pixel/stream configuration

## Architecture Overview

```text
macOS Host App
  -> VirtualDisplayProvider
  -> VirtualDisplayFrameSource
  -> VideoEncoder
  -> WiredTransport
  -> ControlChannel

iPhone Client App
  -> WiredTransport
  -> ControlChannel
  -> VideoDecoder
  -> DisplayRenderer
```

## User Flow

1. User launches both apps.
2. iPhone shows a waiting screen and basic device info.
3. Mac detects the connected phone over the transport layer.
4. Mac and iPhone negotiate:
   - codec
   - resolution
   - refresh rate
   - color format
5. Mac creates a virtual display session.
6. macOS begins rendering desktop content into the virtual display.
7. Host app captures that display stream, encodes frames, and transmits them.
8. iPhone decodes and displays the stream full-screen.

## Best Initial Technical Choices

### Virtual Display Strategy

Use a protocol-based abstraction:

- `VirtualDisplayProvider`: public contract used by the app
- `StubVirtualDisplayProvider`: current buildable placeholder
- `PrivateAPIVirtualDisplayProvider`: experimental implementation behind compile flags

Reason:

- We can build the product flow now.
- We can run local development without the private driver path.
- We isolate the most volatile code into one module.

### Capture Strategy

Once the virtual display exists, capture only that display using `ScreenCaptureKit`.

Reason:

- Avoid capturing the whole desktop when only the virtual display is needed.
- Preserve resolution control.
- Keep pipeline aligned with future multi-display support.

### Codec Strategy

Start with `H.264` low-latency hardware encode/decode.

Reason:

- Broad hardware support
- Easier interoperability
- Lower integration risk for the first working path

Upgrade path:

- Add `HEVC` as an optional negotiated codec after stability work

### Transport Strategy

Code against a transport interface with these implementations:

- `LoopbackTransport`: local dev and simulator testing
- `NetworkTransport`: fallback debug mode over LAN
- `WiredTransport`: production goal for USB path

Reason:

- Wired transport is the highest uncertainty after virtual display.
- We need the rest of the app to progress without blocking on it.

### Render Strategy on iPhone

Start with `AVSampleBufferDisplayLayer`.

Reason:

- Fastest path to a stable hardware-decoded viewer
- Less custom GPU code early on

Upgrade later:

- `Metal` renderer if display timing or custom post-processing requires tighter control

## Logic For The Simplest User Experience

The simplest usable flow should be:

1. Install host app on Mac.
2. Install client app on iPhone.
3. Open both apps once and grant permissions.
4. Connect cable.
5. Press `Start Display` on Mac.
6. iPhone automatically enters viewer mode.

Do not require the user to:

- manually pick Bonjour services
- type IP addresses
- choose multiple codecs
- configure advanced stream settings on first run

Expose only:

- resolution
- target refresh rate
- quality mode

Everything else should stay automatic.

## Repository Layout

```text
docs/
  ARCHITECTURE.md

Sources/
  DisplayCore/
  HostApp/
  ClientApp/

XDisplay.xcodeproj
project.yml
```

## Milestones

### Milestone 1: Buildable Skeleton

- Shared models and protocols
- Host app shell
- Client app shell
- Transport abstraction
- Virtual display abstraction

### Milestone 2: Local End-to-End Pipeline

- Loopback transport
- Mock frame source
- Real encoder/decoder contracts
- Full-screen viewer on iPhone

### Milestone 3: macOS Capture Pipeline

- `ScreenCaptureKit` integration
- Frame pacing
- Encoded stream packets

### Milestone 4: Experimental Wired Transport

- Mac side wired device discovery
- Session bootstrap
- Throughput and latency measurement

### Milestone 5: Experimental Virtual Display Provider

- Prove whether modern macOS can expose a stable virtual display path for this product
- If private APIs or low-level driver pieces are required, isolate them into a dedicated module

### Milestone 6: Real Session Integration

- Connect virtual display -> capture -> encode -> transport -> decode -> viewer

## Immediate Engineering Tasks

1. Create the cross-platform project.
2. Define shared session and transport contracts.
3. Add host-side `VirtualDisplayManager` abstraction.
4. Add host-side capture pipeline abstraction.
5. Add client-side decoder and renderer abstraction.
6. Make both apps compile and show session state.
7. Add loopback mode so product logic can be exercised before wired transport exists.
8. Add benchmark hooks for FPS, frame drops, encode time, decode time, and end-to-end latency.

## Known Risks

- True virtual display may depend on deprecated, unsupported, or private paths.
- Wired Mac-to-iPhone transport may require non-public integration details.
- App Store distribution may not be viable for the full product.
- 60 FPS at high resolution may require aggressive tuning of pixel formats, GOP settings, and copy avoidance.

## Decision For This Repository

This repository will proceed with:

- public SwiftUI app shells
- production-oriented abstractions
- placeholders for the risky modules
- a path to end-to-end testing before the hardest integrations land

That is the fastest path that keeps the architecture honest.
