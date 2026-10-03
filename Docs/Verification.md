# Verification

October 3, 2026. [Hosted run 37109015382](https://github.com/DawoodAamir/Spatial-Room-Studio/actions/runs/37109015382) passed for implementation `c032ca1`.

- Three core tests passed in Debug and Release: independent saved copies, stale draft writes, bounded coordinates, duplicate identifiers, boundary warnings, and deterministic shared snapshot ordering.
- Native visionOS 27 simulator and unsigned device Release builds passed with complete Swift 6 concurrency.
- The native UI workflow added furniture, saved and compared a copy, reopened the app to verify persistence, and opened the tabletop volume. Workspace and volume captures were taken while those scenes remained open, inspected, and published in the README.
- Local UI testing stalled during simulator startup; the successful UI run was hosted.

Physical headsets are required to verify comfortable full-scale placement, eye/hand interaction, passthrough, VoiceOver, spatial audio/system interruptions, and multi-person SharePlay. The simulator does not establish any of those results. No ARKit room capture or real-world measurement is implemented.
