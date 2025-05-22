import SwiftUI

struct LoadingView: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.8))
    }
}

// LoadingOverlay has been moved to its own file: LoadingOverlay.swift

#Preview {
    VStack(spacing: 20) {
        LoadingView(message: "Fetching accounts...")
        
        LoadingOverlay(message: "Syncing transactions...")
            .frame(height: 200)
    }
} 