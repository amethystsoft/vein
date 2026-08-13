import SwiftCrossUI
import DefaultBackend
import VeinSCUI

@main
struct VeinTestEnvironmentApp: App {
    let modelContainer: ModelContainer

    init() {
        // Initialize ModelContainer
        self.modelContainer = initializedModelContainer
    }

    var body: some Scene {
        WindowGroup("VeinExample") {
            ContentView()
        }
    }
}
