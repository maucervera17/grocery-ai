import Foundation

enum ChatRole: String, Codable, Hashable, Sendable {
    case user
    case agent
}

enum ChatMessageKind: String, Codable, Hashable, Sendable {
    case text
    case draftUpdate
    case comparison
    case error
}

struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var role: ChatRole
    var text: String
    var kind: ChatMessageKind
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        kind: ChatMessageKind = .text,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.kind = kind
        self.createdAt = createdAt
    }
}

enum AgentOperationStatus: String, Codable, Hashable, Sendable {
    case complete
    case partial
    case error
}

struct AgentIssue: Identifiable, Codable, Hashable, Error, Sendable {
    var id: UUID
    var code: String
    var message: String
    var clientItemID: UUID?
    var retryable: Bool

    init(
        id: UUID = UUID(),
        code: String,
        message: String,
        clientItemID: UUID? = nil,
        retryable: Bool = false
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.clientItemID = clientItemID
        self.retryable = retryable
    }
}

struct AgentResponse: Codable, Hashable, Sendable {
    var reply: String
    var status: AgentOperationStatus
    var draftItems: [ProductRequest]
    var plan: ComparisonPlan?
    var errors: [AgentIssue]

    init(
        reply: String,
        status: AgentOperationStatus = .complete,
        draftItems: [ProductRequest],
        plan: ComparisonPlan? = nil,
        errors: [AgentIssue] = []
    ) {
        self.reply = reply
        self.status = status
        self.draftItems = draftItems
        self.plan = plan
        self.errors = errors
    }
}

enum ChatLoadingState: Equatable, Sendable {
    case idle
    case updatingDraft
    case comparing
    case failed(message: String)
}
