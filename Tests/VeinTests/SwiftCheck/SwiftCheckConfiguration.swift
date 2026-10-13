import Foundation

extension ProcessInfo {
    static var swiftCheckIterations: Int {
        ProcessInfo.processInfo.environment["ReduceSwiftCheckIterations"] != nil ? 50: 100
    }
}
