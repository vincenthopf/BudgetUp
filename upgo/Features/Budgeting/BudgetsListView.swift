import SwiftUI
// Import shared components
import Foundation

struct BudgetsListView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingCreateSheet = false
    @State private var isTokenSheetPresented = false
    @State private var tokenInput = ""
    @State private var isSubmittingToken = false
    @State private var showAllBudgets = true
    @State private var selectedBudget: Budget? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.needsApiToken {
                        apiTokenSection
                    } else if viewModel.isLoading {
                        loadingSection
                    } else if viewModel.budgets.isEmpty {
                        emptyStateSection
                    } else {
                        // Show budgets
                        overviewSection
                        
                        HStack {
                            Toggle("Show All Budgets", isOn: $showAllBudgets)
                                .font(.subheadline)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        budgetsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.needsApiToken)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.needsApiToken {
                        Button(action: {
                            Task {
                                await viewModel.refreshBudgetData()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                NavigationView {
                    CreateBudgetView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showingCreateSheet = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $isTokenSheetPresented) {
                NavigationView {
                    tokenInputView
                        .navigationTitle("Enter Up API Token")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    isTokenSheetPresented = false
                                }
                            }
                        }
                }
            }
            .alert(title: "Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .sheet(item: $selectedBudget) { budget in
                BudgetDetailView(viewModel: viewModel, budget: budget)
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshBudgetData()
            }
        }
    }
    
    private var apiTokenSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to UpGo")
                .font(.title)
                .fontWeight(.bold)
            
            Text("To get started, please enter your Up Bank Personal Access Token")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                SecureField("Your Up Bank API Token", text: $tokenInput)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button {
                isSubmittingToken = true
            } label: {
                HStack {
                    if isSubmittingToken {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 5)
                    }
                    
                    Text(isSubmittingToken ? "Verifying..." : "Submit")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(width: 200)
                .background(tokenInput.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .disabled(tokenInput.isEmpty || isSubmittingToken)
            
            Link("How to get your token", destination: URL(string: "https://api.up.com.au/getting_started")!)
                .font(.footnote)
                .padding(.top)
        }
        .padding()
    }
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Loading budgets...")
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Budgets Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Create your first budget to start tracking your expenses")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button {
                showingCreateSheet = true
            } label: {
                Text("Create a Budget")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Budget Overview")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(formatCurrency(viewModel.overallRemainingAmount()))
                    .font(.headline)
                    .foregroundColor(viewModel.isOverallOverBudget() ? .red : .green)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Total Budget")
                    Spacer()
                    Text(formatCurrency(viewModel.totalBudgetAmount()))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Total Spent")
                    Spacer()
                    Text(formatCurrency(viewModel.totalSpentAmount()))
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    BudgetProgressBar(
                        value: viewModel.overallProgressPercentage(),
                        color: progressColor(percentage: viewModel.overallProgressPercentage())
                    )
                    
                    HStack {
                        Text("\(Int(viewModel.overallProgressPercentage() * 100))% used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(viewModel.isOverallOverBudget() ? "Over budget" : "Remaining")
                            .font(.caption)
                            .foregroundColor(viewModel.isOverallOverBudget() ? .red : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var budgetsSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Budgets List
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.budgets) { budget in
                        BudgetCardView(budget: budget, viewModel: viewModel)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedBudget = budget
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
        }
        .refreshable {
            Task {
                await viewModel.loadBudgets()
            }
        }
    }
    
    private var tokenInputView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to UpGo")
                .font(.title)
                .fontWeight(.bold)
            
            Text("To get started, please enter your Up Bank Personal Access Token")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                SecureField("Your Up Bank API Token", text: $tokenInput)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button {
                isSubmittingToken = true
            } label: {
                HStack {
                    if isSubmittingToken {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 5)
                    }
                    
                    Text(isSubmittingToken ? "Verifying..." : "Submit")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(width: 200)
                .background(tokenInput.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .disabled(tokenInput.isEmpty || isSubmittingToken)
            
            Link("How to get your token", destination: URL(string: "https://api.up.com.au/getting_started")!)
                .font(.footnote)
                .padding(.top)
        }
        .padding()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD" // Can be made configurable
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func progressColor(percentage: Double) -> Color {
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

struct BudgetCardView: View {
    let budget: Budget
    let viewModel: BudgetViewModel
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Budget Card Header
            budgetHeader
            
            // Budget Progress
            budgetProgress
            
            // Transaction List
            if isExpanded {
                transactionsList
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .animation(.easeInOut, value: isExpanded)
    }
    
    private var budgetHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                // Budget color icon
                Circle()
                    .fill(budget.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name)
                        .font(.headline)
                    
                    if let category = budget.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Budget amounts
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatCurrency(budget.remaining))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(budget.isOverBudget ? .red : .primary)
                    
                    Text(budget.isOverBudget ? "Over budget" : "Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(budget.spent))
                        .foregroundColor(.primary)
                    
                    Text("of \(formatCurrency(budget.amount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var budgetProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            BudgetProgressBar(
                value: budget.progressPercentage,
                color: progressColor(percentage: budget.progressPercentage)
            )
            
            HStack {
                Text("\(Int(budget.progressPercentage * 100))% used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(budget.period.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    )
            }
        }
    }
    
    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            Text("Recent Transactions")
                .font(.subheadline)
                .fontWeight(.medium)
            
            let transactions = viewModel.getTransactionsForBudget(budget)
            
            if transactions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text("No transactions found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                ForEach(transactions.prefix(5), id: \.id) { transaction in
                    SimplifiedTransactionRow(transaction: transaction)
                }
                
                if transactions.count > 5 {
                    HStack {
                        Spacer()
                        
                        Text("+ \(transactions.count - 5) more")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.vertical, 4)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD" // Can be made configurable
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func progressColor(percentage: Double) -> Color {
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    BudgetsListView(viewModel: BudgetViewModel())
} 