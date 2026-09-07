#if canImport(SwiftCheck)
import SwiftCheck
import Foundation
import XCTest
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

fileprivate typealias Test = V0_0_1.Test
final class TestLimitOffsetSuite: XCTestCase {
    
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable {
        var someValue: String
        
        @LazyField
        var text: String?
        
        init(someValue: String, text: String?) {
            self.someValue = someValue
            self.text = text
        }
        
        func getLazyField() -> LazyField<String> {
            _text
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

extension V0_0_1.Test: Arbitrary {
    static fileprivate var arbitrary: SwiftCheck.Gen<Test> {
        return Gen<Test>.compose { dg in
            Test(
                someValue: dg.generate(),
                text: dg.generate()
            )
        }
    }
}
#endif
