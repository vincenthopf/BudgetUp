import SwiftUI
import Foundation
// Import shared components
import SwiftUI

// Include our shared components
@_exported import Foundation

struct BudgetDetailView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State var budget: Budget
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var showingTransactions = true
    @Environment(\.presentationMode) var presentationMode
    
    // For editing
    @State private var editedName: String = ""
    @State private var editedAmount: String = ""
    @State private var editedCategory: String? = nil
    @State private var editedCategoryId: String? = nil
    @State private var editedTags: [String] = []
    @State private var editedColor: Color = .blue
    @State private var editedPeriod: BudgetPeriod = .monthly
    @State private var showingCategorySelector = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if isEditing {
                    editFormSection
                } else {
                    VStack(spacing: 24) {
                        detailsSection
                        progressSection
                        timeframeSection
                        tagsSection
                        
                        transactionsSection
                        
                        actionsSection
                    }
                }
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Budget" : budget.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isEditing = false
                    }
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Budget"),
                message: Text("Are you sure you want to delete this budget? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    viewModel.deleteBudget(budget)
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Refresh transactions data when view appears
            Task {
                if let categoryId = budget.categoryId {
                    await viewModel.updateSpentAmountsForBudgets(withCategoryId: categoryId)
                }
                
                // Update tag-based transactions if needed
                for tag in budget.tags {
                    await viewModel.updateSpentAmountForBudgetWithTag(budget, tag: tag)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            if !isEditing {
                Circle()
                    .fill(budget.color)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    )
                    .padding(.bottom, 8)
                
                Text(budget.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let category = budget.category {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Budget Details")
            
            VStack(spacing: 12) {
                DetailRow(label: "Amount", value: formatCurrency(budget.amount))
                DetailRow(label: "Spent", value: formatCurrency(budget.spent))
                DetailRow(
                    label: "Remaining", 
                    value: formatCurrency(budget.remaining), 
                    valueColor: budget.isOverBudget ? .red : .green
                )
                DetailRow(label: "Period", value: budget.period.displayName)
                
                if let category = budget.category {
                    DetailRow(label: "Category", value: category)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Progress")
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(Int(budget.progressPercentage * 100))% Used")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(budget.isOverBudget ? "Over Budget" : "On Track")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(budget.isOverBudget ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                        )
                        .foregroundColor(budget.isOverBudget ? .red : .green)
                }
                
                BudgetProgressBar(
                    value: budget.progressPercentage,
                    color: progressColor(percentage: budget.progressPercentage)
                )
                .frame(height: 20)
                
                HStack {
                    Text("$0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatCurrency(budget.amount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var timeframeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Time Period")
            
            VStack(spacing: 12) {
                DetailRow(label: "Start Date", value: formatDate(budget.startDate))
                DetailRow(label: "End Date", value: formatDate(budget.endDate()))
                
                // Show days remaining
                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: budget.endDate()).day ?? 0
                DetailRow(
                    label: "Days Remaining", 
                    value: daysRemaining > 0 ? "\(daysRemaining) days" : "Ended",
                    valueColor: daysRemaining > 0 ? .primary : .secondary
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Tags")
            
            if budget.tags.isEmpty {
                Text("No tags")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(budget.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.tertiarySystemBackground))
                            )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Transactions")
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingTransactions.toggle()
                    }
                } label: {
                    Image(systemName: showingTransactions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .imageScale(.medium)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
            }
            
            if showingTransactions {
                let transactions = viewModel.getTransactionsForBudget(budget)
                
                if transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        Text("No transactions found")
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 2) {
                        ForEach(transactions.prefix(10), id: \.id) { transaction in
                            TransactionListItem(transaction: transaction)
                                .padding(.vertical, 8)
                            
                            if transaction.id != transactions.prefix(10).last?.id {
                                Divider()
                            }
                        }
                        
                        if transactions.count > 10 {
                            HStack {
                                Spacer()
                                Text("+ \(transactions.count - 10) more transactions")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .animation(.easeInOut, value: showingTransactions)
    }
    
    private var actionsSection: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                Spacer()
                
                Image(systemName: "trash")
                    .foregroundColor(.red)
                
                Text("Delete Budget")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemRed).opacity(0.1))
            )
        }
    }
    
    private var editFormSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget Name")
                    .font(.headline)
                
                TextField("Budget Name", text: $editedName)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.headline)
                
                TextField("Amount", text: $editedAmount)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.headline)
                
                if let category = editedCategory {
                    HStack {
                        Text(category)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            showingCategorySelector = true
                        } label: {
                            Text("Change")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                } else {
                    Button {
                        showingCategorySelector = true
                    } label: {
                        Text("Select Category")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .sheet(isPresented: $showingCategorySelector) {
                categorySelectionView
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Period")
                    .font(.headline)
                
                Picker("Budget Period", selection: $editedPeriod) {
                    Text("Weekly").tag(BudgetPeriod.weekly)
                    Text("Monthly").tag(BudgetPeriod.monthly)
                    Text("Yearly").tag(BudgetPeriod.yearly)
                    Text("Custom (30 days)").tag(BudgetPeriod.custom(days: 30))
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                
                HStack {
                    TagEditor(tags: $editedTags)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Color")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach([Color.blue, Color.green, Color.orange, Color.red, Color.purple, Color.pink, Color.cyan, Color.yellow], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: editedColor == color ? 2 : 0)
                                    .padding(2)
                            )
                            .onTapGesture {
                                editedColor = color
                            }
                    }
                }
            }
        }
    }
    
    private var categorySelectionView: some View {
        NavigationView {
            List {
                Section(header: Text("Categories")) {
                    Button {
                        editedCategory = nil
                        editedCategoryId = nil
                        showingCategorySelector = false
                    } label: {
                        HStack {
                            Text("None")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if editedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    ForEach(viewModel.categories) { category in
                        Button {
                            editedCategory = category.attributes.name
                            editedCategoryId = category.id
                            showingCategorySelector = false
                        } label: {
                            HStack {
                                Text(category.attributes.name)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if editedCategoryId == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showingCategorySelector = false
                    }
                }
            }
            .onAppear {
                if viewModel.categories.isEmpty {
                    Task {
                        await viewModel.loadCategories()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startEditing() {
        editedName = budget.name
        editedAmount = String(format: "%.2f", budget.amount)
        editedCategory = budget.category
        editedCategoryId = budget.categoryId
        editedTags = budget.tags
        editedColor = budget.color
        editedPeriod = budget.period
        
        isEditing = true
    }
    
    private func saveChanges() {
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let amount = Double(editedAmount.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        
        // Check if we need to get a category name from the category ID
        let categoryName: String?
        if let categoryId = editedCategoryId {
            categoryName = viewModel.getCategoryName(forId: categoryId) ?? editedCategory
        } else {
            categoryName = editedCategory
        }
        
        var updatedBudget = budget
        updatedBudget.name = editedName
        updatedBudget.amount = amount
        updatedBudget.category = categoryName
        updatedBudget.categoryId = editedCategoryId
        updatedBudget.tags = editedTags
        updatedBudget.color = editedColor
        updatedBudget.period = editedPeriod
        
        viewModel.updateBudget(updatedBudget)
        budget = updatedBudget
        isEditing = false
        
        // Update transactions for the updated budget
        Task {
            if let categoryId = updatedBudget.categoryId {
                await viewModel.updateSpentAmountsForBudgets(withCategoryId: categoryId)
            }
            
            for tag in updatedBudget.tags {
                await viewModel.updateSpentAmountForBudgetWithTag(updatedBudget, tag: tag)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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

// Required components
// FlowLayout has been moved to SharedComponents.swift

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct TagEditor: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
                
                HStack {
                    TextField("Add tag", text: $newTag)
                        .font(.caption)
                        .frame(width: 100)
                    
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            newTag = ""
        }
    }
}

// BudgetProgressBar has been moved to SharedComponents.swift

struct TransactionListItem: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.attributes.description)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(formattedDate(transaction.attributes.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let message = transaction.attributes.message, !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(transaction.attributes.amount.valueInBaseUnits))
                .fontWeight(.semibold)
                .foregroundColor(transaction.attributes.amount.valueInBaseUnits < 0 ? .red : .green)
        }
    }
    
    private var iconBackgroundColor: Color {
        let amount = transaction.attributes.amount.valueInBaseUnits
        return amount < 0 ? .red : .green
    }
    
    private var iconName: String {
        let amount = transaction.attributes.amount.valueInBaseUnits
        return amount < 0 ? "arrow.down.circle" : "arrow.up.circle"
    }
    
    private func formatCurrency(_ amountInBaseUnits: Int) -> String {
        let amount = Double(amountInBaseUnits) / 100.0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        BudgetDetailView(
            viewModel: BudgetViewModel(),
            budget: Budget(
                name: "Groceries",
                amount: 500,
                spent: 320,
                category: "Food",
                tags: ["essentials", "home"]
            )
        )
    }
} 