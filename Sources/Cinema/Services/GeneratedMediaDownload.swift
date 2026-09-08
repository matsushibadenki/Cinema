import Foundation

enum GeneratedMediaDownload {
    static func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        return try validated(data, response: response)
    }

    static func validated(_ data: Data, response: URLResponse) throws -> Data {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        return data
    }
}
