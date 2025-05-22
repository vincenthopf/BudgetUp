import Foundation
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    // MARK: - Properties
    private let securityService: SecurityService
    private let upBankService: UpBankService
    
    // Published properties
    @Published var isAuthenticating = false
    @Published var isAuthenticated = false
    @Published var hasToken = false
    @Published var error: String? = nil
    @Published var apiToken: String = ""
    @Published var biometricType: String = "None"
    
    // MARK: - Initialization
    init(securityService: SecurityService = SecurityService(), upBankService: UpBankService = UpBankService()) {
        self.securityService = securityService
        self.upBankService = upBankService
        
        // Check if token exists
        checkToken()
        
        // Get the biometric type
        biometricType = securityService.getBiometricType()
    }
    
    // MARK: - Public Methods
    
    /// Saves the API token to the keychain
    func saveToken() async {
        guard !apiToken.isEmpty else {
            self.error = "Please enter a valid API token"
            return
        }
        
        isAuthenticating = true
        self.error = nil
        
        do {
            // Try to verify the token first
            try await verifyToken(apiToken)
            
            // If verification succeeds, save the token
            try securityService.storeApiToken(apiToken)
            
            // Update state
            await MainActor.run {
                self.isAuthenticated = true
                self.hasToken = true
                self.isAuthenticating = false
                self.apiToken = "" // Clear the text field for security
            }
        } catch let upError as UpBankError {
            await MainActor.run {
                self.error = upError.message
                self.isAuthenticating = false
            }
        } catch let networkError as NetworkError {
            await MainActor.run {
                self.error = "Network error: \(networkError.message)"
                self.isAuthenticating = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to verify token: \(error.localizedDescription)"
                self.isAuthenticating = false
            }
        }
    }
    
    /// Authenticates the user using the stored token
    func authenticate() async {
        guard hasToken else {
            await MainActor.run {
                self.error = "No token available"
            }
            return
        }
        
        await MainActor.run {
            isAuthenticating = true
            self.error = nil
        }
        
        do {
            // Authenticate with biometrics if available
            if securityService.isBiometricAuthAvailable() {
                try await securityService.authenticateWithBiometrics()
            }
            
            // Verify the token
            let token = try await securityService.getApiToken()
            try await verifyToken(token)
            
            // Update state
            await MainActor.run {
                self.isAuthenticated = true
                self.isAuthenticating = false
            }
        } catch {
            await MainActor.run {
                self.error = "Authentication failed: \(error.localizedDescription)"
                self.isAuthenticating = false
            }
        }
    }
    
    /// Signs out the user
    func signOut() {
        isAuthenticated = false
    }
    
    /// Deletes the stored token
    func deleteToken() async {
        do {
            try securityService.deleteApiToken()
            
            await MainActor.run {
                self.hasToken = false
                self.isAuthenticated = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to delete token: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Checks if a token exists
    private func checkToken() {
        hasToken = securityService.hasApiToken()
    }
    
    /// Verifies the token with the Up Bank API
    private func verifyToken(_ token: String) async throws {
        // Create a temporary service to verify the token
        let tempNetworkService = NetworkService()
        let tempUpBankService = UpBankService(networkService: tempNetworkService, securityService: SecurityService())
        
        // Temporarily store the token for the verification
        try securityService.storeApiToken(token)
        
        // Try to verify with the Up Bank API
        do {
            let _ = try await tempUpBankService.verifyToken()
        } catch {
            print("Token verification error: \(error)")
            throw error
        }
    }
} 