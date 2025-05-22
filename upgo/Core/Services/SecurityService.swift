import Foundation
import Security
import LocalAuthentication

enum SecurityError: Error {
    case keychainError(OSStatus)
    case biometricError(Error)
    case tokenNotFound
    case biometricsNotAvailable
    case authenticationFailed
    
    var message: String {
        switch self {
        case .keychainError(let status):
            return "Keychain error with code: \(status)"
        case .biometricError(let error):
            return "Biometric error: \(error.localizedDescription)"
        case .tokenNotFound:
            return "API token not found"
        case .biometricsNotAvailable:
            return "Biometric authentication not available"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

class SecurityService {
    // MARK: - Constants
    private enum KeychainKeys {
        static let apiToken = "com.upgo.apiToken"
        static let service = "com.upgo.keychain"
    }
    
    // MARK: - Token Management
    
    /// Stores the API token securely in the keychain
    /// - Parameter token: The API token to store
    func storeApiToken(_ token: String) throws {
        let tokenData = token.data(using: .utf8)!
        
        // Create query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKeys.apiToken,
            kSecAttrService as String: KeychainKeys.service,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing token
        SecItemDelete(query as CFDictionary)
        
        // Add the new token
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw SecurityError.keychainError(status)
        }
    }
    
    /// Retrieves the API token from the keychain
    /// - Parameter useBiometrics: Whether to use biometric authentication before retrieving the token
    /// - Returns: The API token if found
    func getApiToken(useBiometrics: Bool = false) async throws -> String {
        print("SecurityService: Attempting to get API token (useBiometrics: \(useBiometrics))")
        
        if useBiometrics {
            print("SecurityService: Authenticating with biometrics...")
            try await authenticateWithBiometrics()
            print("SecurityService: Biometric authentication successful")
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKeys.apiToken,
            kSecAttrService as String: KeychainKeys.service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        print("SecurityService: Querying keychain for API token")
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status != errSecSuccess {
            let errorMessage: String
            switch status {
            case errSecItemNotFound:
                errorMessage = "Token not found in keychain"
            case errSecUserCanceled:
                errorMessage = "User canceled the operation"
            case errSecAuthFailed:
                errorMessage = "Authentication failed"
            default:
                errorMessage = "Unknown keychain error (\(status))"
            }
            print("SecurityService: Failed to retrieve token - \(errorMessage)")
            throw SecurityError.tokenNotFound
        }
        
        guard let data = item as? Data else {
            print("SecurityService: Retrieved item is not valid data")
            throw SecurityError.tokenNotFound
        }
        
        guard let token = String(data: data, encoding: .utf8) else {
            print("SecurityService: Could not decode token data to string")
            throw SecurityError.tokenNotFound
        }
        
        // Validate the token has some content
        if token.isEmpty {
            print("SecurityService: Retrieved token is empty")
            throw SecurityError.tokenNotFound
        }
        
        print("SecurityService: Successfully retrieved API token (length: \(token.count))")
        
        // Display a masked version of the token for debugging (show first 3 chars)
        if token.count > 5 {
            let visiblePart = String(token.prefix(3))
            let maskedPart = String(repeating: "*", count: token.count - 3)
            print("SecurityService: Token starts with: \(visiblePart)\(maskedPart)")
        }
        
        return token
    }
    
    /// Deletes the API token from the keychain
    func deleteApiToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKeys.apiToken,
            kSecAttrService as String: KeychainKeys.service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecurityError.keychainError(status)
        }
    }
    
    /// Checks if an API token exists in the keychain
    /// - Returns: `true` if a token exists, `false` otherwise
    func hasApiToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeychainKeys.apiToken,
            kSecAttrService as String: KeychainKeys.service,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Biometric Authentication
    
    /// Authenticates the user using biometrics (Face ID/Touch ID)
    /// - Returns: `true` if authentication succeeds, throws an error otherwise
    func authenticateWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw SecurityError.biometricError(error)
            } else {
                throw SecurityError.biometricsNotAvailable
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access your Up Bank data") { success, error in
                if success {
                    continuation.resume()
                } else if let error = error {
                    continuation.resume(throwing: SecurityError.biometricError(error))
                } else {
                    continuation.resume(throwing: SecurityError.authenticationFailed)
                }
            }
        }
    }
    
    /// Checks if biometric authentication is available on the device
    /// - Returns: `true` if available, `false` otherwise
    func isBiometricAuthAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Gets the type of biometric authentication available on the device
    /// - Returns: A string describing the biometric type ("Face ID", "Touch ID", or "None")
    func getBiometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "None"
        }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "None"
        }
    }
} 