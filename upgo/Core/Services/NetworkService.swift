import Foundation
import Combine

// Remove the protocol and extension as they're causing type issues
// Instead we'll handle this directly in the performRequest method

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(DecodingError? = nil)
    case unauthorized
    case forbidden
    case serverError(Int)
    case rateLimited
    case tooManyRetries
    case invalidResponse
    case unknown(Error)
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            if let error = error {
                switch error {
                case .keyNotFound(let key, let context):
                    return "Error decoding the data: Key '\(key.stringValue)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                case .typeMismatch(let type, let context):
                    return "Error decoding the data: Type '\(type)' mismatch at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                case .valueNotFound(let type, let context):
                    return "Error decoding the data: Value of type '\(type)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                case .dataCorrupted(let context):
                    return "Error decoding the data: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                @unknown default:
                    return "Error decoding the data: \(error.localizedDescription)"
                }
            }
            return "Error decoding the data"
        case .unauthorized:
            return "Unauthorized access. Please check your API token"
        case .forbidden:
            return "Forbidden. You do not have permission to access this resource."
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .tooManyRetries:
            return "Too many retries for the request."
        case .invalidResponse:
            return "Invalid response from the server."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

class NetworkService {
    // MARK: - Properties
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Initialization
    init(session: URLSession = .shared) {
        self.session = session
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom({ decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            if let date = DateFormatter.upBankDateFormatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateStr)")
        })
    }
    
    // MARK: - API Request Methods
    /// Performs a GET request with the provided URL and parameters
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - token: The authorization token
    ///   - parameters: Optional query parameters
    /// - Returns: A publisher with the decoded response or error
    func get<T: Decodable>(url: URL, token: String, parameters: [String: String]? = nil) async throws -> T {
        let request = createRequest(url: url, method: "GET", token: token, parameters: parameters)
        return try await performRequest(request)
    }
    
    /// Performs a POST request with the provided URL and body
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - token: The authorization token
    ///   - body: The request body
    ///   - parameters: Optional query parameters
    /// - Returns: A publisher with the decoded response or error
    func post<T: Decodable, U: Encodable>(url: URL, token: String, body: U, parameters: [String: String]? = nil) async throws -> T {
        let jsonData = try JSONEncoder().encode(body)
        var request = createRequest(url: url, method: "POST", token: token, parameters: parameters)
        request.httpBody = jsonData
        return try await performRequest(request)
    }
    
    /// Performs a PATCH request with the provided URL and body
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - token: The authorization token
    ///   - body: The request body
    ///   - parameters: Optional query parameters
    /// - Returns: A publisher with the decoded response or error
    func patch<T: Decodable, U: Encodable>(url: URL, token: String, body: U, parameters: [String: String]? = nil) async throws -> T {
        let jsonData = try JSONEncoder().encode(body)
        var request = createRequest(url: url, method: "PATCH", token: token, parameters: parameters)
        request.httpBody = jsonData
        return try await performRequest(request)
    }
    
    /// Performs a PATCH request with the provided URL and body with no expected response
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - token: The authorization token
    ///   - body: The request body (optional)
    ///   - parameters: Optional query parameters
    func patch<U: Encodable>(url: URL, token: String, body: U, parameters: [String: String]? = nil) async throws {
        let jsonData = try JSONEncoder().encode(body)
        var request = createRequest(url: url, method: "PATCH", token: token, parameters: parameters)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "NetworkService", code: -1))
        }
        
        try validateResponse(httpResponse, data: data)
    }
    
    /// Performs a DELETE request with the provided URL
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - token: The authorization token
    ///   - parameters: Optional query parameters
    /// - Returns: A publisher with void or error
    func delete(url: URL, token: String, parameters: [String: String]? = nil) async throws {
        let request = createRequest(url: url, method: "DELETE", token: token, parameters: parameters)
        
        // Use the async URLSession.data task properly
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "NetworkService", code: -1))
        }
        
        try validateResponse(httpResponse, data: data)
    }
    
    // MARK: - Helper Methods
    /// Creates a URLRequest with the specified parameters
    private func createRequest(url: URL, method: String, token: String, parameters: [String: String]? = nil) -> URLRequest {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        
        // Add query parameters if provided
        if let parameters = parameters, !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    /// Performs the request and handles the response
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("⬆️ NETWORK: Sending request to \(request.url?.absoluteString ?? "unknown URL")")
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ NETWORK: Invalid response type received")
            throw NetworkError.unknown(NSError(domain: "NetworkService", code: -1))
        }
        
        // Log the response status and size
        let dataSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        print("⬇️ NETWORK: Received response from \(request.url?.host ?? "unknown") - Status: \(httpResponse.statusCode), Size: \(dataSize), Time: \(String(format: "%.2f", elapsedTime))s")
        
        do {
            try validateResponse(httpResponse, data: data)
            
            // Try to decode the data
            do {
                let decodedResponse = try jsonDecoder.decode(T.self, from: data)
                
                // Simple logging based on type name
                let responseType = String(describing: T.self)
                print("✅ NETWORK: Successfully decoded \(responseType)")
                
                // Additional logging for pagination if available
                // This still uses reflection but in a simpler way
                if responseType.contains("ApiResponse") {
                    // For debugging API pagination in a simpler way
                    if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let links = jsonObj["links"] as? [String: Any],
                       let next = links["next"] as? String {
                        print("📄 NETWORK: Next page available at: \(next)")
                    }
                    
                    // Try to log the number of items
                    if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataItems = jsonObj["data"] as? [Any] {
                        print("📊 NETWORK: Response contains \(dataItems.count) items")
                    }
                }
                
                return decodedResponse
            } catch let error as DecodingError {
                // Log the actual error for debugging
                print("❌ NETWORK: Decoding error: \(error)")
                
                // Print the response data if possible
                if let jsonStr = String(data: data, encoding: .utf8) {
                    let previewLength = min(500, jsonStr.count)
                    let jsonPreview = jsonStr.prefix(previewLength)
                    print("❌ NETWORK: Response JSON (first \(previewLength) chars): \(jsonPreview)...")
                }
                
                // Forward the actual DecodingError for better diagnostics
                throw NetworkError.decodingError(error)
            }
        } catch {
            // If validateResponse failed or another error occurred
            print("❌ NETWORK: Request failed with error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Validates the HTTP response and throws appropriate errors
    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            print("❌ NETWORK: Unauthorized access (401) - API token may be invalid")
            throw NetworkError.unauthorized
        case 429:
            print("❌ NETWORK: Rate limited (429) - Too many requests")
            throw NetworkError.rateLimited
        case 400...499:
            print("❌ NETWORK: Client error (\(response.statusCode))")
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("❌ NETWORK: API Error details: \(errorJson)")
            }
            throw NetworkError.serverError(response.statusCode)
        case 500...599:
            print("❌ NETWORK: Server error (\(response.statusCode))")
            throw NetworkError.serverError(response.statusCode)
        default:
            print("❌ NETWORK: Unknown status code: \(response.statusCode)")
            throw NetworkError.unknown(NSError(domain: "NetworkService", code: response.statusCode))
        }
    }
} 