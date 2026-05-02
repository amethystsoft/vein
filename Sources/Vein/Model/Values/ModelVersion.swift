public struct ModelVersion: Comparable, Hashable, Equatable, Sendable {
    let major: UInt32
    let minor: UInt32
    let patch: UInt32
    
    public init(_ major: UInt32, _ minor: UInt32, _ patch: UInt32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    static public func < (lhs: ModelVersion, rhs: ModelVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        return false
    }
    
    static public func == (lhs: ModelVersion, rhs: ModelVersion) -> Bool {
        lhs.major == rhs.major &&
        lhs.minor == rhs.minor &&
        lhs.patch == rhs.patch
    }
}
