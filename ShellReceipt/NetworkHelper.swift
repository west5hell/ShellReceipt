//
//  NetworkHelper.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation

struct ValidationServerRequest: Encodable {
    let receipt: String
    let shared_secret: String
    let sandbox: Bool
}

struct ValidationServerResponse: Decodable {
    let valid: Bool
    let status: Int
    let error: String?
}

enum ValidationServerError: Error {
    case invalidResponse
    case invalidStatus(Int, String)
}

struct NetworkHelper {
    let baseURL: URL

    init(host: String = "127.0.0.1", port: Int = 3000) {
        self.baseURL = URL(string: "http://\(host):\(port)")!
    }

    func validateReceipt(receipt: String, productID: String?) async throws
        -> ValidationServerResponse
    {
        var request = URLRequest(url: baseURL.appendingPathComponent("verify"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ValidationServerRequest(
            receipt: receipt,
            shared_secret: ProductCatalog.appleSharedSecret,
            sandbox: true
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ValidationServerError.invalidResponse
        }

        let serverResponse = try JSONDecoder().decode(
            ValidationServerResponse.self,
            from: data
        )

        if httpResponse.statusCode >= 400 || !serverResponse.valid {
            let message =
                serverResponse.error
                ?? HTTPURLResponse.localizedString(
                    forStatusCode: httpResponse.statusCode
                )
            throw ValidationServerError.invalidStatus(
                serverResponse.status,
                message
            )
        }

        return serverResponse
    }
}
