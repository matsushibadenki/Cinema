import Foundation

/// Ephemeral inspection settings; media and export timing remain unchanged.
struct PreviewLoopRange: Equatable {
    var start: Double
    var end: Double
    func isValid(duration: Double) -> Bool {
        start.isFinite && end.isFinite && duration.isFinite && start >= 0 && end <= duration && end - start >= 0.05 - 1e-9
    }
    func contains(_ seconds: Double) -> Bool { seconds >= start && seconds < end }
}
