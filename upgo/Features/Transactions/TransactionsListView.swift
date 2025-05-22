import SwiftUI

struct TransactionsListView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @State private var showFilters = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Search and filter bar
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search transactions", text: $searchText)
                                .onChange(of: searchText) { oldValue, newValue in
                                    viewModel.searchText = newValue
                                    Task {
                                        await viewModel.fetchTransactions()
                                    }
                                }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        Button(action: {
                            showFilters.toggle()
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Transactions list
                    if viewModel.transactions.isEmpty && !viewModel.isLoading && viewModel.error == nil {
                        emptyStateView
                    } else {
                        transactionsList
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    LoadingOverlay(message: "Loading transactions...")
                }
                
                // Error view
                if let error = viewModel.error {
                    ErrorView(errorMessage: error) {
                        Task {
                            await viewModel.fetchTransactions()
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .refreshable {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000) // Add a small delay for better UX
                    await viewModel.fetchTransactions()
                } catch {
                    print("Refresh was cancelled: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $showFilters) {
                TransactionFiltersView(viewModel: viewModel)
            }
            .task {
                if viewModel.transactions.isEmpty {
                    await viewModel.fetchTransactions()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Transactions")
                .font(.headline)
            
            Text("Transactions will appear here once you have some activity in your Up Bank account.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Refresh") {
                Task {
                    await viewModel.fetchTransactions()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.transactions) { transaction in
                    NavigationLink(destination: TransactionDetailView(transaction: transaction, viewModel: viewModel)) {
                        SharedTransactionRow(transaction: transaction)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                }
                
                // Load more indicator
                if viewModel.hasMorePages {
                    Button(action: {
                        Task {
                            await viewModel.loadNextPage()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            Text("Load More")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

struct TransactionFiltersView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var selectedStatus: TransactionStatus?
    @State private var selectedAccountId: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date Range")) {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { self.startDate ?? Date().addingTimeInterval(-30*24*60*60) },
                            set: { self.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { self.endDate ?? Date() },
                            set: { self.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
                
                Section(header: Text("Status")) {
                    Picker("Transaction Status", selection: $selectedStatus) {
                        Text("All").tag(nil as TransactionStatus?)
                        Text("Held").tag(TransactionStatus.held)
                        Text("Settled").tag(TransactionStatus.settled)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button("Apply Filters") {
                        viewModel.filterStartDate = startDate
                        viewModel.filterEndDate = endDate
                        viewModel.filterStatus = selectedStatus
                        viewModel.selectedAccountId = selectedAccountId
                        
                        Task {
                            await viewModel.fetchTransactions()
                        }
                        
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                    
                    Button("Reset Filters") {
                        startDate = nil
                        endDate = nil
                        selectedStatus = nil
                        selectedAccountId = nil
                        
                        viewModel.filterStartDate = nil
                        viewModel.filterEndDate = nil
                        viewModel.filterStatus = nil
                        viewModel.selectedAccountId = nil
                        
                        Task {
                            await viewModel.fetchTransactions()
                        }
                        
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .onAppear {
                // Initialize with current filter values
                startDate = viewModel.filterStartDate
                endDate = viewModel.filterEndDate
                selectedStatus = viewModel.filterStatus
                selectedAccountId = viewModel.selectedAccountId
            }
        }
    }
}

#Preview {
    TransactionsListView(viewModel: TransactionsViewModel())
} 