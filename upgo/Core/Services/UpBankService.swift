import Foundation

enum UpBankError: Error, LocalizedError {
    case invalidURL
    case apiError(NetworkError)
    case tokenNotFound
    case webhookSetupError(String)
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for Up Bank API"
        case .apiError(let error):
            return "API Error: \(error.message)"
        case .tokenNotFound:
            return "Up Bank API token not found"
        case .webhookSetupError(let reason):
            return "Failed to set up webhook: \(reason)"
        }
    }
    
    // Implementing LocalizedError protocol
    var errorDescription: String? {
        return message
    }
}

class UpBankService {
    // MARK: - Properties
    private let baseURL = "https://api.up.com.au/api/v1"
    private let networkService: NetworkService
    private let securityService: SecurityService
    
    // Shared singleton instance
    static let shared = UpBankService()
    
    // MARK: - Initialization
    init(networkService: NetworkService = NetworkService(), securityService: SecurityService = SecurityService()) {
        self.networkService = networkService
        self.securityService = securityService
    }
    
    // MARK: - API Methods
    
    /// Verifies that the API token is valid
    /// - Returns: true if the token is valid
    func verifyToken() async throws -> Bool {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/util/ping") else {
                throw UpBankError.invalidURL
            }
            
            let _: PingResponse = try await networkService.get(url: url, token: token)
            // If we get here, the token is valid
            return true
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches all accounts from the Up Bank API
    /// - Returns: A list of accounts
    func fetchAccounts() async throws -> [Account] {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/accounts") else {
                throw UpBankError.invalidURL
            }
            
            let response: ApiResponse<[Account]> = try await networkService.get(url: url, token: token)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches a specific account by ID
    /// - Parameter accountId: The ID of the account to fetch
    /// - Returns: The account details
    func fetchAccount(accountId: String) async throws -> Account {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/accounts/\(accountId)") else {
                throw UpBankError.invalidURL
            }
            
            let response: ApiResponse<Account> = try await networkService.get(url: url, token: token)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches transactions with optional filtering
    /// - Parameters:
    ///   - since: Optional date to filter transactions from
    ///   - until: Optional date to filter transactions until
    ///   - category: Optional category ID to filter by
    ///   - tag: Optional tag name to filter by
    ///   - status: Optional transaction status to filter by
    ///   - pageSize: Number of transactions per page
    ///   - pageAfter: Cursor for pagination (next page)
    ///   - pageBefore: Cursor for pagination (previous page)
    /// - Returns: A page of transactions with pagination links
    func fetchTransactions(
        since: Date? = nil,
        until: Date? = nil,
        category: String? = nil,
        tag: String? = nil,
        status: TransactionStatus? = nil,
        pageSize: Int = 30,
        pageAfter: String? = nil,
        pageBefore: String? = nil
    ) async throws -> ApiResponse<[Transaction]> {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/transactions") else {
                throw UpBankError.invalidURL
            }
            
            var parameters: [String: String] = [
                "page[size]": "\(pageSize)"
            ]
            
            // Configure formatter with correct timezone
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone.current
            formatter.formatOptions = [.withInternetDateTime]
            
            if let since = since {
                let sinceStr = formatter.string(from: since)
                print("DEBUG: Using 'since' date filter: \(sinceStr) (original date: \(since))")
                parameters["filter[since]"] = sinceStr
            }
            
            if let until = until {
                let untilStr = formatter.string(from: until)
                print("DEBUG: Using 'until' date filter: \(untilStr) (original date: \(until))")
                parameters["filter[until]"] = untilStr
            }
            
            if let category = category {
                parameters["filter[category]"] = category
            }
            
            if let tag = tag {
                parameters["filter[tag]"] = tag
            }
            
            if let status = status {
                parameters["filter[status]"] = status.rawValue
            }
            
            if let pageAfter = pageAfter {
                parameters["page[after]"] = pageAfter
            }
            
            if let pageBefore = pageBefore {
                parameters["page[before]"] = pageBefore
            }
            
            return try await networkService.get(url: url, token: token, parameters: parameters)
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches transactions for a specific account
    /// - Parameters:
    ///   - accountId: The ID of the account
    ///   - since: Optional date to filter transactions from
    ///   - until: Optional date to filter transactions until
    ///   - pageSize: Number of transactions per page
    ///   - pageAfter: Cursor for pagination (next page)
    ///   - pageBefore: Cursor for pagination (previous page)
    /// - Returns: A page of transactions with pagination links
    func fetchTransactionsForAccount(
        accountId: String,
        since: Date? = nil,
        until: Date? = nil,
        pageSize: Int = 30,
        pageAfter: String? = nil,
        pageBefore: String? = nil
    ) async throws -> ApiResponse<[Transaction]> {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/accounts/\(accountId)/transactions") else {
                throw UpBankError.invalidURL
            }
            
            var parameters: [String: String] = [
                "page[size]": "\(pageSize)"
            ]
            
            // Configure formatter with correct timezone
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone.current
            formatter.formatOptions = [.withInternetDateTime]
            
            if let since = since {
                let sinceStr = formatter.string(from: since)
                print("DEBUG: Using 'since' date filter: \(sinceStr) (original date: \(since))")
                parameters["filter[since]"] = sinceStr
            }
            
            if let until = until {
                let untilStr = formatter.string(from: until)
                print("DEBUG: Using 'until' date filter: \(untilStr) (original date: \(until))")
                parameters["filter[until]"] = untilStr
            }
            
            if let pageAfter = pageAfter {
                parameters["page[after]"] = pageAfter
            }
            
            if let pageBefore = pageBefore {
                parameters["page[before]"] = pageBefore
            }
            
            return try await networkService.get(url: url, token: token, parameters: parameters)
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches a specific transaction by ID
    /// - Parameter transactionId: The ID of the transaction to fetch
    /// - Returns: The transaction details
    func fetchTransaction(transactionId: String) async throws -> Transaction {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/transactions/\(transactionId)") else {
                throw UpBankError.invalidURL
            }
            
            let response: ApiResponse<Transaction> = try await networkService.get(url: url, token: token)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches all categories from the Up Bank API
    /// - Returns: A list of categories
    func fetchCategories() async throws -> [Category] {
        do {
            print("fetchCategories: Attempting to fetch categories from Up Bank API...")
            
            // Try to get the token
            let token: String
            do {
                token = try await getToken()
                print("fetchCategories: Successfully retrieved API token")
            } catch {
                print("fetchCategories: Failed to get API token: \(error.localizedDescription)")
                throw UpBankError.tokenNotFound
            }
            
            guard let url = URL(string: "\(baseURL)/categories") else {
                print("fetchCategories: Invalid URL for categories endpoint")
                throw UpBankError.invalidURL
            }
            
            print("fetchCategories: Making network request to: \(url.absoluteString)")
            
            // Make the network request with detailed error handling
            do {
                let response: ApiResponse<[Category]> = try await networkService.get(url: url, token: token)
                print("fetchCategories: Successfully fetched \(response.data.count) categories")
                return response.data
            } catch let networkError as NetworkError {
                print("fetchCategories: Network error: \(networkError.message)")
                throw UpBankError.apiError(networkError)
            } catch {
                print("fetchCategories: Unknown error: \(error.localizedDescription)")
                throw error
            }
        } catch let error as UpBankError {
            print("fetchCategories: Up Bank error: \(error.message)")
            throw error
        } catch {
            print("fetchCategories: Unexpected error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches a specific category by ID
    /// - Parameter categoryId: The ID of the category to fetch
    /// - Returns: The category details
    func fetchCategory(categoryId: String) async throws -> Category {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/categories/\(categoryId)") else {
                throw UpBankError.invalidURL
            }
            
            let response: ApiResponse<Category> = try await networkService.get(url: url, token: token)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches all tags from the Up Bank API
    /// - Returns: A list of tags
    func fetchTags() async throws -> [Tag] {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/tags") else {
                throw UpBankError.invalidURL
            }
            
            let response: ApiResponse<[Tag]> = try await networkService.get(url: url, token: token)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Creates a new tag
    /// - Parameter tagId: The ID of the tag to create
    /// - Returns: The created tag
    func createTag(tagId: String) async throws -> Tag {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/tags") else {
                throw UpBankError.invalidURL
            }
            
            struct TagRequest: Codable {
                struct TagData: Codable {
                    var type: String = "tags"
                    let id: String
                }
                let data: TagData
            }
            
            let request = TagRequest(data: .init(id: tagId))
            let response: ApiResponse<Tag> = try await networkService.post(url: url, token: token, body: request)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Adds a tag to a transaction
    /// - Parameters:
    ///   - transactionId: The ID of the transaction
    ///   - tagId: The ID of the tag to add
    func addTagToTransaction(transactionId: String, tagId: String) async throws {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/transactions/\(transactionId)/relationships/tags") else {
                throw UpBankError.invalidURL
            }
            
            struct TagRelationshipRequest: Codable {
                struct TagData: Codable {
                    var type: String = "tags"
                    let id: String
                }
                let data: [TagData]
            }
            
            let request = TagRelationshipRequest(data: [.init(id: tagId)])
            let _: ApiResponse<[String: String]> = try await networkService.post(url: url, token: token, body: request)
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Removes a tag from a transaction
    /// - Parameters:
    ///   - transactionId: The ID of the transaction
    ///   - tagId: The ID of the tag to remove
    func removeTagFromTransaction(transactionId: String, tagId: String) async throws {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/transactions/\(transactionId)/relationships/tags") else {
                throw UpBankError.invalidURL
            }
            
            struct TagRelationshipRequest: Codable {
                struct TagData: Codable {
                    var type: String = "tags"
                    let id: String
                }
                let data: [TagData]
            }
            
            try await networkService.delete(url: url, token: token)
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Creates a webhook for receiving real-time transaction updates
    /// - Parameters:
    ///   - url: The URL to send webhook events to
    ///   - description: Optional description for the webhook
    /// - Returns: The created webhook
    func createWebhook(url: URL, description: String? = nil) async throws -> Webhook {
        do {
            let token = try await getToken()
            
            guard let apiUrl = URL(string: "\(baseURL)/webhooks") else {
                throw UpBankError.invalidURL
            }
            
            struct WebhookRequest: Codable {
                struct WebhookData: Codable {
                    var type: String = "webhooks"
                    let attributes: WebhookAttributes
                }
                
                struct WebhookAttributes: Codable {
                    var url: URL
                    var description: String?
                }
                
                let data: WebhookData
            }
            
            let request = WebhookRequest(data: .init(attributes: .init(url: url, description: description)))
            let response: ApiResponse<Webhook> = try await networkService.post(url: apiUrl, token: token, body: request)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Lists all webhooks
    /// - Returns: A list of webhooks
    func listWebhooks() async throws -> [Webhook] {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/webhooks") else {
                throw UpBankError.invalidURL
            }
            
            let response: ApiResponse<[Webhook]> = try await networkService.get(url: url, token: token)
            return response.data
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Deletes a webhook
    /// - Parameter webhookId: The ID of the webhook to delete
    func deleteWebhook(webhookId: String) async throws {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/webhooks/\(webhookId)") else {
                throw UpBankError.invalidURL
            }
            
            try await networkService.delete(url: url, token: token)
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Categorizes a transaction
    /// - Parameters:
    ///   - transactionId: The ID of the transaction to categorize
    ///   - categoryId: The ID of the category to set, or nil to remove the category
    func categorizeTransaction(transactionId: String, categoryId: String?) async throws {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/transactions/\(transactionId)/relationships/category") else {
                throw UpBankError.invalidURL
            }
            
            // If categoryId is nil, we're removing the category
            if categoryId == nil {
                // Use a proper Encodable structure with nil data
                struct NullCategoryData: Encodable {
                    let data: CategoryData?
                    
                    struct CategoryData: Encodable {
                        var type: String = "categories"
                        var id: String = ""
                    }
                    
                    init() {
                        self.data = nil
                    }
                }
                
                try await networkService.patch(url: url, token: token, body: NullCategoryData())
            } else {
                // Send a payload with the category ID to set the category
                struct CategoryRequest: Encodable {
                    struct CategoryData: Encodable {
                        var type: String = "categories"
                        let id: String
                    }
                    let data: CategoryData
                }
                
                let request = CategoryRequest(data: .init(id: categoryId!))
                try await networkService.patch(url: url, token: token, body: request)
            }
        } catch let error as NetworkError {
            throw UpBankError.apiError(error)
        }
    }
    
    /// Fetches transactions for a specific category
    /// - Parameters:
    ///   - categoryId: The ID of the category
    ///   - since: Optional date to filter transactions from
    ///   - pageSize: Number of transactions per page
    /// - Returns: A list of transactions for the category
    func fetchTransactionsForCategory(categoryId: String, since: Date? = nil, pageSize: Int = 50) async throws -> [Transaction] {
        do {
            let token = try await getToken()
            
            guard let url = URL(string: "\(baseURL)/transactions") else {
                throw UpBankError.invalidURL
            }
            
            var parameters: [String: String] = [
                "page[size]": "\(pageSize)",
                "filter[category]": categoryId
            ]
            
            // Add date filtering if specified
            if let since = since {
                // Configure formatter with correct timezone
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone.current
                formatter.formatOptions = [.withInternetDateTime]
                
                let sinceStr = formatter.string(from: since)
                print("DEBUG: Using 'since' date filter: \(sinceStr) (original date: \(since))")
                parameters["filter[since]"] = sinceStr
            }
            
            // First fetch
            let response: ApiResponse<[Transaction]> = try await networkService.get(url: url, token: token, parameters: parameters)
            var allTransactions = response.data
            
            // If there are more pages, fetch them too (up to 3 additional pages)
            var additionalPagesFetched = 0
            var nextPageUrl = response.links?.next
            
            while nextPageUrl != nil && additionalPagesFetched < 3 {
                // Use the nextPageUrl string directly since networkService.get expects a string
                let nextResponse: ApiResponse<[Transaction]> = try await networkService.get(url: nextPageUrl!, token: token)
                allTransactions.append(contentsOf: nextResponse.data)
                
                // Update for next iteration
                nextPageUrl = nextResponse.links?.next
                additionalPagesFetched += 1
            }
            
            print("Fetched \(allTransactions.count) total transactions for category \(categoryId)")
            
            return allTransactions
        } catch let error as NetworkError {
            print("Network error fetching transactions for category \(categoryId): \(error.localizedDescription)")
            throw UpBankError.apiError(error)
        } catch {
            print("Error fetching transactions for category \(categoryId): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches transactions with tag filter
    /// - Parameters:
    ///   - tagName: The tag name to filter by
    ///   - since: Optional date to filter transactions from
    ///   - pageSize: Number of transactions per page
    /// - Returns: Array of transactions matching the tag
    func fetchTransactionsWithTag(tagName: String, since: Date? = nil, pageSize: Int = 30) async throws -> [Transaction] {
        // Use the general fetch transactions method with tag filter
        let apiResponse = try await fetchTransactions(
            since: since,
            tag: tagName,
            pageSize: pageSize
        )
        
        return apiResponse.data
    }
    
    /// Makes an API request that needs to authenticate first
    /// - Parameters:
    ///   - request: URLRequest to execute after authentication
    ///   - retryCount: Number of attempts so far
    /// - Returns: Data from the response
    private func authenticatedRequest(_ request: URLRequest, retryCount: Int = 0) async throws -> Data {
        guard retryCount < 3 else {
            throw NetworkError.tooManyRetries
        }
        
        do {
            let token = try await getToken()
            
            var authorizedRequest = request
            authorizedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, urlResponse) = try await URLSession.shared.data(for: authorizedRequest)
            
            // Check for HTTP status code
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Check if the request was successful
            guard 200...299 ~= httpResponse.statusCode else {
                // Handle specific errors
                switch httpResponse.statusCode {
                case 401:
                    throw NetworkError.unauthorized
                case 403:
                    throw NetworkError.forbidden
                case 429:
                    throw NetworkError.rateLimited
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            
            return data
        } catch NetworkError.unauthorized {
            // If unauthorized, refresh token and retry
            try await refreshToken()
            return try await authenticatedRequest(request, retryCount: retryCount + 1)
        } catch {
            throw error
        }
    }
    
    // Placeholder for refreshToken - IMPLEMENT LATER
    private func refreshToken() async throws {
        // TODO: Implement token refresh logic here
        print("Attempting to refresh token...")
        // For now, this will just throw an error to indicate it's not implemented
        throw NetworkError.unauthorized // Or a more specific error like .tokenRefreshFailed
    }
    
    // MARK: - Helper Methods
    
    /// Gets the API token from the security service
    /// - Returns: The API token
    func getToken() async throws -> String {
        do {
            return try await securityService.getApiToken()
        } catch {
            throw UpBankError.tokenNotFound
        }
    }
    
    /// Stores the API token securely
    /// - Parameter token: The API token to store
    func storeApiToken(_ token: String) async throws {
        try await securityService.storeApiToken(token)
    }
} 