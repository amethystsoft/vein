import Foundation

extension ProcessInfo {
    static var shouldEnableEncryption: Bool {
        ProcessInfo.processInfo.environment["SHOULD_DISABLE_ENCRYPTION"] != "1"
    }
    static var isRunningHeadless: Bool {
        ProcessInfo.processInfo.environment["IS_RUNNING_HEADLESS"] == "1"
    }
}
