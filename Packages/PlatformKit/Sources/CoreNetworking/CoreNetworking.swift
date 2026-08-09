import CoreLogging
import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public struct HTTPRequest: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval

    public init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case unacceptableStatus(Int)
    case transport(String)
    case decoding(String)
    case securityPolicyRejected
}

public struct RetryPolicy: Sendable {
    public let maximumAttempts: Int
    public let retryableStatusCodes: Set<Int>

    public init(maximumAttempts: Int = 1, retryableStatusCodes: Set<Int> = [502, 503, 504]) {
        self.maximumAttempts = max(1, maximumAttempts)
        self.retryableStatusCodes = retryableStatusCodes
    }
}

public protocol RequestHeaderProviding: Sendable {
    func headers() async -> [String: String]
}

public struct EmptyRequestHeaderProvider: RequestHeaderProviding {
    public init() {}
    public func headers() async -> [String: String] { [:] }
}

public protocol TransportSecurityEvaluating: Sendable {
    func prepareRequest(for host: String) async throws
}

public struct SystemTransportSecurityEvaluator: TransportSecurityEvaluating {
    public init() {}
    public func prepareRequest(for host: String) async throws {}
}

public protocol HTTPTransport: Sendable {
    func execute(_ request: URLRequest) async throws -> HTTPResponse
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func execute(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
                result[String(describing: item.key)] = String(describing: item.value)
            }
            return HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: data)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(String(describing: error))
        }
    }
}

public final class DefaultHTTPClient: HTTPClient, @unchecked Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let headerProvider: any RequestHeaderProviding
    private let securityEvaluator: any TransportSecurityEvaluating
    private let retryPolicy: RetryPolicy
    private let logger: any AppLogging

    public init(
        baseURL: URL,
        transport: any HTTPTransport,
        headerProvider: any RequestHeaderProviding = EmptyRequestHeaderProvider(),
        securityEvaluator: any TransportSecurityEvaluating = SystemTransportSecurityEvaluator(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        logger: any AppLogging
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.headerProvider = headerProvider
        self.securityEvaluator = securityEvaluator
        self.retryPolicy = retryPolicy
        self.logger = logger
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = URL(string: request.path, relativeTo: baseURL)?.absoluteURL,
              let host = url.host else {
            throw NetworkError.invalidURL
        }
        try await securityEvaluator.prepareRequest(for: host)
        var urlRequest = URLRequest(url: url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        let commonHeaders = await headerProvider.headers()
        commonHeaders.merging(request.headers) { _, requestValue in requestValue }
            .forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        var lastResponse: HTTPResponse?
        for attempt in 1...retryPolicy.maximumAttempts {
            logger.log(LogEntry(
                level: .debug,
                category: "network",
                message: "HTTP request",
                fields: [
                    LogField(name: "method", value: request.method.rawValue, privacy: .public),
                    LogField(name: "host", value: host, privacy: .public),
                    LogField(name: "authorization", value: request.headers["Authorization"] ?? "", privacy: .sensitive),
                ]
            ))
            let response = try await transport.execute(urlRequest)
            lastResponse = response
            if (200..<300).contains(response.statusCode) {
                return response
            }
            if !retryPolicy.retryableStatusCodes.contains(response.statusCode) || attempt == retryPolicy.maximumAttempts {
                throw NetworkError.unacceptableStatus(response.statusCode)
            }
        }
        throw NetworkError.unacceptableStatus(lastResponse?.statusCode ?? -1)
    }
}

public extension HTTPResponse {
    func decode<Value: Decodable & Sendable>(
        _ type: Value.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value {
        do {
            return try decoder.decode(type, from: body)
        } catch {
            throw NetworkError.decoding(String(describing: error))
        }
    }
}

public struct ClosureHTTPTransport: HTTPTransport {
    private let operation: @Sendable (URLRequest) async throws -> HTTPResponse

    public init(operation: @escaping @Sendable (URLRequest) async throws -> HTTPResponse) {
        self.operation = operation
    }

    public func execute(_ request: URLRequest) async throws -> HTTPResponse {
        try await operation(request)
    }
}
