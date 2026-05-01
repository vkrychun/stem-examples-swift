import SwiftUI
import StemRuntimeSDK

struct ContentView: View {

    private let runtime = StemRuntime()
    @State private var moduleView: AnyView?

    var body: some View {
        Group {
            if let moduleView {
                moduleView
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            guard let url = Bundle.main.url(forResource: "hello", withExtension: "json"),
                  let render = try? await runtime.validate(contentsOf: url).get()
            else { return }
            moduleView = AnyView(render)
        }
    }
}
