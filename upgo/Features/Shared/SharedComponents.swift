import SwiftUI

// MARK: - FlowLayout
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 10) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentWidth + size.width > maxWidth && currentWidth > 0 {
                // Start new row
                height += currentRowHeight + spacing
                currentWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                // Add to current row
                currentWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        
        // Add last row height
        height += currentRowHeight
        
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                // Move to next row
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// FlowLayout variant that wraps content in a View
struct SharedViewFlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content
    
    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        let items = ViewThatFits { content() }
        
        VStack(alignment: alignment, spacing: spacing) {
            items
        }
    }
}

// MARK: - BudgetProgressBar
struct BudgetProgressBar: View {
    var value: Double
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: geometry.size.height)
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
            }
        }
    }
}

// MARK: - TransactionRow
struct SharedTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            // Transaction icon
            ZStack {
                Circle()
                    .fill(transactionColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transactionIcon)
                    .foregroundColor(transactionColor)
            }
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.attributes.description)
                    .font(.body)
                    .lineLimit(1)
                
                Text(formattedDate(transaction.attributes.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Transaction amount
            Text(formattedAmount(
                value: transaction.attributes.amount.value,
                currencyCode: transaction.attributes.amount.currencyCode
            ))
            .font(.headline)
            .foregroundColor(transaction.attributes.amount.valueInBaseUnits < 0 ? .red : .green)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var transactionIcon: String {
        if transaction.attributes.amount.valueInBaseUnits < 0 {
            return "arrow.up.right"
        } else {
            return "arrow.down.left"
        }
    }
    
    private var transactionColor: Color {
        if transaction.attributes.amount.valueInBaseUnits < 0 {
            return .red
        } else {
            return .green
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

// MARK: - Simplified TransactionRow for BudgetsList
struct SimplifiedTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.attributes.description)
                    .fontWeight(.medium)
                
                Text(formatDate(transaction.attributes.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(transaction.attributes.amount.valueInBaseUnits))
                .fontWeight(.semibold)
                .foregroundColor(transaction.attributes.amount.valueInBaseUnits < 0 ? .red : .green)
        }
        .padding(.vertical, 8)
    }
    
    private func formatCurrency(_ amountInCents: Int) -> String {
        let amount = Double(amountInCents) / 100.0
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
} 