import Foundation

enum SyncError: Error {
    case syncFailed(String)
    case tokenNotAvailable
    case networkError(Error)
    
    var message: String {
        switch self {
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .tokenNotAvailable:
            return "API token not available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class DataSyncService {
    // MARK: - Properties
    private let upBankService: UpBankService
    private let securityService: SecurityService
    
    // Used for tracking sync state
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    
    // MARK: - Initialization
    init(upBankService: UpBankService = UpBankService(), securityService: SecurityService = SecurityService()) {
        self.upBankService = upBankService
        self.securityService = securityService
    }
    
    // MARK: - Public Methods
    
    /// Performs an initial sync of data from the Up Bank API
    /// - Parameter completionHandler: Called when the sync is complete or fails
    func performInitialSync() async throws {
        // Check if token exists
        guard securityService.hasApiToken() else {
            throw SyncError.tokenNotAvailable
        }
        
        // Set syncing state
        isSyncing = true
        syncError = nil
        
        do {
            // Verify token works
            let isValid = try await upBankService.verifyToken()
            guard isValid else {
                throw SyncError.tokenNotAvailable
            }
            
            // Fetch accounts
            let _ = try await upBankService.fetchAccounts()
            
            // Fetch categories
            let _ = try await upBankService.fetchCategories()
            
            // Fetch tags
            let _ = try await upBankService.fetchTags()
            
            // Fetch initial transactions for each account
            let accounts = try await upBankService.fetchAccounts()
            for account in accounts {
                try await syncTransactionsForAccount(accountId: account.id)
            }
            
            // Update sync state
            lastSyncDate = Date()
            isSyncing = false
            
        } catch {
            isSyncing = false
            syncError = error
            throw SyncError.syncFailed("Initial sync failed: \(error.localizedDescription)")
        }
    }
    
    /// Performs an incremental sync of data since the last sync
    func performIncrementalSync() async throws {
        guard let lastSync = lastSyncDate else {
            // If no previous sync, perform an initial sync
            return try await performInitialSync()
        }
        
        // Check if token exists
        guard securityService.hasApiToken() else {
            throw SyncError.tokenNotAvailable
        }
        
        // Set syncing state
        isSyncing = true
        syncError = nil
        
        do {
            // Fetch accounts (always get the latest)
            let accounts = try await upBankService.fetchAccounts()
            
            // Fetch transactions since last sync
            for account in accounts {
                try await syncTransactionsForAccount(accountId: account.id, since: lastSync)
            }
            
            // Update sync state
            lastSyncDate = Date()
            isSyncing = false
            
        } catch {
            isSyncing = false
            syncError = error
            throw SyncError.syncFailed("Incremental sync failed: \(error.localizedDescription)")
        }
    }
    
    /// Sets up a webhook for real-time updates
    /// - Parameters:
    ///   - url: The URL to send webhook events to
    ///   - description: Optional description for the webhook
    /// - Returns: The webhook ID if successful
    func setupWebhook(url: URL, description: String? = nil) async throws -> String {
        do {
            let webhook = try await upBankService.createWebhook(
                url: url,
                description: description ?? "UpGo App Webhook"
            )
            return webhook.id
        } catch {
            throw SyncError.syncFailed("Failed to set up webhook: \(error.localizedDescription)")
        }
    }
    
    /// Processes a webhook event
    /// - Parameter payload: The webhook payload
    func processWebhookEvent(payload: Data) async throws {
        // Parse the webhook payload
        // This would typically decode the webhook data, verify it's valid,
        // and then fetch any new transactions or updates
        
        // Example implementation - actual implementation would depend on webhook format
        do {
            // Refresh accounts (get latest balances)
            let _ = try await upBankService.fetchAccounts()
            
            // Specific transaction to update could be extracted from webhook payload
            // let transactionId = ... (extract from payload)
            // let transaction = try await upBankService.fetchTransaction(transactionId: transactionId)
            
            // Update lastSyncDate
            lastSyncDate = Date()
            
        } catch {
            throw SyncError.syncFailed("Failed to process webhook: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Syncs transactions for a specific account
    /// - Parameters:
    ///   - accountId: The ID of the account
    ///   - since: Optional date to filter transactions from
    private func syncTransactionsForAccount(accountId: String, since: Date? = nil) async throws {
        var hasMorePages = true
        var nextPageCursor: String? = nil
        
        while hasMorePages {
            let response = try await upBankService.fetchTransactionsForAccount(
                accountId: accountId,
                since: since,
                pageSize: 100,
                pageAfter: nextPageCursor
            )
            
            // Process the transactions
            // Here you would typically save them to a local database
            _ = response.data
            
            // Check if there are more pages
            if let nextLink = response.links?.next {
                // Extract cursor from next link
                let queryItems = URLComponents(url: nextLink, resolvingAgainstBaseURL: true)?.queryItems
                nextPageCursor = queryItems?.first(where: { $0.name == "page[after]" })?.value
                hasMorePages = nextPageCursor != nil
            } else {
                hasMorePages = false
            }
        }
    }
} 