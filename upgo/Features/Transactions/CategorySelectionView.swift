import SwiftUI

struct CategorySelectionView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @Environment(\.dismiss) private var dismiss
    let transactionId: String
    @State private var selectedCategoryId: String?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoadingCategories {
                    ProgressView("Loading categories...")
                        .padding()
                } else {
                    List {
                        Section(header: Text("Remove Category")) {
                            Button {
                                selectedCategoryId = nil
                                updateCategory()
                            } label: {
                                HStack {
                                    Text("No Category")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategoryId == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Section(header: Text("Categories")) {
                            SearchBar(text: $searchText, placeholder: "Search categories")
                                .padding(.vertical, 4)
                            
                            ForEach(filteredCategories) { category in
                                Button {
                                    selectedCategoryId = category.id
                                    updateCategory()
                                } label: {
                                    HStack {
                                        Text(category.attributes.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if category.id == selectedCategoryId {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load the current category ID if available
                if let categoryLink = viewModel.transactions.first(where: { $0.id == transactionId })?.relationships?.category?.links?.related {
                    // Extract category ID from the URL
                    let urlComponents = categoryLink.absoluteString.components(separatedBy: "/")
                    selectedCategoryId = urlComponents.last
                }
                
                // Load categories if not already loaded
                Task {
                    await viewModel.loadCategories()
                }
            }
        }
    }
    
    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return viewModel.categories
        } else {
            return viewModel.categories.filter { category in
                category.attributes.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private func updateCategory() {
        Task {
            await viewModel.updateTransactionCategory(
                transactionId: transactionId,
                categoryId: selectedCategoryId
            )
            dismiss()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    CategorySelectionView(
        viewModel: TransactionsViewModel(),
        transactionId: "sample-id"
    )
} 