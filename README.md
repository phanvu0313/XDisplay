# XDisplay

Wired iPhone-as-secondary-display project for macOS, structured toward a Duet-style architecture.

## Current Status

This repository now contains:

- an architecture plan in [docs/ARCHITECTURE.md](/Users/macbookprom1/Desktop/EDisplay/docs/ARCHITECTURE.md)
- a generated Xcode project spec in [project.yml](/Users/macbookprom1/Desktop/EDisplay/project.yml)
- a buildable macOS host app skeleton
- a buildable iPhone client app skeleton
- a shared core module for session and transport abstractions

## Next Steps

1. Generate the Xcode project with `xcodegen generate`.
2. Implement loopback and network test transport to validate session flow.
3. Replace the host-side virtual display stub with an experimental provider.
4. Add the real capture, encode, decode, and frame presentation pipeline.
