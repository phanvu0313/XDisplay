# XDisplay Implementation Plan

## Current Status

- [x] Repository structure created
- [x] macOS host app skeleton created
- [x] iPhone client app skeleton created
- [x] Shared session and transport abstractions created
- [x] Xcode project generation wired up with XcodeGen
- [x] Host app build verified
- [x] Client app simulator build verified
- [ ] Real virtual display provider implemented
- [ ] Real wired USB transport implemented
- [ ] Real video encode/decode pipeline implemented
- [ ] End-to-end frame streaming implemented
- [x] Typed session phases and protocol envelopes added
- [x] Development loopback transport API added
- [x] Network transport over Bonjour and TCP added
- [x] Mock frame streaming scaffold added

## Step 1: Session Bootstrap

Goal:

- Let host and client move through deterministic session states.

Tasks:

- Expand control messages for capabilities and stream lifecycle.
- Add session IDs and protocol versioning.
- Add shared error codes.
- Add host/client state machines instead of ad-hoc status strings.

## Step 2: Development Transport

Goal:

- Prove end-to-end app behavior before USB transport exists.

Tasks:

- Implement `LoopbackTransport` for same-process development.
- Implement `NetworkTransport` for Mac-to-device debug over LAN.
- Add connection retry logic.
- Add structured logs for handshake timing.

## Step 3: Host Capture Pipeline

Goal:

- Stream frames from a known source on macOS.

Tasks:

- Add a mock frame source first.
- Integrate `ScreenCaptureKit` for a chosen display source.
- Add frame pacing.
- Add capture metrics: FPS, dropped frames, capture latency.

## Step 4: Video Pipeline

Goal:

- Move from raw frame placeholders to low-latency encoded video.

Tasks:

- Add host-side `VideoToolbox` encoder.
- Start with H.264 low-latency settings.
- Define NALU or sample packet framing.
- Add client-side `VideoToolbox` decoder.
- Render first through `AVSampleBufferDisplayLayer`.

## Step 5: Wired Transport Spike

Goal:

- Prove whether the product can sustain a cable-only Mac-to-iPhone session.

Tasks:

- Investigate device discovery over cable.
- Investigate session bootstrap over the cable path.
- Measure throughput and latency under sustained streaming.
- Decide whether the transport path requires unsupported or non-public integration.

Exit criteria:

- Either we have a stable wired transport prototype, or we formally document that the transport path is blocked by platform restrictions.

## Step 6: Virtual Display Spike

Goal:

- Prove whether a true extended-display experience is viable on current macOS.

Tasks:

- Research the current viable virtual display path on the local SDK and runtime.
- Prototype a dedicated `PrivateAPIVirtualDisplayProvider`.
- Keep all risky code isolated in a separate module boundary.
- Measure stability across display attach, detach, sleep, unlock, and resolution changes.

Exit criteria:

- Either the system can expose a stable extra display, or we downgrade the product to a non-extended viewer architecture.

## Step 7: Integrated Pipeline

Goal:

- Connect all pieces into the first real display session.

Tasks:

- Virtual display created on host.
- Host captures only that display.
- Host encodes and streams frames.
- Client decodes and presents frames.
- Host and client report metrics in UI.

## Step 8: Product Hardening

Goal:

- Make the flow usable outside development.

Tasks:

- Add onboarding and permission guidance.
- Add reconnect handling.
- Add device capability negotiation.
- Add performance profiles: battery saver, balanced, sharp.
- Add diagnostics export for field debugging.

## Immediate Next Code Tasks

1. Replace placeholder session strings with typed host/client state machines.
2. Implement `LoopbackTransport` with in-memory async channels.
3. Add a mock frame producer on macOS.
4. Add a client-side sample renderer path.
5. Add protocol-versioned handshake messages.
