import Foundation

public enum FurnitureKind: String, Codable, CaseIterable, Sendable {
  case sofa, chair, table, shelf
  public var title: String { rawValue.capitalized }
  public var width: Float {
    switch self {
    case .sofa: 1.8
    case .chair: 0.75
    case .table: 1.1
    case .shelf: 1.2
    }
  }
  public var depth: Float {
    switch self {
    case .sofa: 0.85
    case .chair: 0.8
    case .table: 0.6
    case .shelf: 0.35
    }
  }
  public var height: Float {
    switch self {
    case .sofa, .chair: 0.85
    case .table: 0.42
    case .shelf: 1.5
    }
  }
}
public enum FurnitureFinish: String, Codable, CaseIterable, Sendable {
  case sage, clay, sand, charcoal
}
public struct Furniture: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var kind: FurnitureKind
  public var finish: FurnitureFinish
  public var x: Float
  public var z: Float
  public var rotation: Float
  public init(kind: FurnitureKind, x: Float = 0, z: Float = 0) {
    id = UUID()
    self.kind = kind
    finish = .sage
    self.x = x
    self.z = z
    rotation = 0
  }
}
public enum RoomLighting: String, Codable, CaseIterable, Sendable { case daylight, warm, studio }
public struct RoomLayout: Identifiable, Codable, Equatable, Sendable {
  public var id = UUID()
  public var title: String
  public var items: [Furniture]
  public var created = Date()
  public var formatVersion = 1
  public var lighting = RoomLighting.daylight
  public init(title: String, items: [Furniture] = []) {
    self.title = title
    self.items = items
  }
  public static var sample: RoomLayout {
    RoomLayout(
      title: "Quiet corner",
      items: [
        Furniture(kind: .sofa, x: 0, z: -1.25), Furniture(kind: .table, x: 0, z: 0),
        Furniture(kind: .chair, x: 1.15, z: 0.7),
      ])
  }
  public func validate() throws {
    guard formatVersion == 1, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      title.count <= 100,
      items.count <= 24, Set(items.map(\.id)).count == items.count,
      items.allSatisfy({
        $0.x.isFinite && $0.z.isFinite && $0.rotation.isFinite && abs($0.x) <= 2 && abs($0.z) <= 2
          && abs($0.rotation) <= 360
      })
    else { throw RoomError.invalidLayout }
  }
  public func moved(id: UUID, x: Float, z: Float) -> RoomLayout {
    guard x.isFinite, z.isFinite, let index = items.firstIndex(where: { $0.id == id }) else {
      return self
    }
    var result = self
    result.items[index].x = min(2, max(-2, x))
    result.items[index].z = min(2, max(-2, z))
    return result
  }
  public var footprintWarning: Bool {
    items.contains { item in
      let angle = item.rotation * .pi / 180
      let width = abs(cos(angle)) * item.kind.width + abs(sin(angle)) * item.kind.depth
      let depth = abs(sin(angle)) * item.kind.width + abs(cos(angle)) * item.kind.depth
      return abs(item.x) + width / 2 > 2 || abs(item.z) + depth / 2 > 2
    }
  }
}
public enum RoomError: LocalizedError, Sendable {
  case invalidLayout, libraryFull
  public var errorDescription: String? {
    switch self {
    case .invalidLayout:
      "The layout has unsupported or invalid values. Use up to 24 furniture pieces and a title of 1–100 characters."
    case .libraryFull: "This library has reached its 100 saved-layout limit."
    }
  }
}
public actor RoomStore {
  let url: URL
  public init(url: URL) { self.url = url }
  public func load() throws -> [RoomLayout] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) < 2_000_000 else {
      throw RoomError.invalidLayout
    }
    let layouts = try JSONDecoder().decode([RoomLayout].self, from: Data(contentsOf: url))
    guard layouts.count <= 100, Set(layouts.map(\.id)).count == layouts.count else {
      throw RoomError.invalidLayout
    }
    for layout in layouts { try layout.validate() }
    return layouts
  }
  public func saveCopy(_ layout: RoomLayout) throws -> [RoomLayout] {
    try layout.validate()
    var layouts = try load()
    guard layouts.count < 100 else { throw RoomError.libraryFull }
    var copy = layout
    copy.id = UUID()
    copy.created = Date()
    layouts.insert(copy, at: 0)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(layouts).write(to: url, options: .atomic)
    return layouts
  }
}

/// Ordered snapshots converge without merging coordinates from different reviews.
public struct ReviewSnapshot: Codable, Equatable, Sendable {
  public let counter: Int
  public let author: UUID
  public let layout: RoomLayout
  public init(counter: Int, author: UUID, layout: RoomLayout) {
    self.counter = counter
    self.author = author
    self.layout = layout
  }
  public func supersedes(_ other: ReviewSnapshot?) -> Bool {
    guard counter >= 0, counter < 1_000_000, (try? layout.validate()) != nil else { return false }
    guard let other else { return true }
    return counter > other.counter
      || (counter == other.counter && author.uuidString > other.author.uuidString)
  }
}

public actor DraftStore {
  let url: URL
  var revision: UInt64 = 0
  public init(url: URL) { self.url = url }
  public func load() throws -> RoomLayout? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) < 100_000 else {
      throw RoomError.invalidLayout
    }
    let draft = try JSONDecoder().decode(RoomLayout.self, from: Data(contentsOf: url))
    try draft.validate()
    return draft
  }
  public func save(_ draft: RoomLayout, revision next: UInt64) throws {
    try draft.validate()
    guard next >= revision else { return }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(draft).write(to: url, options: .atomic)
    revision = next
  }
}
