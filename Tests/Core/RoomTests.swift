import Foundation
import Testing

@testable import RoomCore

@Test func draftAndCopiesRemainIndependent() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let store = RoomStore(url: root.appendingPathComponent("Layouts.json"))
  let drafts = DraftStore(url: root.appendingPathComponent("Draft.json"))
  let original = RoomLayout.sample
  _ = try await store.saveCopy(original)
  var edited = original
  edited.title = "Warm reading room"
  edited.items[0].finish = .clay
  edited.lighting = .warm
  try await drafts.save(edited, revision: 2)
  try await drafts.save(original, revision: 1)
  #expect(try await drafts.load() == edited)
  let reloaded = try await store.load()
  #expect(reloaded.count == 1)
  #expect(reloaded[0].id != original.id)
  #expect(reloaded[0].items == original.items)
  #expect(reloaded[0].lighting == .daylight)
}
@Test func invalidAndOutOfBoundsTransforms() throws {
  var layout = RoomLayout.sample
  layout.items[0].x = .nan
  #expect(throws: RoomError.self) { try layout.validate() }
  layout = .sample
  let moved = layout.moved(id: layout.items[0].id, x: 10, z: -10)
  #expect(moved.items[0].x == 2 && moved.items[0].z == -2)
  #expect(moved.footprintWarning)
  #expect(layout.moved(id: layout.items[0].id, x: .infinity, z: 0) == layout)
  layout.items.append(layout.items[0])
  #expect(throws: RoomError.self) { try layout.validate() }
}
@Test func deterministicConcurrentReviewOrdering() throws {
  let lower = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  let higher = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
  let first = ReviewSnapshot(counter: 5, author: lower, layout: .sample)
  let second = ReviewSnapshot(counter: 5, author: higher, layout: .sample)
  #expect(second.supersedes(first))
  #expect(!first.supersedes(second))
  #expect(!second.supersedes(second))
  #expect(!ReviewSnapshot(counter: -1, author: higher, layout: .sample).supersedes(nil))
  var invalid = RoomLayout.sample
  invalid.title = ""
  #expect(!ReviewSnapshot(counter: 6, author: higher, layout: invalid).supersedes(second))
}
