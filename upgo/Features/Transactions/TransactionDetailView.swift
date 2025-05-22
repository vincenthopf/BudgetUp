import SwiftUI
// Import shared components
import Foundation
// We don't need to import SharedComponents since it's part of the same module

struct TransactionDetailView: View {
    let transaction: Transaction
    @ObservedObject var viewModel: TransactionsViewModel
    
    @State private var showingTagSheet = false
    @State private var showingCategorySheet = false
    @State private var selectedTags: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Transaction amount
                VStack(spacing: 10) {
                    Text(formattedAmount(
                        value: transaction.attributes.amount.value,
                        currencyCode: transaction.attributes.amount.currencyCode
                    ))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.attributes.amount.valueInBaseUnits < 0 ? .red : .green)
                    
                    Text(transaction.attributes.status.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(transaction.attributes.status == .settled ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(.vertical, 16)
                
                // Transaction details
                VStack(spacing: 20) {
                    detailRow(title: "Description", value: transaction.attributes.description)
                    
                    if let message = transaction.attributes.message, !message.isEmpty {
                        detailRow(title: "Message", value: message)
                    }
                    
                    detailRow(title: "Date", value: formattedDate(transaction.attributes.createdAt))
                    
                    if let settled = transaction.attributes.settledAt {
                        detailRow(title: "Settled Date", value: formattedDate(settled))
                    }
                    
                    if let rawText = transaction.attributes.rawText, !rawText.isEmpty {
                        detailRow(title: "Raw Description", value: rawText)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // Category section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Category")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    categorySection
                        .padding(.horizontal)
                }
                
                // Tags section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tags")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if selectedTags.isEmpty {
                        HStack {
                            Text("No tags")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Add") {
                                showingTagSheet = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedTags, id: \.self) { tag in
                                        Text(tag)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.blue.opacity(0.2))
                                            )
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Button("Manage Tags") {
                                showingTagSheet = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }
                }

                // Related accounts section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Account Information")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    accountInfoSection
                }
                
                // Additional info for round-up/cashback
                if transaction.attributes.roundUp != nil || transaction.attributes.cashback != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Additional Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        additionalInfoSection
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTagSheet) {
            TagSelectionView(selectedTags: $selectedTags)
        }
        .sheet(isPresented: $showingCategorySheet) {
            CategorySelectionView(viewModel: viewModel, transactionId: transaction.id)
        }
        .onAppear {
            // Load categories if not already loaded
            Task {
                await viewModel.loadCategories()
            }
            
            // Here we would fetch any existing tags
            selectedTags = ["groceries", "food"] // Example for preview
        }
    }
    
    private var categorySection: some View {
        Button {
            showingCategorySheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let categoryLink = transaction.relationships?.category?.links?.related {
                        // Extract category ID from the URL
                        let urlComponents = categoryLink.absoluteString.components(separatedBy: "/")
                        if let categoryId = urlComponents.last,
                           let categoryName = viewModel.getCategoryName(for: categoryId) {
                            Text(categoryName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Text("Loading category...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No category")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!transaction.attributes.isCategorizable)
    }
    
    private var accountInfoSection: some View {
        VStack {
            if let accountLink = transaction.relationships?.account.links?.related {
                Button(action: {
                    // Navigate to account details
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Account")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(accountLink.absoluteString.components(separatedBy: "/").last ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
            
            if let transferLink = transaction.relationships?.transferAccount?.links?.related {
                Button(action: {
                    // Navigate to transfer account details
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transfer Account")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(transferLink.absoluteString.components(separatedBy: "/").last ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var additionalInfoSection: some View {
        VStack {
            if let roundUp = transaction.attributes.roundUp {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Round-Up Amount")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(formattedAmount(
                            value: roundUp.amount.value,
                            currencyCode: roundUp.amount.currencyCode
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let boost = roundUp.boostPortion {
                        Text("Boost: \(formattedAmount(value: boost.value, currencyCode: boost.currencyCode))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
            }
            
            if let cashback = transaction.attributes.cashback {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cashback: \(cashback.description)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(formattedAmount(
                            value: cashback.amount.value,
                            currencyCode: cashback.amount.currencyCode
                        ))
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedAmount(value: String, currencyCode: String) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currencyCode
        
        if let number = Double(value) {
            return numberFormatter.string(from: NSNumber(value: number)) ?? value
        }
        
        return value
    }
}

// A placeholder for tag selection
struct TagSelectionView: View {
    @Binding var selectedTags: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Tag Selection - to be implemented")
                .navigationTitle("Select Tags")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    let sampleTransaction = Transaction(
        id: "sample-id",
        attributes: TransactionAttributes(
            description: "Grocery Shopping",
            message: "Weekly groceries",
            amount: MoneyObject(currencyCode: "AUD", value: "-85.50", valueInBaseUnits: -8550),
            status: .settled,
            rawText: "WOOLWORTHS 1234 SYDNEY",
            isCategorizable: true,
            holdInfo: nil,
            roundUp: RoundUp(
                amount: MoneyObject(currencyCode: "AUD", value: "0.50", valueInBaseUnits: 50),
                boostPortion: nil
            ),
            cashback: nil,
            createdAt: Date(),
            settledAt: Date()
        ),
        relationships: nil
    )
    
    return NavigationView {
        TransactionDetailView(transaction: sampleTransaction, viewModel: TransactionsViewModel())
    }
} 