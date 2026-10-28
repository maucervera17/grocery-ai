import Foundation
import SwiftData

@Model
final class LocalAppStateRecord {
    @Attribute(.unique) var key: String
    var draftData: Data
    var ordersData: Data
    var messagesData: Data
    var postalCode: String

    init(
        key: String = "primary",
        draftData: Data = Data(),
        ordersData: Data = Data(),
        messagesData: Data = Data(),
        postalCode: String = ""
    ) {
        self.key = key
        self.draftData = draftData
        self.ordersData = ordersData
        self.messagesData = messagesData
        self.postalCode = postalCode
    }
}
