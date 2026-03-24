# Feasibility Gates

## Gate 1: Virtual Display

Questions:

- Can macOS expose a stable extra display from this app?
- Can resolution changes, attach, detach, sleep, and unlock be handled?

Exit condition:

- host can attach a usable display surface that macOS treats as an extended display target

## Gate 2: Wired Transport

Questions:

- Can host and client discover each other over cable?
- Can the transport carry sustained encoded video payloads?
- Is latency acceptable versus network fallback?

Exit condition:

- cable transport supports control-plane messages and sustained video packets

## Gate 3: Video Pipeline

Questions:

- Can host encode with low latency using hardware encode?
- Can client decode and render without visible hitching?
- Can the system sustain 60 FPS class delivery?

Exit condition:

- end-to-end wired stream is stable and latency is materially lower than the current preview path
