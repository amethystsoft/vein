public struct ModelVersion: Comparable, Equatable, Sendable {
    let major: UInt32
    let minor: UInt32
    let patch: UInt32
    
    public init(_ major: UInt32, _ minor: UInt32, _ patch: UInt32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    static public func < (lhs: ModelVersion, rhs: ModelVersion) -> Bool {
        guard lhs.major <= rhs.major else { return false }
        guard lhs.minor <= rhs.minor else { return false }
        return lhs.patch < rhs.patch
    }
    
    static public func == (lhs: ModelVersion, rhs: ModelVersion) -> Bool {
        lhs.major == rhs.major &&
        lhs.minor == rhs.minor &&
        lhs.patch == rhs.patch
    }
}
