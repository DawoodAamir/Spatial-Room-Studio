import RealityKit
import SwiftUI

@main struct SpatialRoomStudioApp: App {
  @State private var model = RoomModel()
  var body: some SwiftUI.Scene {
    WindowGroup {
      RoomWorkspace(model: model).frame(minWidth: 900, minHeight: 640)
    }.defaultSize(width: 1100, height: 740)
    WindowGroup(id: "room-model") { RoomScene(model: model, fullScale: false) }
      .windowStyle(.volumetric).defaultSize(width: 1.1, height: 0.8, depth: 1.1, in: .meters)
    ImmersiveSpace(id: "room-space") {
      RoomScene(model: model, fullScale: true).onDisappear { model.immersive = false }
    }.immersionStyle(selection: .constant(.mixed), in: .mixed)
  }
}

struct RoomWorkspace: View {
  @Bindable var model: RoomModel
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openImmersiveSpace) private var openSpace
  @Environment(\.dismissImmersiveSpace) private var dismissSpace
  @State private var title = ""
  var body: some View {
    NavigationSplitView {
      List(selection: $model.selectedID) {
        Section("Furniture · \(model.draft.items.count)/24") {
          ForEach(model.draft.items) { item in
            NavigationLink(value: item.id) {
              Label(item.kind.title, systemImage: symbol(item.kind))
            }
          }
        }
        Section("Add furniture") {
          ForEach(FurnitureKind.allCases, id: \.self) { kind in
            Button {
              model.add(kind)
            } label: {
              Label(kind.title, systemImage: "plus")
            }.accessibilityIdentifier("add-" + kind.rawValue).disabled(
              model.draft.items.count >= 24)
          }
        }
      }.navigationTitle("Room Studio").navigationSplitViewColumnWidth(230)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            VStack(alignment: .leading) {
              Text(model.draft.title).font(.largeTitle.bold())
              Text("4 × 4 meter concept room").foregroundStyle(.secondary)
            }
            Spacer()
            Button("View in 3D", systemImage: "cube.transparent") { openWindow(id: "room-model") }
          }
          HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
              Text("Working layout").font(.headline)
              FloorPlan(layout: model.draft, selectedID: model.selectedID)
            }
            if let comparison = model.comparison {
              VStack(alignment: .leading) {
                Text(comparison.title).font(.headline)
                FloorPlan(layout: comparison, selectedID: nil)
              }
            }
          }
          Picker(
            "Lighting",
            selection: Binding(
              get: { model.draft.lighting },
              set: { value in
                var next = model.draft
                next.lighting = value
                model.update(next)
              })
          ) {
            ForEach(RoomLighting.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
          }.pickerStyle(.segmented)
          if model.draft.footprintWarning {
            Label(
              "Some furniture extends beyond the room boundary.",
              systemImage: "exclamationmark.triangle"
            ).foregroundStyle(.orange)
          }
          if let selected = model.selected { FurnitureControls(item: selected, model: model) }
          HStack {
            TextField("Layout name", text: $title).textFieldStyle(.roundedBorder)
              .accessibilityIdentifier("layoutName")
            Button("Rename") {
              var next = model.draft
              next.title = title
              model.update(next)
            }.disabled(
              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 100)
            Button("Save a copy") { Task { await model.saveCopy() } }.disabled(model.saving)
          }
          DisclosureGroup("Saved layouts · \(model.saved.count)") {
            ForEach(model.saved) { layout in
              HStack {
                VStack(alignment: .leading) {
                  Text(layout.title)
                  Text(layout.created.formatted(date: .abbreviated, time: .shortened)).font(
                    .caption
                  ).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Compare") { model.comparisonID = layout.id }
                Button("Use layout") {
                  model.update(layout)
                  model.selectedID = nil
                  title = layout.title
                }
              }.padding(.vertical, 6)
            }
          }
          if model.comparisonID != nil { Button("End comparison") { model.comparisonID = nil } }
          GroupBox("Shared review") {
            VStack(alignment: .leading, spacing: 12) {
              if model.joined {
                Text(
                  "\(model.participantCount) participants · Snapshots are shared only when you send them."
                )
                HStack {
                  Button("Send current layout") { Task { await model.sendLayout() } }.disabled(model.sending)
                  Button("Leave review") { model.leaveReview() }
                }
                if let shared = model.shared {
                  Text("Shared: \(shared.title)").font(.headline)
                  FloorPlan(layout: shared, selectedID: nil).frame(maxWidth: 320)
                  Button("Save shared layout as a copy") { Task { await model.saveCopy(shared) } }
                    .disabled(model.saving)
                }
              } else {
                Text(
                  "Review a layout over SharePlay. Incoming layouts stay separate from your working draft."
                ).foregroundStyle(.secondary)
                Button("Start SharePlay review") { Task { await model.startReview() } }.disabled(
                  model.sharing)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
          Text(
            "Draft changes save locally. Use saved copies to compare alternatives. Furniture is conceptual geometry; this app does not scan your room or measure clearance."
          ).font(.footnote).foregroundStyle(.secondary)
        }.padding(28)
      }
      .toolbar {
        Button("Undo", systemImage: "arrow.uturn.backward", action: model.undo).disabled(
          !model.canUndo)
        Button(
          model.immersive ? "Close full-scale view" : "Open full-scale view",
          systemImage: "vision.pro"
        ) {
          Task {
            model.changingSpace = true
            defer { model.changingSpace = false }
            if model.immersive {
              await dismissSpace()
              model.immersive = false
            } else {
              switch await openSpace(id: "room-space") {
              case .opened: model.immersive = true
              case .userCancelled: break
              case .error:
                model.error = "The full-scale view could not open. Try the tabletop view instead."
              @unknown default: break
              }
            }
          }
        }.disabled(model.changingSpace)
      }
    }
    .task {
      await model.load()
      title = model.draft.title
    }
    .alert(
      "Unable to complete request",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK") { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
  }
  func symbol(_ kind: FurnitureKind) -> String {
    switch kind {
    case .sofa: "sofa"
    case .chair: "chair"
    case .table: "table.furniture"
    case .shelf: "cabinet"
    }
  }
}

struct FurnitureControls: View {
  let item: Furniture
  let model: RoomModel
  var body: some View {
    GroupBox(item.kind.title) {
      VStack(spacing: 14) {
        HStack {
          Picker(
            "Finish",
            selection: Binding(
              get: { item.finish }, set: { value in model.changeSelected { $0.finish = value } })
          ) {
            ForEach(FurnitureFinish.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
          }
          Spacer()
          Button("Remove", systemImage: "minus.circle", action: model.removeSelected)
        }
        Stepper(
          "Across: \(item.x.formatted(.number.precision(.fractionLength(1)))) m",
          value: Binding(get: { item.x }, set: { value in model.changeSelected { $0.x = value } }),
          in: -2...2, step: 0.1)
        Stepper(
          "Depth: \(item.z.formatted(.number.precision(.fractionLength(1)))) m",
          value: Binding(get: { item.z }, set: { value in model.changeSelected { $0.z = value } }),
          in: -2...2, step: 0.1)
        Stepper(
          "Rotation: \(Int(item.rotation))°",
          value: Binding(
            get: { item.rotation }, set: { value in model.changeSelected { $0.rotation = value } }),
          in: -180...180, step: 15)
      }.padding(8)
    }
  }
}

struct FloorPlan: View {
  let layout: RoomLayout
  let selectedID: UUID?
  var body: some View {
    GeometryReader { geometry in
      let unit = geometry.size.width / 4.8
      ZStack {
        RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
        Rectangle().stroke(.secondary.opacity(0.4), lineWidth: 1).frame(
          width: unit * 4, height: unit * 4)
        ForEach(layout.items) { item in
          RoundedRectangle(cornerRadius: 4)
            .fill(finishColor(item.finish).opacity(0.8))
            .overlay {
              if item.id == selectedID {
                RoundedRectangle(cornerRadius: 4).stroke(.white, lineWidth: 3)
              }
            }
            .overlay {
              Text(item.kind.title).font(.caption2.bold()).foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            }
            .frame(width: CGFloat(item.kind.width) * unit, height: CGFloat(item.kind.depth) * unit)
            .rotationEffect(.degrees(Double(item.rotation)))
            .offset(x: CGFloat(item.x) * unit, y: CGFloat(item.z) * unit)
        }
      }
    }.aspectRatio(1, contentMode: .fit).frame(maxWidth: 390)
      .accessibilityElement(children: .ignore).accessibilityLabel(
        "\(layout.title), top-down plan with \(layout.items.count) furniture pieces")
  }
}

func finishColor(_ finish: FurnitureFinish) -> Color {
  switch finish {
  case .sage: Color(red: 0.34, green: 0.48, blue: 0.43)
  case .clay: Color(red: 0.64, green: 0.38, blue: 0.28)
  case .sand: Color(red: 0.65, green: 0.56, blue: 0.40)
  case .charcoal: Color(white: 0.24)
  }
}

struct RoomScene: View {
  let model: RoomModel
  let fullScale: Bool
  @State private var root = Entity()
  @State private var cache = RoomRenderCache()
  var body: some View {
    RealityView { content in
      root.name = "Room"
      root.scale = SIMD3<Float>(repeating: fullScale ? 1 : 0.22)
      root.position = fullScale ? [0, 0, -3] : [0, -0.25, 0]
      content.add(root)
      rebuild()
    } update: { _ in
      if cache.layout != model.draft { rebuild() }
    }
    .gesture(
      SpatialTapGesture().targetedToAnyEntity().onEnded { value in
        model.selectedID = UUID(uuidString: value.entity.name)
      }
    )
    .gesture(
      DragGesture().targetedToAnyEntity().onChanged { value in
        guard let id = UUID(uuidString: value.entity.name),
          let item = model.draft.items.first(where: { $0.id == id })
        else { return }
        let delta = value.convert(value.translation3D, from: .local, to: root)
        value.entity.position = [
          min(2, max(-2, item.x + Float(delta.x))), 0, min(2, max(-2, item.z + Float(delta.z))),
        ]
      }.onEnded { value in
        guard let id = UUID(uuidString: value.entity.name),
          let item = model.draft.items.first(where: { $0.id == id })
        else { return }
        let delta = value.convert(value.translation3D, from: .local, to: root)
        model.update(
          model.draft.moved(id: id, x: item.x + Float(delta.x), z: item.z + Float(delta.z)))
      }
    )
    .accessibilityIdentifier("roomScene")
    .accessibilityLabel(
      "Room furniture. Use the main window's position controls as an alternative to dragging.")
  }
  @MainActor private func rebuild() {
    root.children.removeAll()
    let floor = ModelEntity(
      mesh: .generateBox(size: [4, 0.015, 4]),
      materials: [SimpleMaterial(color: .init(white: 0.65, alpha: 0.25), isMetallic: false)])
    floor.position.y = -0.015
    root.addChild(floor)
    for item in model.draft.items {
      let furniture = makeFurniture(item)
      furniture.position = [item.x, 0, item.z]
      furniture.orientation = simd_quatf(angle: item.rotation * .pi / 180, axis: [0, 1, 0])
      root.addChild(furniture)
    }
    let light = DirectionalLight()
    light.light.intensity = model.draft.lighting == .studio ? 1800 : 900
    light.light.color =
      model.draft.lighting == .warm ? UIColor(red: 1, green: 0.83, blue: 0.65, alpha: 1) : .white
    light.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0, 0])
    root.addChild(light)
    cache.layout = model.draft
  }
  @MainActor private func makeFurniture(_ item: Furniture) -> Entity {
    let group = Entity()
    group.name = item.id.uuidString
    let material = SimpleMaterial(
      color: UIColor(finishColor(item.finish)), roughness: 0.85, isMetallic: false)
    let wood = SimpleMaterial(
      color: UIColor(red: 0.45, green: 0.32, blue: 0.21, alpha: 1), roughness: 0.7,
      isMetallic: false)
    func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ material: SimpleMaterial) {
      let part = ModelEntity(
        mesh: .generateBox(size: size, cornerRadius: 0.015), materials: [material])
      part.position = position
      group.addChild(part)
    }
    let width = item.kind.width
    let depth = item.kind.depth
    switch item.kind {
    case .sofa, .chair:
      box([width, 0.22, depth], [0, 0.38, 0], material)
      box([width, 0.45, 0.15], [0, 0.625, -depth / 2 + 0.075], material)
      for x in [-width / 2 + 0.06, width / 2 - 0.06] {
        box([0.12, 0.22, depth], [x, 0.59, 0], material)
        for z in [-depth / 2 + 0.08, depth / 2 - 0.08] {
          box([0.07, 0.27, 0.07], [x, 0.135, z], wood)
        }
      }
    case .table:
      box([width, 0.06, depth], [0, 0.39, 0], wood)
      for x in [-width / 2 + 0.08, width / 2 - 0.08] {
        for z in [-depth / 2 + 0.08, depth / 2 - 0.08] {
          box([0.055, 0.36, 0.055], [x, 0.18, z], wood)
        }
      }
    case .shelf:
      for x in [-width / 2 + 0.03, width / 2 - 0.03] {
        box([0.06, 1.5, depth], [x, 0.75, 0], wood)
      }
      for y: Float in [0.04, 0.5, 0.98, 1.46] { box([width, 0.05, depth], [0, y, 0], wood) }
    }
    let shape = ShapeResource.generateBox(size: [width, item.kind.height, depth]).offsetBy(
      translation: [0, item.kind.height / 2, 0])
    group.components.set(CollisionComponent(shapes: [shape]))
    group.components.set(InputTargetComponent())
    group.components.set(HoverEffectComponent())
    return group
  }
}

@MainActor private final class RoomRenderCache { var layout: RoomLayout? }
