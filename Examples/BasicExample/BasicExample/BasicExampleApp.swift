import SwiftUI
import Vein
import VeinSwiftUI

@main
struct VeinTestEnvironmentApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let containerPath = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            
            let dbDirURL = containerPath
                .appendingPathComponent("VeinSwiftUI")
                .appendingPathComponent("BasicExample")
                .appendingPathComponent("InternalData")
            
            let dbURL = dbDirURL.appendingPathComponent("db.sqlite3")
            print(dbDirURL.path)
            try FileManager.default.createDirectory(
                at: dbDirURL,
                withIntermediateDirectories: true
            )
            
            self.modelContainer = try ModelContainer(
                TestSchemaV0_0_1.self,
                migration: TestMigration.self,
                at: dbURL.path(),
                appID: Bundle.main.bundleIdentifier ?? "de.amethystsoft.vein-swiftui.BasicExample"
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    var body: some Scene {
        WindowGroup("VeinTest") {
            VeinContainer {
                // This is displayed here to make debugging and looking at
                // the db example easier.
                // NEVER do this in prod.
                Text(modelContainer.context.getDatabaseKey() ?? "no key")
                    .textSelection(.enabled)
                HStack {
                    ContentView()
                    #if !canImport(UIKit)
                    ContentView(predicate: #Predicate<Test> { test in
                        test.randomValue >= 500 && test.flag == true
                    })
                    #endif
                }
            }
            .modelContainer(modelContainer)
        }.defaultSize(width: 800, height: 600)
    }
}
