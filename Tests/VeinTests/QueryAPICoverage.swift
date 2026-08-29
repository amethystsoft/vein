#if (TEST_SCUI || TEST_SWIFTUI) && VeinFilter
import Foundation
#if TEST_SCUI
@testable import VeinSCUI
import SwiftCrossUI
#elseif TEST_SWIFTUI
import SwiftUI
@testable import VeinSwiftUI
#endif

fileprivate func apiCoverage() {
    let query = Query(#Predicate<Test> { test in test.flag })
    let sortedQuery = Query(#Predicate<Test> { test in test.flag }, sortBy: [SortRule(\.flag)])
    
    let query1 = Query(#Filter<Test> { test in test.flag })
    let sortedQuery1 = Query(#Filter<Test> { test in test.flag }, sortBy: [SortRule(\.flag)])
}

fileprivate typealias Test = V0_0_1.Test

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable {
        @Field
        var flag: Bool
        
        init(flag: Bool) {
            self.flag = flag
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
