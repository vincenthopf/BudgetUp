import SwiftUI

struct TokenInputView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var isShowingInstructions = false
    @FocusState private var isTokenFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo and title
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Up Bank Sync")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Connect to your Up Bank account")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    
                    // Instructions section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter your Up Bank Personal Access Token")
                            .font(.headline)
                        
                        HStack {
                            Text("Your token connects this app to your Up Bank account.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                isShowingInstructions.toggle()
                            } label: {
                                Text("Get a token")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Token input field
                    VStack(spacing: 8) {
                        SecureField("Personal Access Token", text: $viewModel.apiToken)
                            .font(.body)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(.separator), lineWidth: 1)
                            )
                            .focused($isTokenFieldFocused)
                    }
                    .padding(.horizontal)
                    
                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Connect button
                    Button {
                        isTokenFieldFocused = false
                        Task {
                            await viewModel.saveToken()
                        }
                    } label: {
                        Text("Connect")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .disabled(viewModel.apiToken.isEmpty || viewModel.isAuthenticating)
                    
                    if viewModel.isAuthenticating {
                        ProgressView()
                            .padding(.top)
                    }
                    
                    // Token security notice
                    VStack(spacing: 12) {
                        Text("Your token is stored securely on this device only")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("UpGo never transmits your token to our servers")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Connect to Up Bank")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingInstructions) {
                TokenInstructionsView()
            }
        }
    }
}

struct TokenInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("How to get your Personal Access Token")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        instructionStep(
                            number: 1,
                            title: "Open the Up app",
                            description: "Launch the Up Bank app on your phone"
                        )
                        
                        instructionStep(
                            number: 2,
                            title: "Go to Data sharing",
                            description: "Swipe right and select \"Data sharing\" from the menu"
                        )
                        
                        instructionStep(
                            number: 3,
                            title: "Access Personal Access Token",
                            description: "Tap on \"Personal Access Token\""
                        )
                        
                        instructionStep(
                            number: 4,
                            title: "Generate a token",
                            description: "Select \"Generate a token\" and follow the prompts"
                        )
                        
                        instructionStep(
                            number: 5,
                            title: "Copy your token",
                            description: "Copy the token and return to this app to paste it"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Personal Access Tokens")
                            .font(.headline)
                        
                        Text("Your Personal Access Token provides read-only access to your Up Bank data. You can revoke it at any time from the Up app. Never share your token with others or post it online.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Get Your Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func instructionStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    TokenInputView(viewModel: AuthViewModel())
} 