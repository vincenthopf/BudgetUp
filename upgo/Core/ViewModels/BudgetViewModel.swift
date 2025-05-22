import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var selectedBudget: Budget? = nil
    @Published var categories: [Category] = []
    @Published var isLoadingCategories: Bool = false
    @Published var needsApiToken: Bool = false
    @Published var relatedTransactions: [String: [Transaction]] = [:]
    
    // For new budget creation
    @Published var newBudgetName: String = ""
    @Published var newBudgetAmount: String = ""
    @Published var newBudgetCategory: String? = nil
    @Published var newBudgetCategoryId: String? = nil
    @Published var newBudgetTags: [String] = []
    @Published var newBudgetPeriod: BudgetPeriod = .monthly
    @Published var newBudgetStartDate: Date = Date()
    @Published var newBudgetColor: Color = .blue
    
    // MARK: - Time-related properties
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }
    
    private var upBankService: UpBankService
    private var cancellables = Set<AnyCancellable>()
    private let coreDataManager = CoreDataManager.shared
    
    // Sample budgets for testing UI
    private let sampleBudgets: [Budget] = [
        Budget(name: "Groceries", amount: 500, spent: 320, category: "Food", categoryId: nil, tags: ["groceries", "essentials"], color: .green),
        Budget(name: "Dining Out", amount: 300, spent: 280, category: "Food", categoryId: nil, tags: ["dining", "restaurants"], color: .orange),
        Budget(name: "Entertainment", amount: 200, spent: 150, category: "Leisure", categoryId: nil, tags: ["entertainment", "movies"], color: .purple),
        Budget(name: "Transportation", amount: 150, spent: 130, category: "Transport", categoryId: nil, tags: ["transport"], color: .blue),
        Budget(name: "Shopping", amount: 250, spent: 400, category: "Shopping", categoryId: nil, tags: ["clothing", "personal"], color: .red)
    ]
    
    nonisolated init(upBankService: UpBankService = UpBankService.shared) {
        self.upBankService = upBankService
        
        // Subscribe to transaction category updates after init
        Task { @MainActor in
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(transactionCategoryUpdated(_:)),
                name: .transactionCategoryUpdated,
                object: nil
            )
            
            // Add observer for new transactions
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(newTransactionsReceived),
                name: .newTransactionsReceived,
                object: nil
            )
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func transactionCategoryUpdated(_ notification: Notification) {
        if let categoryId = notification.userInfo?["categoryId"] as? String {
            // If we have a budget for this category, update its spent amount
            let budgetsForCategory = budgetsForCategoryId(categoryId)
            
            if !budgetsForCategory.isEmpty {
                Task {
                    await updateSpentAmountsForBudgets(withCategoryId: categoryId)
                }
            }
        }
    }
    
    @objc private func newTransactionsReceived() {
        // When new transactions are received, update all budget amounts
        Task {
            await updateSpentAmountsForAllBudgets()
        }
    }
    
    // MARK: - Category Management
    
    func loadCategories() async {
        guard categories.isEmpty else { return }
        
        isLoadingCategories = true
        
        do {
            let fetchedCategories = try await upBankService.fetchCategories()
            DispatchQueue.main.async { [weak self] in
                self?.categories = fetchedCategories
                self?.isLoadingCategories = false
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.error = "Failed to load categories: \(error.localizedDescription)"
                self?.isLoadingCategories = false
            }
        }
    }
    
    func getCategoryName(forId id: String?) -> String? {
        guard let id = id else { return nil }
        return categories.first(where: { $0.id == id })?.attributes.name
    }
    
    func getTransactionsForCategory(categoryId: String) async throws -> [Transaction] {
        return try await upBankService.fetchTransactionsForCategory(categoryId: categoryId)
    }
    
    // MARK: - Budget Management
    
    func loadBudgets() async {
        isLoading = true
        error = nil
        
        // Check if API token is set
        do {
            // Check if we can get a token - if we can, it exists
            var hasToken = false
            do {
                let _ = try await upBankService.getToken()
                hasToken = true
            } catch {
                hasToken = false
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.needsApiToken = !hasToken
            }
            
            if !hasToken {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                }
                return
            }
            
            // Load categories first to support proper budget setup
            if categories.isEmpty {
                await loadCategories()
            }
            
            // Now that we have categories, load the budgets from Core Data
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let fetchedBudgets = self.coreDataManager.fetchBudgets()
                print("BudgetViewModel: Fetched \(fetchedBudgets.count) budgets from storage")
                
                if fetchedBudgets.isEmpty && !UserDefaults.standard.bool(forKey: "hasInitializedBudgets") {
                    // If no budgets exist yet and we haven't initialized before, use sample data
                    print("BudgetViewModel: No stored budgets found, creating sample budgets")
                    
                    // Create sample budgets with proper category IDs
                    var enhancedSampleBudgets = [Budget]()
                    
                    for var budget in self.sampleBudgets {
                        // Try to find a matching category ID by name
                        if let categoryName = budget.category, !categoryName.isEmpty {
                            if let matchingCategory = self.categories.first(where: { 
                                $0.attributes.name.lowercased() == categoryName.lowercased() 
                            }) {
                                print("BudgetViewModel: Matched category '\(categoryName)' with ID: \(matchingCategory.id)")
                                budget.categoryId = matchingCategory.id
                            } else {
                                print("BudgetViewModel: Could not find matching category for '\(categoryName)'")
                            }
                        }
                        enhancedSampleBudgets.append(budget)
                    }
                    
                    self.budgets = enhancedSampleBudgets
                    
                    // Save enhanced sample budgets to Core Data
                    for budget in enhancedSampleBudgets {
                        self.saveBudgetToStorage(budget)
                    }
                    
                    // Mark that we've initialized the budgets
                    UserDefaults.standard.set(true, forKey: "hasInitializedBudgets")
                } else {
                    // Use the budgets from Core Data
                    self.budgets = fetchedBudgets
                }
                
                // Load the transaction data for each budget
                Task {
                    print("BudgetViewModel: Updating spent amounts for all budgets...")
                    await self.updateSpentAmountsForAllBudgets()
                    
                    // Update UI once we have the spent amounts
                    DispatchQueue.main.async {
                        self.isLoading = false
                        print("BudgetViewModel: Finished loading budgets")
                    }
                }
            }
        } catch {
            print("BudgetViewModel: Error during budget loading: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.error = "Failed to load budgets: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            // Still try to load any local budgets if API fails
            self.loadStoredBudgetsOnly()
        }
    }
    
    /// Loads only locally stored budgets when API fails
    private func loadStoredBudgetsOnly() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("BudgetViewModel: Loading stored budgets only (fallback)")
            let fetchedBudgets = self.coreDataManager.fetchBudgets()
            self.budgets = fetchedBudgets
            
            // Try to update spent amounts for budgets with known category IDs
            Task {
                await self.updateSpentAmountsForAllBudgets()
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("BudgetViewModel: Finished loading stored budgets only")
                }
            }
        }
    }
    
    func createBudget() -> Bool {
        guard validateNewBudget() else { return false }
        
        // Convert amount string to Double
        guard let amount = Double(newBudgetAmount.replacingOccurrences(of: ",", with: ".")) else {
            error = "Invalid amount format"
            return false
        }
        
        // Get the category name if we have a categoryId
        let categoryName = newBudgetCategory ?? getCategoryName(forId: newBudgetCategoryId)
        
        let categoryId = newBudgetCategoryId
        
        // If we have a category name but no ID, try to find the ID from loaded categories
        let resolvedCategoryId: String? = {
            if let existingId = categoryId, !existingId.isEmpty {
                return existingId
            } else if let name = categoryName, !name.isEmpty {
                // Try to find category ID by name
                return categories.first(where: { 
                    $0.attributes.name.lowercased() == name.lowercased() 
                })?.id
            }
            return nil
        }()
        
        let newBudget = Budget(
            name: newBudgetName,
            amount: amount,
            category: categoryName,
            categoryId: resolvedCategoryId,
            tags: newBudgetTags,
            period: newBudgetPeriod,
            startDate: newBudgetStartDate,
            color: newBudgetColor
        )
        
        budgets.append(newBudget)
        saveBudgetToStorage(newBudget)
        resetNewBudgetForm()
        
        // Update the spent amount immediately after creating the budget
        Task { [weak self] in
            if let categoryId = resolvedCategoryId {
                await self?.updateSpentAmountsForBudgets(withCategoryId: categoryId)
            }
            
            // If we have tags, update by tag
            for tag in newBudget.tags {
                await self?.updateSpentAmountForBudgetWithTag(newBudget, tag: tag)
            }
        }
        
        return true
    }
    
    func updateBudget(_ budget: Budget) {
        if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
            budgets[index] = budget
            
            // Save to Core Data
            updateBudgetInStorage(budget)
            
            // Update the spent amount for the updated budget
            Task { [weak self] in
                if let categoryId = budget.categoryId {
                    await self?.updateSpentAmountsForBudgets(withCategoryId: categoryId)
                }
                
                // If we have tags, update by tag
                for tag in budget.tags {
                    await self?.updateSpentAmountForBudgetWithTag(budget, tag: tag)
                }
            }
        }
    }
    
    func deleteBudget(_ budget: Budget) {
        budgets.removeAll { $0.id == budget.id }
        
        // Delete from Core Data
        deleteBudgetFromStorage(budget)
        
        // Remove any cached transactions for this budget
        DispatchQueue.main.async { [weak self] in
            self?.relatedTransactions[budget.id.uuidString] = nil
        }
    }
    
    // MARK: - Storage Methods
    
    private func saveBudgetToStorage(_ budget: Budget) {
        coreDataManager.saveBudget(budget)
    }
    
    private func updateBudgetInStorage(_ budget: Budget) {
        coreDataManager.updateBudget(budget)
    }
    
    private func deleteBudgetFromStorage(_ budget: Budget) {
        coreDataManager.deleteBudget(withId: budget.id)
    }
    
    // MARK: - Transaction and Category Integration
    
    /// Updates spent amounts for all budgets
    func updateSpentAmountsForAllBudgets() async {
        // Update category-based budgets
        for budget in budgets {
            if let categoryId = budget.categoryId {
                await updateSpentAmountForBudget(budget, categoryId: categoryId)
            }
            
            // If the budget has tags, update based on tags
            for tag in budget.tags {
                await updateSpentAmountForBudgetWithTag(budget, tag: tag)
            }
        }
    }
    
    /// Updates spent amounts for budgets with a specific category ID
    func updateSpentAmountsForBudgets(withCategoryId categoryId: String) async {
        for budget in budgetsForCategoryId(categoryId) {
            await updateSpentAmountForBudget(budget, categoryId: categoryId)
        }
    }
    
    /// Updates spent amount for a single budget by category ID
    private func updateSpentAmountForBudget(_ budget: Budget, categoryId: String) async {
        do {
            // Fetch transactions for this category within the budget period
            let since = budget.startDate
            let until = budget.endDate()
            
            let transactions = try await upBankService.fetchTransactionsForCategory(
                categoryId: categoryId,
                since: since,
                pageSize: 100
            )
            
            // Calculate total spent amount
            let spent = calculateSpentAmount(from: transactions)
            
            // Cache the transactions for this budget
            DispatchQueue.main.async { [weak self] in
                self?.relatedTransactions[budget.id.uuidString] = transactions
            }
            
            // Update budget with new spent amount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let index = self.budgets.firstIndex(where: { $0.id == budget.id }) {
                    var updatedBudget = self.budgets[index]
                    updatedBudget.spent = spent
                    self.budgets[index] = updatedBudget
                    self.updateBudgetInStorage(updatedBudget)
                    
                    print("Updated budget \(budget.name) spent amount to \(spent)")
                }
            }
        } catch {
            print("Error updating spent amount for budget \(budget.name): \(error.localizedDescription)")
        }
    }
    
    /// Updates spent amount for a budget by tag
    func updateSpentAmountForBudgetWithTag(_ budget: Budget, tag: String) async {
        do {
            // Fetch transactions for this tag within the budget period
            let since = budget.startDate
            let until = budget.endDate()
            
            let transactions = try await upBankService.fetchTransactionsWithTag(
                tagName: tag,
                since: since,
                pageSize: 100
            )
            
            // Calculate total spent amount and update existing transactions
            let existingTransactions = relatedTransactions[budget.id.uuidString] ?? []
            let newTransactions = transactions.filter { transaction in
                !existingTransactions.contains(where: { $0.id == transaction.id })
            }
            
            let combinedTransactions = existingTransactions + newTransactions
            let spent = calculateSpentAmount(from: combinedTransactions)
            
            // Cache the combined transactions for this budget
            DispatchQueue.main.async { [weak self] in
                self?.relatedTransactions[budget.id.uuidString] = combinedTransactions
            }
            
            // Update budget with new spent amount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let index = self.budgets.firstIndex(where: { $0.id == budget.id }) {
                    var updatedBudget = self.budgets[index]
                    updatedBudget.spent = spent
                    self.budgets[index] = updatedBudget
                    self.updateBudgetInStorage(updatedBudget)
                    
                    print("Updated budget \(budget.name) spent amount to \(spent) based on tag \(tag)")
                }
            }
        } catch {
            print("Error updating spent amount for budget \(budget.name) with tag \(tag): \(error.localizedDescription)")
        }
    }
    
    /// Calculate total spent amount from a list of transactions
    private func calculateSpentAmount(from transactions: [Transaction]) -> Double {
        // Sum only negative amounts (expenses) and convert to positive value
        return transactions.reduce(0.0) { total, transaction in
            let amount = Double(transaction.attributes.amount.valueInBaseUnits) / 100.0
            return total + (amount < 0 ? abs(amount) : 0)
        }
    }
    
    /// Get transactions related to a specific budget
    func getTransactionsForBudget(_ budget: Budget) -> [Transaction] {
        return relatedTransactions[budget.id.uuidString] ?? []
    }
    
    /// Validates the new budget form
    private func validateNewBudget() -> Bool {
        // Name should not be empty
        guard !newBudgetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Budget name cannot be empty"
            return false
        }
        
        // Amount should be a valid positive number
        guard let amount = Double(newBudgetAmount.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else {
            error = "Please enter a valid positive amount"
            return false
        }
        
        return true
    }
    
    private func resetNewBudgetForm() {
        newBudgetName = ""
        newBudgetAmount = ""
        newBudgetCategory = nil
        newBudgetCategoryId = nil
        newBudgetTags = []
        newBudgetPeriod = .monthly
        // Ensure we're using the current date in the current time zone
        newBudgetStartDate = Calendar.current.startOfDay(for: Date())
        newBudgetColor = .blue
    }
    
    // MARK: - Stats & Calculations
    
    func totalBudgetAmount() -> Double {
        return budgets.reduce(0) { $0 + $1.amount }
    }
    
    func totalSpentAmount() -> Double {
        return budgets.reduce(0) { $0 + $1.spent }
    }
    
    func overallRemainingAmount() -> Double {
        return totalBudgetAmount() - totalSpentAmount()
    }
    
    func overallProgressPercentage() -> Double {
        let total = totalBudgetAmount()
        guard total > 0 else { return 0 }
        return min(totalSpentAmount() / total, 1.0)
    }
    
    func isOverallOverBudget() -> Bool {
        return totalSpentAmount() > totalBudgetAmount()
    }
    
    func activeBudgets() -> [Budget] {
        return budgets.filter { $0.isActive }
    }
    
    func overBudgetItems() -> [Budget] {
        return budgets.filter { $0.isOverBudget }
    }
    
    func budgetsForCategory(_ category: String) -> [Budget] {
        return budgets.filter { $0.category == category }
    }
    
    func budgetsForCategoryId(_ categoryId: String) -> [Budget] {
        return budgets.filter { $0.categoryId == categoryId }
    }
    
    func budgetsWithTag(_ tag: String) -> [Budget] {
        return budgets.filter { $0.tags.contains(tag) }
    }
    
    /// Checks if the API token is set and valid
    /// - Returns: true if token is valid, false otherwise
    func validateApiToken(token: String) async -> Bool {
        do {
            // First try to store the token
            try await upBankService.storeApiToken(token)
            
            // Then verify it works by pinging the API
            return try await upBankService.verifyToken()
        } catch {
            DispatchQueue.main.async {
                self.error = "Invalid API token: \(error.localizedDescription)"
            }
            return false
        }
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let newTransactionsReceived = Notification.Name("newTransactionsReceived")
} 