import SwiftUI

struct CreateBudgetView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isPresented: Bool
    @State private var showingCategories = false
    @State private var showingTagInput = false
    @State private var tagInput = ""
    @FocusState private var focusedField: Field?
    @State private var animateButton = false
    
    enum Field: Hashable {
        case name
        case amount
        case category
        case tag
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    budgetDetailsSection
                    timePeriodSection
                    appearanceSection
                    createButton
                }
                .padding()
            }
            .navigationTitle("Create Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var budgetDetailsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "Budget Details")
            
            FormField(title: "Budget Name", placeholder: "Enter budget name") {
                TextField("e.g. Groceries", text: $viewModel.newBudgetName)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .amount
                    }
            }
            
            FormField(title: "Budget Amount", placeholder: "Enter budget amount") {
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $viewModel.newBudgetAmount)
                        .focused($focusedField, equals: .amount)
                        .keyboardType(.decimalPad)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = nil
                        }
                }
            }
            
            FormField(title: "Category", placeholder: "Select a category") {
                Button {
                    showingCategories = true
                } label: {
                    HStack {
                        if let categoryName = viewModel.newBudgetCategory {
                            Text(categoryName)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select a category")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
            }
            .sheet(isPresented: $showingCategories) {
                categorySelectionView
            }
            
            FormField(title: "Tags", placeholder: "Add tags to help organize your budget") {
                TagEditor(tags: $viewModel.newBudgetTags)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var timePeriodSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "Time Period")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget Period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Budget Period", selection: $viewModel.newBudgetPeriod) {
                    Text("Weekly").tag(BudgetPeriod.weekly)
                    Text("Monthly").tag(BudgetPeriod.monthly)
                    Text("Yearly").tag(BudgetPeriod.yearly)
                    Text("Custom (30 days)").tag(BudgetPeriod.custom(days: 30))
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                DatePicker("", selection: $viewModel.newBudgetStartDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "Appearance")
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Budget Color")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                colorSelector
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var colorSelector: some View {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .cyan, .yellow, .mint, .indigo]
        
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
            ForEach(colors, id: \.self) { color in
                colorButton(color)
            }
        }
    }
    
    private func colorButton(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: viewModel.newBudgetColor == color ? 2 : 0)
                    .padding(2)
            )
            .overlay(
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .opacity(viewModel.newBudgetColor == color ? 1 : 0)
            )
            .onTapGesture {
                withAnimation(.spring()) {
                    viewModel.newBudgetColor = color
                }
            }
    }
    
    private var createButton: some View {
        Button {
            createBudget()
        } label: {
            Text("Create Budget")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFormValid ? viewModel.newBudgetColor : Color.gray)
                )
                .scaleEffect(animateButton ? 0.98 : 1)
        }
        .disabled(!isFormValid)
        .onTapGesture {
            // Add a small animation effect
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                animateButton = true
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                animateButton = false
            }
        }
    }
    
    // MARK: - Helpers
    
    // Computed property to check if the form is valid
    private var isFormValid: Bool {
        !viewModel.newBudgetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.newBudgetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Double(viewModel.newBudgetAmount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }
    
    private func createBudget() {
        // Hide keyboard
        focusedField = nil
        
        let success = viewModel.createBudget()
        if success {
            isPresented = false
        }
    }
    
    private var categorySelectionView: some View {
        NavigationView {
            List {
                Section(header: Text("Categories")) {
                    Button {
                        viewModel.newBudgetCategory = nil
                        viewModel.newBudgetCategoryId = nil
                        showingCategories = false
                    } label: {
                        HStack {
                            Text("None")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if viewModel.newBudgetCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    ForEach(viewModel.categories) { category in
                        Button {
                            viewModel.newBudgetCategory = category.attributes.name
                            viewModel.newBudgetCategoryId = category.id
                            showingCategories = false
                        } label: {
                            HStack {
                                Text(category.attributes.name)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if viewModel.newBudgetCategoryId == category.id {
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
                        showingCategories = false
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
}

struct FormField<Content: View>: View {
    let title: String
    let placeholder: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            content()
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
        }
    }
}

#Preview {
    CreateBudgetView(viewModel: BudgetViewModel(), isPresented: .constant(true))
} 