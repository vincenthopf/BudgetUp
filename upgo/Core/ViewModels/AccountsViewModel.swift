import Foundation
import SwiftUI
import Combine

@MainActor
class AccountsViewModel: ObservableObject {
    // MARK: - Properties
    private let upBankService: UpBankService
    private var dataSyncService: DataSyncService
    
    // Reference to TransactionsViewModel
    var transactionsViewModel: TransactionsViewModel
    
    // Published properties
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var lastRefreshDate: Date? = nil
    
    // MARK: - Initialization
    nonisolated init(upBankService: UpBankService = UpBankService(), 
         dataSyncService: DataSyncService = DataSyncService(), 
         transactionsViewModel: TransactionsViewModel = TransactionsViewModel()) {
        self.upBankService = upBankService
        self.dataSyncService = dataSyncService
        self.transactionsViewModel = transactionsViewModel
    }
    
    // MARK: - Public Methods
    
    /// Fetches all accounts from the Up Bank API
    func fetchAccounts() async {
        self.isLoading = true
        self.error = nil
        
        do {
            let fetchedAccounts = try await upBankService.fetchAccounts()
            
            // Check if the task hasn't been cancelled before updating UI
            self.accounts = fetchedAccounts
            self.lastRefreshDate = Date()
            self.isLoading = false
        } catch let upError as UpBankError {
            self.isLoading = false
            self.error = "Failed to fetch accounts: \(upError.message)"
        } catch {
            self.isLoading = false
            
            // Handle task cancellation separately to avoid showing error message
            if error is CancellationError || 
               (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                print("Account fetch was cancelled")
                // Don't set error message for cancellation
            } else {
                self.error = "Failed to fetch accounts: \(error.localizedDescription)"
            }
        }
    }
    
    /// Refreshes all account data
    func refreshData() async {
        self.isLoading = true
        self.error = nil
        
        do {
            // Perform an incremental sync
            try await dataSyncService.performIncrementalSync()
            
            // Fetch the latest accounts
            let fetchedAccounts = try await upBankService.fetchAccounts()
            
            // Check if the task hasn't been cancelled before updating UI
            self.accounts = fetchedAccounts
            self.lastRefreshDate = Date()
            self.isLoading = false
        } catch let upError as UpBankError {
            self.isLoading = false
            self.error = "Failed to refresh data: \(upError.message)"
        } catch {
            self.isLoading = false
            
            // Handle task cancellation separately to avoid showing error message
            if error is CancellationError || 
               (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                print("Refresh was cancelled")
                // Don't set error message for cancellation
            } else {
                self.error = "Failed to refresh data: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets the total balance across all accounts
    var totalBalance: String {
        let totalInBaseUnits = accounts.reduce(0) { $0 + $1.attributes.balance.valueInBaseUnits }
        
        // Assuming AUD with 100 base units = 1 dollar
        let dollars = Double(totalInBaseUnits) / 100.0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = accounts.first?.attributes.balance.currencyCode ?? "AUD"
        
        return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
    }
    
    /// Gets the formatted balance for a specific account
    func formattedBalance(for account: Account) -> String {
        let baseUnits = account.attributes.balance.valueInBaseUnits
        let dollars = Double(baseUnits) / 100.0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.attributes.balance.currencyCode
        
        return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
    }
} 