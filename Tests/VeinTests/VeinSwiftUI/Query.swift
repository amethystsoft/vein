#if TEST_SWIFTUI
import Foundation
import Testing
import SQLiteDB
import SwiftUI
@testable import Vein
@_spi(VeinTesting) import VeinSwiftUI

fileprivate typealias Test = V0_0_1.Test

@MainActor
struct QueryTestView: SwiftUI.View {
    @Query(#Predicate<Test> { _ in true })
    fileprivate var tests: [Test]
    
    fileprivate let onRender: ([Test]) -> Void
    
    var body: some SwiftUI.View {
        Text("Count: \(tests.count)")
            .onAppear {
                onRender(tests)
            }
            .onChange(of: tests) { _, newValue in
                onRender(newValue)
            }
    }
}

@MainActor
struct FilteredQueryTestView: SwiftUI.View {
    @Query(#Predicate<Test> { test in test.someValue.contains("i") })
    fileprivate var tests: [Test]
    
    fileprivate let onRender: ([Test]) -> Void
    
    var body: some SwiftUI.View {
        Text("Count: \(tests.count)")
            .onAppear {
                onRender(tests)
            }
            .onChange(of: tests) { _, newValue in
                onRender(newValue)
            }
    }
}

@Suite
@MainActor
struct QueryTests {
    @Test(.timeLimit(.minutes(1)))
    func queryIntegrationWithSwiftUI() async throws {
        let (container, models) = try seed()
        
        let (stream, continuation) = AsyncStream.makeStream(of: [V0_0_1.Test].self)
        
        let view = VeinContainer {
            QueryTestView { updatedTests in
                continuation.yield(updatedTests)
            }
        }
            .modelContainer(container)
        
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.layoutSubtreeIfNeeded()
        
        var iterator = stream.makeAsyncIterator()
        
        guard let initialResults = await iterator.next() else {
            Issue.record("Expected initial results")
            return
        }
        #expect(initialResults == models)
        
        try container.context.delete(models.first!)
        
        guard let resultAfterDelete = await iterator.next() else {
            Issue.record("Expected updated results after delete")
            return
        }
        #expect(resultAfterDelete == Array(models[1...]))
        
        try container.context.insert(models.first!)
        
        guard let resultsAfterReinsert = await iterator.next() else {
            Issue.record("Expected updated results after reinsert")
            return
        }
        #expect(resultsAfterReinsert == models)
        
        continuation.finish()
    }
    
    @Test(.timeLimit(.minutes(1)))
    func filteredQueryIntegrationWithSwiftUI() async throws {
        let (container, initialModels) = try seed()
        let models = initialModels.filter { $0.someValue.contains("i")}
        
        let (stream, continuation) = AsyncStream.makeStream(of: [V0_0_1.Test].self)
        
        let view = VeinContainer {
            FilteredQueryTestView { updatedTests in
                continuation.yield(updatedTests)
            }
        }
            .modelContainer(container)
        
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.layoutSubtreeIfNeeded()
        
        var iterator = stream.makeAsyncIterator()
        
        guard let initialResults = await iterator.next() else {
            Issue.record("Expected initial results")
            return
        }
        #expect(initialResults == models)
        
        try container.context.delete(models.first!)
        
        guard let resultAfterDelete = await iterator.next() else {
            Issue.record("Expected updated results after delete")
            return
        }
        #expect(resultAfterDelete == Array(models[1...]))
        
        try container.context.insert(models.first!)
        
        guard let resultsAfterReinsert = await iterator.next() else {
            Issue.record("Expected updated results after reinsert")
            return
        }
        #expect(resultsAfterReinsert == models)
        
        models.first!.someValue = "no letter you're look'n for here"
        
        // Not sure why this is needed, but in an app it works without,
        // so it's probably fine for now.
        /* Credits to https://gist.github.com/25A0/ba7d9bc7724cf157bc6c0e7909906aee
                           `````             `               ```                 ```````
         ```          `````````````````````````````      ```````````         ````````````
         ``` ``````` ```````````````  `````````` ````````````````       ``` ```` `````
         ```````````` ```       ````` ++.   .#@@@@  ````````   ````` ``  ```   ``````````
         ``````` `````   ```````   :@@@@@@@@@@@@@@@@@@@@@@::::::,:,,::::   `````` .@@:
         ```` ;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,,:`````````.::@@@@##@@@@@@@@@@
         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@#';,,@@@@@@@@@@@@@@@:::`````````.: @@@@@@@@@@@@@@@@
         @@@@@@@@@@@@                      @@@@@@@@@@@@@@@:::`` ``````,:`@@@@@@@@@@@@@@@@
         @@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@   @@@@@@@@@@@@@@@,::```` ````:: @@@@@@@@@@@@@@@@
         @@@@@@ #@@@@ @@@@@@@@#@@@@@@@@@   @@@@@@@@@@@@@@@:::`````` ``,, @@@@@@@@@@@@@@@@
         @@@@@   @@@@ @@@@@`  @@@@@@@ :;;  @@@@@@@@@@@@@@@:::`````````:, @@@@@@@@@@ @@@@@
         @@@@     @@@ @@@`   +@@@ @@ ;;;:.  ;,#@@@@@@@@@@@:::````` `` :: @@@@@@@@@@  ;@@@
         @@@      @@@ @@`    @@@@  @@:    :;;:#@@@@@@@@@@@:,:,,,,,,.`:::+@@@@@@@@@@+  #@@
         @@      `@@@ @      @@@    ;;;;;;;;`.::: @@@@@@@@`:::::::::::: @@@@@@@@@@@@   @@
         @@       @@@    '   @@:     ;;;:. ::;;;; ,`+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'   @@
          +   '   @@@   '';   @  ;'  @ ::;.`::;.@@    @@@@@@@@@@@@@@@@@@@,@@@@@@@@@    #
              '   @,@   '''      '''   :.@++@ : @    .@@@@@@@@@@@@@@@@@  @@@@@@@@@
              '  @@ ., '''''    ''     ;@,   @ .#@    `      .@@@@@@@:  `@@@@@@@@   ;
             `'  @@  `'''''''; ''      ;@    @`;:.;;;;:       @@@@@@  `  @@@@@@@   ''
         '    '  @@   ;'''''''''       :.@@@# ::;:;;;;::     @@@@@#  ',  .@@@@@`  `''.  '
         ''  ''  @'    '''''''';      ;;;;;;;;;:.``;::::;;..@'@@@   ' ......` @   ;''' ''
         '''''  .@     '''''''.,,   `::;;;;;:;:;;;: @@++#@@@  @@   '' ':   .' ++  '''''''
         '''''   @     '''''';.,, , :;;::;::;;;;;;; @@@@@@@   @ ` '''`'++++++ ''@@@@@@@@@
         '''''   `     ''''''',,, , ::: : :;;;;;;::, @@@@@+      ''@@ '++++++ ,@@@@@@@@@@
         ''''',     '  ''''';;.,, , :::.: :;;;;;;;::,@@@@@,  ;  :@@@@ ;++++'+ @@@@@@@@@@@
         ''''''     '  ;;;;;;' ,, ,,,::;.:`;;;:;;;:.;'@@@@;  '' ''@@@@@@@@@@@@@@@@@@@@@@@
         '''''';   ''  ;;;;;;; ,,,,. ,:::`:,     ,`;` `@@@#  ;''''''''''+''''''''''''''''
         '''''''. '''  ::::,,'; ,,,,,, `:::::` :: ,,`;:@'@#  .'''''''''''''''''''''''''''
         '''' ''';'';  ;;;;''';;; ,,,,,,,,,,,, :;;`  :;:: +  `''''''''+''+''  ''''''''''
         '''':'''''';  ;;;;  '';;'   ````      :;::` `  @@   ''''''''    ``   ````````
         '''';'''''''  ,;;   ;;;;;;;`,,.....   ``       `    '''  '''         ```````
         ''''''''''''   ;     ;';;;;.,,.;;''   ,,;.   ;;;  '': ; ''''         ``````    ;
         '':''.'''''''     ,  ';' '';,,.;;;;   ,,;,   ;;';;;;;' `.;'`        `````     .'
         ''.'' ''`' '''    '   '  ;;;,,.;;;'   ,,;;   ;;;;;;;;;;;;   ` .'    ````      ''
         ''''':'';''''''   ''     ;;;,,.;;;;   ,,;;   ;;;;;;;';;`     '''    ``       '''
         '''''',''`':''''; '''`   ;;;` ;;;;;'; ,,;;  ';;;;;;;;:     :''''           ;''''
         ''''''''''''''''''''''' ``;'';;;;;;;;';;;;;;;;;;;;;;'   ` ;''''';        '''''''
         ''''''''''''''''''''''', ;;;;;;;;;;;';;;;;;;;;;;;;;'      '''''''',    '''''''''
         '''''''''''''''''''''; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;'     ''''''''''':`''''''''''
         */
        // TODO: investigate why an extra layoutSubtreeIfNeeded() is required here
        // after editing a model that drops out of the predicate filter.
        hostingController.view.layoutSubtreeIfNeeded()
        
        if !ProcessInfo.isRunningHeadless {
            guard let resultsAfterEdit = await iterator.next() else {
                Issue.record("Expected updated results after editing model")
                return
            }
            #expect(resultsAfterEdit == Array(models[1...]))
        }
        
        continuation.finish()
    }
    
    private func seed() throws -> (ModelContainer, [Test]) {
        var logConfiguration = LogConfiguration.debug
        logConfiguration.modelContextErrors = true
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.swiftui.query",
            logConfiguration: logConfiguration
        )
        
        let context = container.context!
        
        let names = [
            "Mia Koring",
            "John Doe",
            "Alice Johnson",
            "Robert Smith",
            "Elena Rodriguez",
            "Liam Chen",
            "Sophia Müller",
            "David Park",
            "Amara Okafor",
            "Lucas Bernard",
            "Isabella Rossi",
            "Yuki Tanaka"
        ]
        
        let models = names.map(Test.init)
        
        for model in models {
            try context.insert(model)
        }
        
        return (container, models.sorted(by: { $0.id < $1.id }))
    }
}

extension Array where Element == Test {
    fileprivate var ids: [ULID] {
        map(\.id)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable, Equatable {
        var someValue: String
        
        init(someValue: String) {
            self.someValue = someValue
        }
        
        static func == (lhs: V0_0_1.Test, rhs: V0_0_1.Test) -> Bool {
            lhs.someValue == rhs.someValue
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
}
#endif
