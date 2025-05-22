import Foundation
import SwiftUI
import Combine

@MainActor
class TransactionsViewModel: ObservableObject {
    // MARK: - Properties
    private let upBankService: UpBankService
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var hasMorePages = false
    @Published var error: String? = nil
    @Published var selectedAccountId: String? = nil
    @Published var categories: [Category] = []
    @Published var isLoadingCategories = false
    
    // Pagination
    private var nextPageCursor: String? = nil
    private var prevPageCursor: String? = nil
    
    // Filters
    @Published var filterStartDate: Date? = nil
    @Published var filterEndDate: Date? = nil
    @Published var filterCategory: String? = nil
    @Published var filterTag: String? = nil
    @Published var filterStatus: TransactionStatus? = nil
    @Published var searchText: String = ""
    
    // MARK: - Initialization
    nonisolated init(upBankService: UpBankService = UpBankService()) {
        self.upBankService = upBankService
    }
    
    // MARK: - Public Methods
    
    /// Loads categories from the Up Bank API
    func loadCategories() async {
        guard categories.isEmpty else { return }
        
        isLoadingCategories = true
        error = nil
        
        do {
            let fetchedCategories = try await upBankService.fetchCategories()
            categories = fetchedCategories
            isLoadingCategories = false
        } catch {
            isLoadingCategories = false
            self.error = "Failed to load categories: \(error.localizedDescription)"
        }
    }
    
    /// Updates a transaction's category
    /// - Parameters:
    ///   - transactionId: The ID of the transaction
    ///   - categoryId: The ID of the category to set
    func updateTransactionCategory(transactionId: String, categoryId: String?) async {
        do {
            // Call the Up Bank API to update the category
            try await upBankService.categorizeTransaction(transactionId: transactionId, categoryId: categoryId)
            
            // Refresh the transaction details to get the updated category
            if let index = transactions.firstIndex(where: { $0.id == transactionId }),
               let updatedTransaction = try? await upBankService.fetchTransaction(transactionId: transactionId) {
                transactions[index] = updatedTransaction
            }
            
            // Also trigger a refresh for any budgets that might be associated with this category
            NotificationCenter.default.post(name: .transactionCategoryUpdated, object: nil, userInfo: ["categoryId": categoryId as Any])
        } catch {
            self.error = "Failed to update category: \(error.localizedDescription)"
        }
    }
    
    /// Gets a category name from its ID
    /// - Parameter categoryId: The category ID
    /// - Returns: The category name, or nil if not found
    func getCategoryName(for categoryId: String) -> String? {
        return categories.first(where: { $0.id == categoryId })?.attributes.name
    }
    
    /// Fetches transactions based on current filters
    func fetchTransactions() async {
        self.isLoading = true
        self.error = nil
        
        do {
            let response: ApiResponse<[Transaction]>
            
            if let accountId = selectedAccountId {
                response = try await upBankService.fetchTransactionsForAccount(
                    accountId: accountId,
                    since: filterStartDate,
                    until: filterEndDate,
                    pageSize: 30
                )
            } else {
                response = try await upBankService.fetchTransactions(
                    since: filterStartDate,
                    until: filterEndDate,
                    category: filterCategory,
                    tag: filterTag,
                    status: filterStatus,
                    pageSize: 30
                )
            }
            
            // Process pagination info on the main thread
            await processResponseLinks(response.links)
            
            // Update transactions
            self.transactions = response.data
            self.isLoading = false
        } catch {
            self.isLoading = false
            
            // Handle task cancellation separately to avoid showing error message
            if error is CancellationError || 
               (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                print("Transaction fetch was cancelled")
                // Don't set error message for cancellation
            } else {
                self.error = "Failed to fetch transactions: \(error.localizedDescription)"
            }
        }
    }
    
    /// Loads the next page of transactions
    func loadNextPage() async {
        guard let nextCursor = nextPageCursor, !isLoading else { return }
        
        self.isLoading = true
        self.error = nil
        
        do {
            let response: ApiResponse<[Transaction]>
            
            if let accountId = selectedAccountId {
                response = try await upBankService.fetchTransactionsForAccount(
                    accountId: accountId,
                    since: filterStartDate,
                    until: filterEndDate,
                    pageSize: 30,
                    pageAfter: nextCursor
                )
            } else {
                response = try await upBankService.fetchTransactions(
                    since: filterStartDate,
                    until: filterEndDate,
                    category: filterCategory,
                    tag: filterTag,
                    status: filterStatus,
                    pageSize: 30,
                    pageAfter: nextCursor
                )
            }
            
            // Process pagination info on the main thread
            await processResponseLinks(response.links)
            
            // Append transactions
            self.transactions.append(contentsOf: response.data)
            self.isLoading = false
        } catch {
            self.isLoading = false
            
            // Handle task cancellation separately to avoid showing error message
            if error is CancellationError || 
               (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                print("Load next page was cancelled")
                // Don't set error message for cancellation
            } else {
                self.error = "Failed to load more transactions: \(error.localizedDescription)"
            }
        }
    }
    
    /// Loads the previous page of transactions
    func loadPreviousPage() async {
        guard let prevCursor = prevPageCursor, !isLoading else { return }
        
        self.isLoading = true
        self.error = nil
        
        do {
            let response: ApiResponse<[Transaction]>
            
            if let accountId = selectedAccountId {
                response = try await upBankService.fetchTransactionsForAccount(
                    accountId: accountId,
                    since: filterStartDate,
                    until: filterEndDate,
                    pageSize: 30,
                    pageBefore: prevCursor
                )
            } else {
                response = try await upBankService.fetchTransactions(
                    since: filterStartDate,
                    until: filterEndDate,
                    category: filterCategory,
                    tag: filterTag,
                    status: filterStatus,
                    pageSize: 30,
                    pageBefore: prevCursor
                )
            }
            
            // Process pagination info on the main thread
            await processResponseLinks(response.links)
            
            // Update transactions
            self.transactions = response.data
            self.isLoading = false
        } catch {
            self.isLoading = false
            
            // Handle task cancellation separately to avoid showing error message
            if error is CancellationError || 
               (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                print("Load previous page was cancelled")
                // Don't set error message for cancellation
            } else {
                self.error = "Failed to load previous transactions: \(error.localizedDescription)"
            }
        }
    }
    
    /// Helper method to process pagination links on the main thread
    private func processResponseLinks(_ links: ApiLinks?) {
        if let nextLink = links?.next {
            let queryItems = URLComponents(url: nextLink, resolvingAgainstBaseURL: true)?.queryItems
            nextPageCursor = queryItems?.first(where: { $0.name == "page[after]" })?.value
            hasMorePages = nextPageCursor != nil
        } else {
            nextPageCursor = nil
            hasMorePages = false
        }
        
        if let prevLink = links?.prev {
            let queryItems = URLComponents(url: prevLink, resolvingAgainstBaseURL: true)?.queryItems
            prevPageCursor = queryItems?.first(where: { $0.name == "page[before]" })?.value
        } else {
            prevPageCursor = nil
        }
    }
    
    /// Adds a tag to a transaction
    /// - Parameters:
    ///   - transactionId: The ID of the transaction
    ///   - tagId: The ID of the tag to add
    func addTag(to transactionId: String, tagId: String) async {
        do {
            try await upBankService.addTagToTransaction(transactionId: transactionId, tagId: tagId)
            
            // Refresh transaction details
            if let index = transactions.firstIndex(where: { $0.id == transactionId }),
               let updatedTransaction = try? await upBankService.fetchTransaction(transactionId: transactionId) {
                self.transactions[index] = updatedTransaction
            }
        } catch {
            self.error = "Failed to add tag: \(error.localizedDescription)"
        }
    }
    
    /// Removes a tag from a transaction
    /// - Parameters:
    ///   - transactionId: The ID of the transaction
    ///   - tagId: The ID of the tag to remove
    func removeTag(from transactionId: String, tagId: String) async {
        do {
            try await upBankService.removeTagFromTransaction(transactionId: transactionId, tagId: tagId)
            
            // Refresh transaction details
            if let index = transactions.firstIndex(where: { $0.id == transactionId }),
               let updatedTransaction = try? await upBankService.fetchTransaction(transactionId: transactionId) {
                self.transactions[index] = updatedTransaction
            }
        } catch {
            self.error = "Failed to remove tag: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Reset all filters
    func resetFilters() {
        filterStartDate = nil
        filterEndDate = nil
        filterCategory = nil
        filterTag = nil
        filterStatus = nil
        searchText = ""
    }
    
    /// Filter transactions by the current account selection
    func selectAccount(_ accountId: String?) {
        selectedAccountId = accountId
    }
    
    /// Format the amount for display
    func formattedAmount(for transaction: Transaction) -> String {
        let amount = transaction.attributes.amount
        let baseUnits = amount.valueInBaseUnits
        let dollars = Double(baseUnits) / 100.0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = amount.currencyCode
        
        return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
    }
    
    /// Format the date for display
    func formattedDate(for transaction: Transaction) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if let settledAt = transaction.attributes.settledAt {
            return formatter.string(from: settledAt)
        } else {
            return formatter.string(from: transaction.attributes.createdAt)
        }
    }
}

// Extension for notification names
extension Notification.Name {
    static let transactionCategoryUpdated = Notification.Name("transactionCategoryUpdated")
} 