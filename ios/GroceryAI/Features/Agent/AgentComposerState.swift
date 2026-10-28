import Foundation
import Observation

@MainActor
@Observable
final class AgentComposerState {
    var text = ""
    var presentedSheet: AgentSheet?
    var focusRequest = 0

    func requestFocus() {
        focusRequest += 1
    }
}
