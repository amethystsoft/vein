import VeinCore

// Our baseline schema
enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any PersistentModel.Type] = [
        Test.self
    ]
    
    @Model
    final class Test {
        var flag: Bool
        var someValue: String
        var randomValue: Int
        
        init(flag: Bool, someValue: String, randomValue: Int) {
            self.flag = flag
            self.someValue = someValue
            self.randomValue = randomValue
        }
    }
}

// Our destination schema
enum V0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    static let models: [any PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test {
        var flag: Bool
        var someValue: String
        var securityCode: String // This replaces the old raw Int
        
        init(flag: Bool, someValue: String, securityCode: String) {
            self.flag = flag
            self.someValue = someValue
            self.securityCode = securityCode
        }
    }
}
