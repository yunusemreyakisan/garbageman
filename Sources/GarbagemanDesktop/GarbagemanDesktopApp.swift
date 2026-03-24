import SwiftUI

@main
struct GarbagemanDesktopApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("Garbageman") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 560)
        }
        .defaultSize(width: 1160, height: 720)
    }
}
