# XDisplay

XDisplay turns an iPhone into a wired secondary display for macOS.

It is built around a simple idea: plug in your iPhone with a cable, launch the Mac host and iPhone client, and use the iPhone as an extended screen.

## Main Features

- Wired iPhone-as-secondary-display workflow
- Extended display on macOS, not just a basic viewer
- Dedicated Mac host app and iPhone client app
- High refresh-rate focused streaming
- Performance and resolution presets for testing
- Lightweight host utility with menu bar support

## Highlights

- Cable-first setup
- Clean host and client UI
- Real-time display streaming
- Built for low-latency experimentation
- Optimized for quick testing on Mac + iPhone

## Current State

XDisplay is a working prototype.

What is already working:

- macOS host app
- iPhone client app
- virtual extended display on macOS
- wired USB session
- fullscreen display output on iPhone

This project is still under active development and is not a production release yet.

## Quick Start

Requirements:

- macOS with Xcode
- iPhone
- USB cable

Generate the project:

```bash
xcodegen generate
```

Open in Xcode:

```bash
open XDisplay.xcodeproj
```

Build:

```bash
xcodebuild -project XDisplay.xcodeproj -scheme XDisplayHost -configuration Debug build
xcodebuild -project XDisplay.xcodeproj -scheme XDisplayClient -configuration Debug -destination 'generic/platform=iOS' build
```

## How To Run

1. Run `XDisplayClient` on iPhone.
2. Run `XDisplayHost` on Mac.
3. Connect iPhone with cable.
4. Start the host session.
5. Connect from the client.

## Project Structure

```text
Sources/
  ClientApp/
  DisplayCore/
  HostApp/
docs/
project.yml
XDisplay.xcodeproj
```

## Notes

- The host may request `Screen Recording` permission on macOS.
- This repo is currently intended for private testing, iteration, and sharing with collaborators.

## License

No license file is included yet.
