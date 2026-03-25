# XDisplay

XDisplay is a wired iPhone-as-secondary-display prototype for macOS.

The project explores a `Duet Display`-style architecture with:

- a macOS host app
- an iPhone client app
- a virtual extended display on macOS
- wired USB transport
- real-time capture, encode, decode, and presentation

This repository is a working prototype, not a production release.

## What It Does

- Creates a virtual extended display on macOS
- Streams that display to an iPhone over cable
- Uses a dedicated macOS host app and iPhone client app
- Includes performance profiles and resolution presets for testing
- Provides a menu bar utility on macOS so the host can keep running after the main window closes

## Current Status

What works today:

- macOS host app builds and runs
- iPhone client app builds and runs
- virtual display creation on macOS
- wired USB session setup
- real-time video streaming from Mac to iPhone
- basic host/client UI for configuration and testing

What is still experimental:

- long-session stability
- quality tuning across different Macs and iPhones
- full release-level cleanup of platform-specific warnings
- broader device compatibility validation

## Architecture

High-level flow:

1. The macOS host creates a virtual display.
2. The host captures frames from that display.
3. Frames are encoded and sent over a wired transport.
4. The iPhone client receives, decodes, and displays the stream fullscreen.

Main modules:

- `Sources/HostApp`
  macOS app, host UI, virtual display, capture pipeline
- `Sources/ClientApp`
  iPhone app, client UI, decode/render pipeline
- `Sources/DisplayCore`
  shared session, transport, protocol, logging, and design utilities

Supporting documents:

- [ARCHITECTURE.md](/Users/macbookprom1/Desktop/EDisplay/docs/ARCHITECTURE.md)
- [IMPLEMENTATION_PLAN.md](/Users/macbookprom1/Desktop/EDisplay/docs/IMPLEMENTATION_PLAN.md)
- [RESTART_ARCHITECTURE.md](/Users/macbookprom1/Desktop/EDisplay/docs/RESTART_ARCHITECTURE.md)
- [FEASIBILITY_GATES.md](/Users/macbookprom1/Desktop/EDisplay/docs/FEASIBILITY_GATES.md)
- [WIRED_TRANSPORT_SPIKE.md](/Users/macbookprom1/Desktop/EDisplay/docs/WIRED_TRANSPORT_SPIKE.md)
- [USB_TRANSPORT_OPTIONS.md](/Users/macbookprom1/Desktop/EDisplay/docs/USB_TRANSPORT_OPTIONS.md)

## Tech Stack

- `Swift 6`
- `SwiftUI`
- `ScreenCaptureKit`
- `VideoToolbox`
- `Network`
- `XcodeGen`

## Quick Start

Requirements:

- macOS with Xcode installed
- an iPhone running a recent iOS version
- USB cable between Mac and iPhone

Generate the Xcode project:

```bash
xcodegen generate
```

Open the project:

```bash
open XDisplay.xcodeproj
```

Build from Terminal:

```bash
xcodebuild -project XDisplay.xcodeproj -scheme XDisplayHost -configuration Debug build
xcodebuild -project XDisplay.xcodeproj -scheme XDisplayClient -configuration Debug -destination 'generic/platform=iOS' build
```

## Running the Prototype

1. Build and run `XDisplayClient` on the iPhone.
2. Build and run `XDisplayHost` on the Mac.
3. Connect the iPhone with a cable.
4. Start the host session.
5. Connect from the client.

Notes:

- The host may require `Screen Recording` permission on macOS.
- This project is intended for local testing and iteration, not App Store distribution.

## Repository Structure

```text
.
├── Sources
│   ├── ClientApp
│   ├── DisplayCore
│   └── HostApp
├── docs
├── project.yml
└── XDisplay.xcodeproj
```

## Design Goals

- Cable-first workflow
- Simple host and client UI
- High frame rate
- Low latency
- Clear separation between host logic, client logic, and shared protocol code

## Known Limitations

- macOS virtual display support is implementation-sensitive
- performance varies by hardware
- some platform APIs used here are not yet hardened for production release behavior
- the prototype still needs additional release cleanup before broad sharing outside developer testing

## Roadmap

- improve performance consistency
- reduce remaining rendering and platform warnings
- strengthen reconnect and lifecycle handling
- continue polishing host and client UX
- evaluate portability of the architecture to additional host platforms

## Contributing

This repo is currently organized around rapid prototyping and architecture validation.

If you share the project with others, it helps to frame it as:

- a technical prototype
- a cable-first secondary display experiment
- a macOS host + iPhone client architecture study

## License

No license file is included yet. Add one before public distribution outside private sharing.
