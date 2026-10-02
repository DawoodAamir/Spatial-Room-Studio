# Spatial Room Studio

A native visionOS workspace for arranging original furniture, comparing room layouts, and reviewing a selected layout over SharePlay.

## Try it

Open **Spatial Room Studio.xcodeproj** with Xcode 27. Run on the visionOS 27 simulator, or select your own development team to run on Apple Vision Pro. The bundle identifier is `com.dd.spatialroomstudio`; no signing team is embedded.

Start with the **Quiet corner** concept room. Add a sofa, chair, table, or shelf, select its finish, and adjust its position and rotation with the native controls. **View in 3D** opens a tabletop volume where you can select and drag furniture. **Open full-scale view** presents the concept room in a mixed immersive space; close it from the main window.

The room is a four-meter square. Boundary warnings flag furniture that extends outside it. This is a concept planner, not a room scanner, measurement tool, collision checker, or construction drawing. Furniture dimensions are illustrative. The app does not collect camera frames, map your home, or request environmental sensing access.

## Save and compare

Draft changes persist locally. **Save a copy** creates an independent snapshot. Expand **Saved layouts**, choose **Compare** to see an alternative beside the current plan, or **Use layout** to continue editing it. Undo retains the last 30 edits for the current app session. The library holds up to 100 saved copies and each layout allows 24 furniture pieces.

Daylight, warm, and studio presets change the virtual directional light. These are designed lighting presets, not captured physical-space lighting. Original procedural furniture uses physically based materials and system hover feedback.

## SharePlay review

Start a FaceTime call with another person who has this app, then choose **Start SharePlay review**. The initial layout is included in the activity. During a review, **Send current layout** explicitly publishes the current snapshot. Incoming snapshots appear separately and can be saved as local copies; they never silently replace the working draft.

Reliable group messages carry validated layouts and ordered revision stamps. Concurrent snapshots use a deterministic tie-break, and active participants relay the latest review to newcomers. This is shared review, not simultaneous coordinate editing, shared physical-world anchoring, or an access-controlled approval system. End-to-end multi-headset behavior still needs device verification.

## Engineering

Swift 6 complete concurrency, main-actor observable state, isolated atomic storage, bounded file decoding, stale-draft write rejection, original layered app icons, and no third-party packages. Native windows, volumes, immersive spaces, RealityKit collision/input components, and alternative position controls support different ways of working.

```sh
swift test
swift test -c release
xcodebuild -project 'Spatial Room Studio.xcodeproj' -scheme 'Spatial Room Studio' -configuration Release -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build
bash Scripts/test-ui.sh
```

The native test requires the visionOS 27 simulator runtime. [Verification](Docs/Verification.md) distinguishes simulator checks from physical-device checks. See [privacy](PRIVACY.md) and [contributing](CONTRIBUTING.md). MIT licensed.

References: [visionOS design](https://developer.apple.com/design/human-interface-guidelines/designing-for-visionos), [RealityKit](https://developer.apple.com/documentation/realitykit), and [Group Activities](https://developer.apple.com/documentation/groupactivities).
