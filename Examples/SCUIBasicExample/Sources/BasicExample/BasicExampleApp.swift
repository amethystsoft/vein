import Foundation
import SwiftCrossUI
import DefaultBackend
import VeinSCUI

@main
struct VeinTestEnvironmentApp: App {
    @State var toggleQueries = false
    let modelContainer: ModelContainer
    
    init() {
        do {
            let containerPath = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            
            let dbDir = containerPath.relativePath.replacingOccurrences(of: "%20", with: " ").appending("/BSCUITest/InternalData")
            
            let dbPath = dbDir.appending("/db.sqlite3")
            print(dbDir)
            try FileManager.default.createDirectory(
                atPath: dbDir,
                withIntermediateDirectories: true
            )
            
            self.modelContainer = try ModelContainer(
                TestSchemaV0_0_1.self,
                migration: TestMigration.self,
                at: dbPath,
                appID: Bundle.main.bundleIdentifier ?? "de.amethystsoft.vein-scui.BasicExample"
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    var body: some Scene {
        WindowGroup("VeinTest") {
            VeinContainer {
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
