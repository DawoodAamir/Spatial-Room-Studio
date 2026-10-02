# Privacy

The working draft and saved layouts are JSON files in the app's private Application Support directory. There are no accounts, analytics, advertising, custom backend, or cloud database.

Starting a SharePlay review shares the initial layout through Apple's Group Activities service. **Send current layout** shares another snapshot with the active group. Snapshots include the layout title, creation date, furniture identifiers, types, finishes, positions, rotations, and lighting preset. Review titles before sharing. Incoming snapshots remain separate until you explicitly save a copy.

The app requests no camera, microphone, room-mapping, hand-tracking, or environmental-sensing data. RealityKit receives system-targeted interaction events. The mixed immersive view is a virtual concept room; it is not a scan of your surroundings.

The SharePlay entitlement enables system group sessions. Physical-device signing and service availability are controlled by Apple. Debug tests use a separate library selected by a validated random identifier; this override is excluded from Release builds.
