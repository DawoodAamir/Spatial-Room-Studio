import Combine
@preconcurrency import GroupActivities
import Observation
import SwiftUI

struct RoomReviewActivity: GroupActivity, Sendable {
  static let activityIdentifier = "com.dd.spatialroomstudio.review"
  let layout: RoomLayout
  var metadata: GroupActivityMetadata {
    var value = GroupActivityMetadata()
    value.title = "Review a room layout"
    value.type = .createTogether
    value.subtitle = layout.title
    return value
  }
}

@MainActor @Observable final class RoomModel {
  private(set) var draft = RoomLayout.sample
  var saved: [RoomLayout] = []
  var selectedID: UUID?
  var comparisonID: UUID?
  var error: String?
  var saving = false
  var immersive = false
  var changingSpace = false
  var shared: RoomLayout?
  var joined = false
  var participantCount = 0
  var sharing = false
  var sending = false
  var canUndo: Bool { !history.isEmpty }
  private var history: [RoomLayout] = []
  private var draftRevision: UInt64 = 0
  private var loaded = false
  private let library: RoomStore
  private let drafts: DraftStore
  private var session: GroupSession<RoomReviewActivity>?
  private var messenger: GroupSessionMessenger?
  private var listener: Task<Void, Never>?
  private var sessionTasks: [Task<Void, Never>] = []
  private var latest: ReviewSnapshot?
  init() {
    var root = URL.applicationSupportDirectory.appendingPathComponent("SpatialRoomStudio")
    #if DEBUG
      if let id = ProcessInfo.processInfo.environment["ROOM_TEST_STORE"],
        UUID(uuidString: id) != nil
      {
        root.appendPathComponent("Tests/" + id)
      }
    #endif
    library = RoomStore(url: root.appendingPathComponent("Layouts.json"))
    drafts = DraftStore(url: root.appendingPathComponent("Draft.json"))
  }
  var selected: Furniture? { draft.items.first { $0.id == selectedID } }
  var comparison: RoomLayout? { saved.first { $0.id == comparisonID } }
  func load() async {
    guard !loaded else { return }
    loaded = true
    do {
      saved = try await library.load()
      if let draft = try await drafts.load() { self.draft = draft }
    } catch { self.error = error.localizedDescription }
    listen()
  }
  func update(_ next: RoomLayout) {
    do { try next.validate() } catch {
      self.error = error.localizedDescription
      return
    }
    guard next != draft else { return }
    history.append(draft)
    if history.count > 30 { history.removeFirst() }
    draft = next
    persistDraft()
  }
  func undo() {
    guard let previous = history.popLast() else { return }
    draft = previous
    persistDraft()
  }
  private func persistDraft() {
    draftRevision += 1
    let revision = draftRevision
    let value = draft
    Task {
      do { try await drafts.save(value, revision: revision) } catch {
        self.error = error.localizedDescription
      }
    }
  }
  func add(_ kind: FurnitureKind) {
    guard draft.items.count < 24 else { return }
    var next = draft
    let item = Furniture(kind: kind)
    next.items.append(item)
    update(next)
    selectedID = item.id
  }
  func changeSelected(_ change: (inout Furniture) -> Void) {
    guard let index = draft.items.firstIndex(where: { $0.id == selectedID }) else { return }
    var next = draft
    change(&next.items[index])
    update(next)
  }
  func removeSelected() {
    var next = draft
    next.items.removeAll { $0.id == selectedID }
    update(next)
    selectedID = nil
  }
  func saveCopy(_ layout: RoomLayout? = nil) async {
    guard !saving else { return }
    saving = true
    defer { saving = false }
    do { saved = try await library.saveCopy(layout ?? draft) } catch {
      self.error = error.localizedDescription
    }
  }
  func startReview() async {
    guard !sharing else { return }
    sharing = true
    defer { sharing = false }
    do {
      let activity = RoomReviewActivity(layout: draft)
      switch await activity.prepareForActivation() {
      case .activationPreferred: _ = try await activity.activate()
      case .activationDisabled:
        error =
          "Start a FaceTime call with another person who has Spatial Room Studio, then try SharePlay again."
      case .cancelled: break
      @unknown default: break
      }
    } catch { self.error = error.localizedDescription }
  }
  func sendLayout() async {
    guard !sending, let session, let messenger else { return }
    sending = true
    defer { sending = false }
    let snapshot = ReviewSnapshot(
      counter: (latest?.counter ?? 0) + 1, author: session.localParticipant.id, layout: draft)
    guard snapshot.supersedes(latest) else { return }
    do {
      try await messenger.send(snapshot)
      guard self.session?.id == session.id, snapshot.supersedes(latest) else { return }
      latest = snapshot
      shared = snapshot.layout
    } catch { if self.session?.id == session.id { self.error = error.localizedDescription } }
  }
  func leaveReview() {
    session?.leave()
    clearSession()
  }
  private func clearSession() {
    sessionTasks.forEach { $0.cancel() }
    sessionTasks = []
    session = nil
    messenger = nil
    joined = false
    participantCount = 0
    latest = nil
    shared = nil
  }
  private func listen() {
    guard listener == nil else { return }
    listener = Task {
      for await session in RoomReviewActivity.sessions() {
        guard !Task.isCancelled else { return }
        do { try session.activity.layout.validate() } catch {
          session.leave()
          continue
        }
        self.session?.leave()
        clearSession()
        self.session = session
        shared = session.activity.layout
        let messenger = GroupSessionMessenger(session: session)
        self.messenger = messenger
        sessionTasks.append(
          Task {
            for await (snapshot, context) in messenger.messages(of: ReviewSnapshot.self) {
              guard !Task.isCancelled, self.session?.id == session.id else { return }
              guard session.activeParticipants.contains(context.source),
                snapshot.supersedes(self.latest)
              else { continue }
              self.latest = snapshot
              self.shared = snapshot.layout
            }
          })
        sessionTasks.append(
          Task {
            for await state in session.$state.values {
              guard !Task.isCancelled, self.session?.id == session.id else { return }
              switch state {
              case .joined: self.joined = true
              case .invalidated:
                self.clearSession()
                return
              case .waiting: self.joined = false
              @unknown default: self.joined = false
              }
            }
          })
        sessionTasks.append(
          Task {
            var previous: Set<Participant> = []
            for await participants in session.$activeParticipants.values {
              guard !Task.isCancelled, self.session?.id == session.id else { return }
              self.participantCount = participants.count
              let added = participants.subtracting(previous).subtracting([session.localParticipant])
              previous = participants
              if !added.isEmpty, let latest = self.latest {
                do { try await messenger.send(latest, to: .only(added)) } catch {
                  self.error = error.localizedDescription
                }
              }
            }
          })
        session.join()
      }
    }
  }
}
