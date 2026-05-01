import SwiftUI
import Combine
import StemRuntimeSDK

struct MainTabView: View {

    /// Single runtime shared across native + module surfaces. Native toggles
    /// fire `deviceToggled` events into the module via `trigger`; native views
    /// observe module state via `subscribe`.
    private let runtime = StemRuntime().navigationEmbedded()

    @State private var render: StemRender?
    @State private var devices: [Device] = []
    @State private var recentEvents: [ActivityEntry] = []
    @State private var activeCount = 0
    @State private var subscriptions: [AnyCancellable] = []
    @State private var selectedTab = 1 // default to Rooms so module mounts on launch

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    devices: devices,
                    activeCount: activeCount,
                    onToggle: { device in
                        runtime.trigger(
                            event: "deviceToggled",
                            data: ["id":        device.id,
                                   "name":      device.name,
                                   "on":        !device.on,
                                   "timestamp": Date().timeIntervalSince1970]
                        )
                    }
                )
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            NavigationStack {
                RoomsBrowserView(render: render)
            }
            .tabItem { Label("Rooms", systemImage: "square.grid.2x2.fill") }
            .tag(1)

            NavigationStack {
                ActivityView(entries: recentEvents)
            }
            .tabItem { Label("Activity", systemImage: "clock.fill") }
            .tag(2)
        }
        // Module's onCustom handler registers via SwiftUI's .onReceive when
        // its view mounts. Defaulting to the Rooms tab (tag 1) ensures the
        // module renders on launch so native triggers from the Home tab reach
        // the handler immediately.
        .task { await loadAndObserve() }
    }

    @MainActor
    private func loadAndObserve() async {
        guard let url = Bundle.main.url(forResource: "home", withExtension: "json"),
              let r = try? await runtime.validate(contentsOf: url).get()
        else { return }
        render = r

        subscriptions.append(runtime.subscribe(to: "devices", in: r) { value in
            guard let arr = value as? [[String: Any]] else { return }
            let parsed = arr.compactMap { Device(dict: $0) }
            Task { @MainActor in devices = parsed }
        })
        subscriptions.append(runtime.subscribe(to: "activeCount", in: r) { value in
            let count: Int? = if let i = value as? Int { i }
                              else if let d = value as? Double { Int(d) }
                              else { nil }
            Task { @MainActor in if let count { activeCount = count } }
        })
        subscriptions.append(runtime.subscribe(to: "recentEvents", in: r) { value in
            guard let arr = value as? [[String: Any]] else { return }
            let parsed = arr.compactMap(ActivityEntry.init(dict:))
            Task { @MainActor in recentEvents = parsed }
        })
    }
}

struct Device: Identifiable, Equatable {
    let id: String
    let name: String
    let room: String
    let kind: String
    let icon: String
    var on: Bool

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let room = dict["room"] as? String,
              let kind = dict["kind"] as? String,
              let icon = dict["icon"] as? String,
              let on = dict["on"] as? Bool
        else { return nil }
        self.id = id; self.name = name; self.room = room
        self.kind = kind; self.icon = icon; self.on = on
    }
}

struct ActivityEntry: Identifiable, Equatable {
    let id: String
    let deviceName: String
    let action: String
    let timestamp: Double

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let name = dict["deviceName"] as? String,
              let action = dict["action"] as? String
        else { return nil }
        self.id = id
        self.deviceName = name
        self.action = action
        if let d = dict["timestamp"] as? Double {
            self.timestamp = d
        } else if let date = dict["timestamp"] as? Date {
            self.timestamp = date.timeIntervalSince1970
        } else {
            self.timestamp = 0
        }
    }
}
