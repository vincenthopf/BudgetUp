import Foundation

// MARK: - API Response Structures

struct ApiLinks {
    let prev: URL?
    let next: URL?
}

extension ApiLinks: Codable {
    enum CodingKeys: String, CodingKey {
        case prev
        case next
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prev = try container.decodeIfPresent(URL.self, forKey: .prev)
        next = try container.decodeIfPresent(URL.self, forKey: .next)
    }
}

// MARK: - Ping Response
// Custom structure for the /util/ping endpoint response
struct PingResponse: Codable {
    let meta: [String: String]
}

// MARK: - Generic API Response
struct ApiResponse<T: Codable>: Codable {
    let data: T
    let links: ApiLinks?
}

// MARK: - Account Models
struct Account: Identifiable {
    let id: String
    let attributes: AccountAttributes
    let relationships: AccountRelationships?
    
    enum AccountType: String, Codable {
        case saver = "SAVER"
        case transactional = "TRANSACTIONAL"
    }
    
    enum OwnershipType: String, Codable {
        case individual = "INDIVIDUAL"
        case joint = "JOINT"
    }
}

extension Account: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }
}

struct AccountAttributes: Codable {
    let displayName: String
    let accountType: Account.AccountType
    let ownershipType: Account.OwnershipType
    let balance: MoneyObject
    let createdAt: Date
}

struct AccountRelationships: Codable {
    let transactions: RelationshipLinks?
}

struct RelationshipLinks: Codable {
    let links: RelationshipURLs?
}

struct RelationshipURLs: Codable {
    let related: URL?
    let `self`: URL?
}

// MARK: - Transaction Models
struct Transaction: Identifiable {
    let id: String
    let attributes: TransactionAttributes
    let relationships: TransactionRelationships?
}

extension Transaction: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }
}

struct TransactionAttributes: Codable {
    let description: String
    let message: String?
    let amount: MoneyObject
    let status: TransactionStatus
    let rawText: String?
    let isCategorizable: Bool
    let holdInfo: HoldInfo?
    let roundUp: RoundUp?
    let cashback: Cashback?
    let createdAt: Date
    let settledAt: Date?
}

enum TransactionStatus: String, Codable {
    case held = "HELD"
    case settled = "SETTLED"
}

struct HoldInfo: Codable {
    let amount: MoneyObject
    let foreignAmount: MoneyObject?
}

struct RoundUp: Codable {
    let amount: MoneyObject
    let boostPortion: MoneyObject?
}

struct Cashback: Codable {
    let description: String
    let amount: MoneyObject
}

struct TransactionRelationships: Codable {
    let account: RelationshipLinks
    let transferAccount: RelationshipLinks?
    let category: RelationshipLinks?
    let parentCategory: RelationshipLinks?
    let tags: RelationshipLinks?
}

// MARK: - Category Models
struct Category: Identifiable {
    let id: String
    let attributes: CategoryAttributes
    let relationships: CategoryRelationships?
}

extension Category: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }
}

struct CategoryAttributes: Codable {
    let name: String
}

struct CategoryRelationships: Codable {
    let parent: RelationshipLinks?
    let children: RelationshipLinks?
}

// MARK: - Tag Models
struct Tag: Identifiable {
    let id: String
    let relationships: TagRelationships?
}

extension Tag: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case relationships
    }
}

struct TagRelationships: Codable {
    let transactions: RelationshipLinks?
}

// MARK: - Webhook Models
struct Webhook: Identifiable {
    let id: String
    let attributes: WebhookAttributes
    let relationships: WebhookRelationships?
}

extension Webhook: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }
}

struct WebhookAttributes: Codable {
    let url: URL
    let description: String?
    let secretKey: String
    let createdAt: Date
}

struct WebhookRelationships: Codable {
    let logs: RelationshipLinks?
}

// MARK: - Common Value Objects
struct MoneyObject: Codable {
    let currencyCode: String
    let value: String
    let valueInBaseUnits: Int
}

// MARK: - Date Formatting
extension DateFormatter {
    static let upBankDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
} 