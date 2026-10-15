import SwiftUI

@main
struct SamsungRemoteApp: App {
    @State private var model = RemoteModel()

    var body: some Scene {
        MenuBarExtra("Samsung Remote", systemImage: "av.remote") {
            RootView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
