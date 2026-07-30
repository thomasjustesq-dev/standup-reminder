import Foundation

/// Centralises the runtime gate used by the debug panel and debug menu item.
///
/// Returns `true` only in debug builds **and** when `--debug` is present in
/// the process arguments — so the panel is invisible to normal users even
/// in a locally-built debug binary.
enum DebugEnvironment {
    static var isDebugMode: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--debug")
        #else
        return false
        #endif
    }
}
