import SwiftUI

struct DashboardView: View {
    @ObservedObject var accountsViewModel: AccountsViewModel
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Total Balance Card
                        VStack(spacing: 16) {
                            Text("Total Balance")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(accountsViewModel.totalBalance)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            if let lastRefresh = accountsViewModel.lastRefreshDate {
                                Text("Last updated: \(formattedDate(lastRefresh))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Accounts List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Accounts")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            if accountsViewModel.accounts.isEmpty && accountsViewModel.error == nil && !accountsViewModel.isLoading {
                                Text("No accounts found")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(accountsViewModel.accounts) { account in
                                    AccountCard(account: account, formattedBalance: accountsViewModel.formattedBalance(for: account))
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Recent Transactions Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Transactions")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                NavigationLink(destination: TransactionsListView(viewModel: accountsViewModel.transactionsViewModel)) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            if accountsViewModel.transactionsViewModel.transactions.isEmpty && 
                               !accountsViewModel.transactionsViewModel.isLoading {
                                Text("No recent transactions")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.separator), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 1) {
                                    // Show at most 5 recent transactions
                                    ForEach(accountsViewModel.transactionsViewModel.transactions.prefix(5)) { transaction in
                                        NavigationLink(
                                            destination: TransactionDetailView(
                                                transaction: transaction,
                                                viewModel: accountsViewModel.transactionsViewModel
                                            )
                                        ) {
                                            SharedTransactionRow(transaction: transaction)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Divider()
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 32)
                }
                .refreshable {
                    await refreshData()
                }
                
                // Error view
                if let error = accountsViewModel.error {
                    ErrorView(errorMessage: error) {
                        Task {
                            await accountsViewModel.fetchAccounts()
                        }
                    }
                }
                
                // Loading view
                if accountsViewModel.isLoading {
                    LoadingOverlay(message: "Fetching accounts...")
                }
            }
            .navigationTitle("Dashboard")
            .task {
                if accountsViewModel.accounts.isEmpty {
                    await accountsViewModel.fetchAccounts()
                }
                
                // Fetch transactions if needed
                if accountsViewModel.transactionsViewModel.transactions.isEmpty {
                    await accountsViewModel.transactionsViewModel.fetchTransactions()
                }
            }
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        
        // Use a simpler approach without try-catch since our viewModel methods don't throw
        // They handle errors internally
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await accountsViewModel.fetchAccounts()
            }
            
            group.addTask {
                await accountsViewModel.transactionsViewModel.fetchTransactions()
            }
            
            // Wait for all tasks to complete
            for await _ in group { }
        }
        
        isRefreshing = false
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AccountCard: View {
    let account: Account
    let formattedBalance: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.attributes.displayName)
                        .font(.headline)
                    
                    Text(account.attributes.accountType.rawValue.capitalized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formattedBalance)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 4)
    }
}

#Preview {
    let viewModel = AccountsViewModel()
    
    // Add some mock accounts for preview
    let mockAccounts = [
        Account(
            id: "1",
            attributes: AccountAttributes(
                displayName: "Spending",
                accountType: .transactional,
                ownershipType: .individual,
                balance: MoneyObject(
                    currencyCode: "AUD",
                    value: "1234.56",
                    valueInBaseUnits: 123456
                ),
                createdAt: Date()
            ),
            relationships: nil
        ),
        Account(
            id: "2",
            attributes: AccountAttributes(
                displayName: "Savings",
                accountType: .saver,
                ownershipType: .individual,
                balance: MoneyObject(
                    currencyCode: "AUD",
                    value: "5678.90",
                    valueInBaseUnits: 567890
                ),
                createdAt: Date()
            ),
            relationships: nil
        )
    ]
    
    DashboardView(accountsViewModel: viewModel)
} 