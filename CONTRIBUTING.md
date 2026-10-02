# Contributing

Use Xcode 27. Keep views and scene entities on the main actor, persistence inside the storage actors, and shared payloads bounded and Sendable. Preserve the separation between local drafts and incoming review snapshots.

Run Debug/Release core tests, simulator/device builds, and the native workflow after interaction changes. Verify manipulation, comfort, accessibility, lifecycle, and SharePlay with physical headsets before claiming device readiness. Do not add private room data, credentials, or signing identities.

Regenerate the original layered icon with `swift Scripts/GenerateIcon.swift "$PWD"`. Furniture geometry is generated in RoomScene. Use focused Conventional Commits and update verification notes when checks change.
