# XDisplay Restart Architecture

## Goal

Rebuild XDisplay around the actual product target:

- iPhone acts as a true secondary display for macOS
- wired-only in phase 1
- low-latency video pipeline
- no dependence on the current network mirror prototype

## Non-Goals

The following are explicitly not the target architecture:

- JPEG preview streaming
- network-first transport
- mirror-only viewer flow
- UI work that hides missing platform capabilities

## Hard Gates

The project succeeds only if all three gates are proven:

1. `Virtual display gate`
   macOS must expose a usable extra display surface to the system.

2. `Wired transport gate`
   Mac and iPhone must exchange control and video payloads over cable with enough throughput and acceptable latency.

3. `Video pipeline gate`
   Capture, encode, transfer, decode, and render must stay low-latency at 60 FPS class performance.

## Runtime Modules

### macOS Host

- `VirtualDisplayProvider`
- `FrameCapturePipeline`
- `VideoEncoder`
- `WiredTransport`
- `HostSessionRuntime`

### iPhone Client

- `WiredTransport`
- `VideoDecoder`
- `DisplayRenderer`
- `ClientSessionRuntime`

### Shared Core

- session state machine
- handshake protocol
- stream configuration
- transport packet framing

## Build Strategy

### Track A: Feasibility

Used to prove the hard gates:

- private or experimental virtual display provider
- cable transport bridge
- low-latency encoded stream path

### Track B: Product Shell

Used only after Track A is proven:

- simple host UI
- simple iPhone setup UI
- full-screen display mode

## Immediate Refactor Rules

1. Keep `network` and `loopback` code only as development scaffolding.
2. Do not let development transport pretend to be the production path.
3. Keep `wired` as the default selected mode.
4. Fail loudly and specifically when the real wired or virtual-display path is unavailable.
5. Keep the hard modules behind protocols so experiments do not infect app UI code.

## Required Abstractions

- `VirtualDisplayProvider`
- `WiredTransportBridge`
- `FrameCapturePipeline`
- `VideoEncodingPipeline`
- `VideoDecodingPipeline`
- `DisplayRenderingPipeline`

## Milestones

1. Isolate all real-path abstractions.
2. Replace placeholder success paths with explicit capability errors.
3. Add host/client session runtimes for the real path.
4. Implement wired transport bridge spike.
5. Implement virtual display spike.
6. Implement H.264 low-latency pipeline.
