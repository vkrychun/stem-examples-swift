import SwiftUI
import StemRuntimeSDK
import StemJSON
import StemDependencies

struct AppEntry: Identifiable, Equatable, Hashable {
    let module: JSONCatalog.Module
    var render: StemRender?

    var id: String { module.rawValue }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ContentView: View {

    private let standaloneRenderer = StemRuntime()
        .register(FirebaseRepository.self, as: AppRepositoryType.firebase)
        .register(LocationService.self, as: AppServiceType.location)

    private let embeddedRenderer = StemRuntime()
        .navigationEmbedded()

    @State private var apps: [AppEntry] = []
    @State private var modalModule: AppEntry?
    // `.fullScreenCover(isPresented:)` — not `(item:)`: the item variant
    // re-creates the module on every parent-state change and wipes SDK state.
    @State private var isModalPresented: Bool = false
    @State private var embeddedModule: AppEntry?
    @State private var closeTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(apps) { app in
                        ModuleTile(
                            iconName: app.module.iconName,
                            title: app.module.displayName,
                            subtitle: app.module.subtitle,
                            color: app.module.iconColor
                        )
                        .onTapGesture { open(app) }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Stem Examples")
            .navigationDestination(item: $embeddedModule) { entry in
                if let render = entry.render {
                    render
                }
            }
            .fullScreenCover(isPresented: $isModalPresented) {
                Group {
                    if let render = modalModule?.render {
                        render
                    }
                }
            }
            .onChange(of: isModalPresented) { _, presented in
                if !presented {
                    closeTask?.cancel()
                    closeTask = nil
                    modalModule = nil
                }
            }
            .onChange(of: modalModule) { _, entry in
                guard let entry, let render = entry.render else {
                    closeTask?.cancel()
                    closeTask = nil
                    return
                }
                closeTask = Task {
                    for await value in standaloneRenderer.stream(for: "onClose", from: render) {
                        guard let closed = value as? Bool, closed else { continue }
                        await standaloneRenderer.kill(render)
                        markKilled(render.id)
                        isModalPresented = false
                        break
                    }
                }
            }
        }
        .task { await validateAll() }
    }

    @MainActor
    private func validateAll() async {
        var entries: [AppEntry] = []
        for module in JSONCatalog.Module.allCases {
            let renderer = module.isEmbedded ? embeddedRenderer : standaloneRenderer
            guard let data = try? JSONCatalog.data(for: module),
                  let render = try? await renderer.validate(data: data, ignore: [.bingo]).get()
            else { continue }
            entries.append(AppEntry(module: module, render: render))
        }
        apps = entries
    }

    private func open(_ app: AppEntry) {
        guard let idx = apps.firstIndex(where: { $0.id == app.id }) else { return }

        if apps[idx].render == nil {
            Task {
                let renderer = app.module.isEmbedded ? embeddedRenderer : standaloneRenderer
                guard let data = try? JSONCatalog.data(for: app.module),
                      let render = try? await renderer.validate(data: data).get()
                else { return }
                apps[idx].render = render
                present(apps[idx])
            }
        } else {
            present(apps[idx])
        }
    }

    private func present(_ app: AppEntry) {
        if app.module.isEmbedded {
            embeddedModule = app
        } else {
            // Set modalModule before isModalPresented so the onChange observer
            // can wire the onClose stream to a non-nil render.
            modalModule = app
            isModalPresented = true
        }
    }

    private func markKilled(_ id: String) {
        if let idx = apps.firstIndex(where: { $0.render?.id == id }) {
            apps[idx].render = nil
        }
    }
}

private extension JSONCatalog.Module {
    /// Modules whose navigation participates in the host's stack.
    var isEmbedded: Bool { false }
}

private struct ModuleTile: View {

    let iconName: String
    let title: String
    let subtitle: String
    let color: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundStyle(tileColor)
                .frame(height: 40)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tileColor: Color {
        switch color {
        case "orange": .orange; case "purple": .purple; case "blue": .blue
        case "green": .green; case "teal": .teal; case "indigo": .indigo
        case "pink": .pink; case "brown": .brown; case "red": .red
        case "mint": .mint; default: .accentColor
        }
    }
}

