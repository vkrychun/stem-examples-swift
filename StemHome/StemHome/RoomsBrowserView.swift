import SwiftUI
import StemRuntimeSDK

struct RoomsBrowserView: View {

    let render: StemRender?

    var body: some View {
        if let render {
            render
        } else {
            ProgressView("Loading rooms…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
